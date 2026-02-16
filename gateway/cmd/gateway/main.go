package main

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/go-redis/redis/v8"
	"gopkg.in/irc.v3"
)

const (
	redisAddr     = "localhost:6379"
	reconnectWait = 5 * time.Second
)

func ircHost() string {
	if v := os.Getenv("IRC_HOST"); v != "" {
		return v
	}
	return "irc.example.com"
}

func ircPort() string {
	if v := os.Getenv("IRC_PORT"); v != "" {
		return v
	}
	return "6697"
}

func ircUseTLS() bool {
	if v := os.Getenv("IRC_TLS"); v == "false" || v == "0" {
		return false
	}
	return true
}

// RateLimiter token bucket - 1 msg/sec sustained, burst of 5 for IRC flood protection
type RateLimiter struct {
	tokens     float64
	maxTokens  float64
	refillRate float64 // tokens per second
	lastRefill time.Time
	mu         sync.Mutex
}

func NewRateLimiter(rate float64, burst int) *RateLimiter {
	return &RateLimiter{
		tokens:     float64(burst),
		maxTokens:  float64(burst),
		refillRate: rate,
		lastRefill: time.Now(),
	}
}

func (r *RateLimiter) Allow() bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	now := time.Now()
	elapsed := now.Sub(r.lastRefill).Seconds()
	r.tokens = math.Min(r.maxTokens, r.tokens+elapsed*r.refillRate)
	r.lastRefill = now

	if r.tokens >= 1.0 {
		r.tokens -= 1.0
		return true
	}
	return false
}

type IRCSession struct {
	UserID      int
	Username    string
	Client      *irc.Client
	Conn        net.Conn
	ctx         context.Context
	cancel      context.CancelFunc
	rateLimiter *RateLimiter
}

type Command struct {
	Type   string          `json:"type"`
	Data   json.RawMessage `json:"data"`
	UserID int             `json:"user_id,omitempty"`
}

type Event struct {
	Type   string      `json:"type"`
	Data   interface{} `json:"data"`
	UserID int         `json:"user_id"`
}

var (
	rdb      *redis.Client
	sessions = make(map[int]*IRCSession)
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Redis client
	rdb = redis.NewClient(&redis.Options{
		Addr: redisAddr,
		DB:   0,
	})
	defer rdb.Close()

	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatalf("Redis connection failed: %v", err)
	}
	log.Println("Connected to Redis")

	// Subscribe to all command channels
	pubsub := rdb.PSubscribe(ctx, "commands:*")
	defer pubsub.Close()

	ch := pubsub.Channel()

	// Handle shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigChan
		log.Println("Shutting down...")
		cancel()
		for _, sess := range sessions {
			if sess.cancel != nil {
				sess.cancel()
			}
		}
		os.Exit(0)
	}()

	log.Println("Gateway listening for Redis commands...")

	// Process Redis messages
	for msg := range ch {
		var cmd Command
		if err := json.Unmarshal([]byte(msg.Payload), &cmd); err != nil {
			log.Printf("Failed to parse command: %v", err)
			continue
		}

		// Extract user ID from channel name (commands:42 -> 42)
		var userID int
		if _, err := fmt.Sscanf(msg.Channel, "commands:%d", &userID); err != nil {
			log.Printf("Failed to parse user ID from channel %s: %v", msg.Channel, err)
			continue
		}
		cmd.UserID = userID

		handleCommand(ctx, cmd)
	}
}

func handleCommand(ctx context.Context, cmd Command) {
	switch cmd.Type {
	case "connect":
		var data struct{ Username string }
		if err := json.Unmarshal(cmd.Data, &data); err == nil {
			if err := createSession(ctx, cmd.UserID, data.Username); err != nil {
				log.Printf("Failed to create IRC session for user %d: %v", cmd.UserID, err)
				publishEvent(cmd.UserID, "irc:error", map[string]string{"message": err.Error()})
			}
		}
		return
	}

	sess, exists := sessions[cmd.UserID]
	if !exists {
		log.Printf("No session for user %d, ignoring command %s", cmd.UserID, cmd.Type)
		return
	}

	writeOrError := func(line string) {
		if err := sess.WriteLine(line); err != nil {
			publishEvent(cmd.UserID, "irc:error", map[string]string{"message": err.Error()})
		}
	}

	switch cmd.Type {
	case "join":
		var data struct{ Channel string }
		if err := json.Unmarshal(cmd.Data, &data); err == nil {
			writeOrError("JOIN " + data.Channel)
		}
	case "part":
		var data struct{ Channel, Message string }
		if err := json.Unmarshal(cmd.Data, &data); err == nil {
			msg := "PART " + data.Channel
			if data.Message != "" {
				msg += " :" + data.Message
			}
			writeOrError(msg)
		}
	case "send_message":
		var data struct{ Target, Message string }
		if err := json.Unmarshal(cmd.Data, &data); err == nil {
			writeOrError(fmt.Sprintf("PRIVMSG %s :%s", data.Target, data.Message))
		}
	case "change_nick":
		var data struct{ Nick string }
		if err := json.Unmarshal(cmd.Data, &data); err == nil {
			writeOrError("NICK " + data.Nick)
		}
	case "set_topic":
		var data struct{ Channel, Topic string }
		if err := json.Unmarshal(cmd.Data, &data); err == nil {
			msg := "TOPIC " + data.Channel
			if data.Topic != "" {
				msg += " :" + data.Topic
			}
			writeOrError(msg)
		}
	case "kick":
		var data struct{ Channel, Nick, Reason string }
		if err := json.Unmarshal(cmd.Data, &data); err == nil {
			msg := fmt.Sprintf("KICK %s %s", data.Channel, data.Nick)
			if data.Reason != "" {
				msg += " :" + data.Reason
			}
			writeOrError(msg)
		}
	case "invite":
		var data struct{ Nick, Channel string }
		if err := json.Unmarshal(cmd.Data, &data); err == nil {
			writeOrError(fmt.Sprintf("INVITE %s %s", data.Nick, data.Channel))
		}
	case "whois":
		var data struct{ Nick string }
		if err := json.Unmarshal(cmd.Data, &data); err == nil {
			writeOrError("WHOIS " + data.Nick)
		}
	case "list_channels":
		writeOrError("LIST")
	case "get_nicklist":
		var data struct{ Channel string }
		if err := json.Unmarshal(cmd.Data, &data); err == nil {
			writeOrError("NAMES " + data.Channel)
		}
	case "disconnect":
		if sess.cancel != nil {
			sess.cancel()
		}
		if sess.Conn != nil {
			sess.Conn.Close()
		}
		delete(sessions, cmd.UserID)
		publishEvent(cmd.UserID, "irc:disconnected", nil)
	default:
		log.Printf("Unknown command type: %s", cmd.Type)
	}
}

func createSession(ctx context.Context, userID int, username string) error {
	sessCtx, cancel := context.WithCancel(ctx)

	nick := sanitizeNick(username)
	if len(nick) > 9 {
		nick = nick[:9]
	}
	if nick == "" {
		nick = fmt.Sprintf("user%d", userID)
	}

	var conn net.Conn
	var err error

	host := ircHost()
	port := ircPort()
	address := net.JoinHostPort(host, port)
	if ircUseTLS() {
		tlsConfig := &tls.Config{
			ServerName:         host,
			InsecureSkipVerify: true, // IRC server cert often doesn't match (e.g. self-signed, different domain)
		}
		conn, err = tls.Dial("tcp", address, tlsConfig)
	} else {
		conn, err = net.Dial("tcp", address)
	}
	if err != nil {
		cancel()
		return fmt.Errorf("IRC connection failed: %w", err)
	}

	config := irc.ClientConfig{
		Nick: nick,
		User: username,
		Name: "NullRoute Web Client",
		Pass: "",
		Handler: irc.HandlerFunc(func(c *irc.Client, m *irc.Message) {
			if m.Command == "001" { // RPL_WELCOME
				publishEvent(userID, "irc:connected", map[string]string{"nick": c.CurrentNick()})
			}
			handleIRCMessage(userID, m)
		}),
	}

	// Pass the net.Conn directly - irc.NewClient accepts io.ReadWriteCloser
	client := irc.NewClient(conn, config)

	sess := &IRCSession{
		UserID:      userID,
		Username:    username,
		Client:      client,
		Conn:        conn,
		ctx:         sessCtx,
		cancel:      cancel,
		rateLimiter: NewRateLimiter(1.0, 5), // 1 msg/sec, burst of 5
	}

	sessions[userID] = sess

	// Start client in goroutine (handles registration and message processing)
	go func() {
		if err := client.Run(); err != nil {
			log.Printf("IRC client error for user %d: %v", userID, err)
			publishEvent(userID, "irc:error", map[string]string{"message": err.Error()})
			conn.Close()
			cancel()
			delete(sessions, userID)
		}
	}()

	return nil
}

// WriteLine sends a line to IRC with rate limiting. Returns error if rate limited.
func (s *IRCSession) WriteLine(line string) error {
	if !s.rateLimiter.Allow() {
		return fmt.Errorf("rate limit exceeded - slow down")
	}
	return s.Client.Write(line)
}

func handleIRCMessage(userID int, msg *irc.Message) {
	switch msg.Command {
	case "PRIVMSG":
		if len(msg.Params) < 2 {
			return
		}
		target := msg.Params[0]
		message := msg.Params[1]
		isAction := len(message) >= 8 && message[:1] == "\x01" && message[len(message)-1:] == "\x01"

		if isAction {
			message = message[8 : len(message)-1]
			publishEvent(userID, "irc:action", map[string]interface{}{
				"nick":    msg.Name,
				"target":  target,
				"message": message,
				"time":    time.Now().Format(time.RFC3339),
			})
		} else {
			publishEvent(userID, "irc:message", map[string]interface{}{
				"nick":    msg.Name,
				"target":  target,
				"message": message,
				"time":    time.Now().Format(time.RFC3339),
			})
		}
	case "JOIN":
		if len(msg.Params) < 1 {
			return
		}
		channel := msg.Params[0]
		if msg.Name == "" {
			// Our own join
			publishEvent(userID, "irc:joined", map[string]string{"channel": channel})
		}
		publishEvent(userID, "irc:user_join", map[string]string{
			"channel": channel,
			"nick":    msg.Name,
		})
	case "PART":
		if len(msg.Params) < 1 {
			return
		}
		channel := msg.Params[0]
		reason := ""
		if len(msg.Params) > 1 {
			reason = msg.Params[1]
		}
		publishEvent(userID, "irc:user_part", map[string]string{
			"channel": channel,
			"nick":    msg.Name,
			"message": reason,
		})
	case "NICK":
		if len(msg.Params) < 1 {
			return
		}
		publishEvent(userID, "irc:nick_change", map[string]string{
			"oldNick": msg.Name,
			"newNick": msg.Params[0],
		})
	case "TOPIC":
		if len(msg.Params) < 1 {
			return
		}
		channel := msg.Params[0]
		topic := ""
		if len(msg.Params) > 1 {
			topic = msg.Params[1]
		}
		publishEvent(userID, "irc:topic", map[string]string{
			"channel": channel,
			"topic":   topic,
			"nick":    msg.Name,
		})
	case "353": // RPL_NAMREPLY
		if len(msg.Params) < 4 {
			return
		}
		channel := msg.Params[2]
		names := msg.Params[3]
		publishEvent(userID, "irc:nicklist", map[string]interface{}{
			"channel": channel,
			"names":   parseNames(names),
		})
	case "NOTICE":
		if len(msg.Params) < 2 {
			return
		}
		publishEvent(userID, "irc:notice", map[string]string{
			"nick":    msg.Name,
			"message": msg.Params[1],
			"target":  msg.Params[0],
		})
	case "311", "312", "313", "317", "318": // WHOIS replies
		if len(msg.Params) < 2 {
			return
		}
		// Aggregate WHOIS data
		publishEvent(userID, "irc:whois", map[string]interface{}{
			"nick": msg.Params[1],
			"data": msg,
		})
	case "322": // RPL_LIST
		if len(msg.Params) < 3 {
			return
		}
		channel := msg.Params[1]
		users := msg.Params[2]
		topic := ""
		if len(msg.Params) > 3 {
			topic = msg.Params[3]
		}
		publishEvent(userID, "irc:channel_list_item", map[string]interface{}{
			"channel": channel,
			"users":   users,
			"topic":   topic,
		})
	case "323": // RPL_LISTEND
		publishEvent(userID, "irc:channel_list_end", nil)
	}
}

func parseNames(namesStr string) []string {
	var names []string
	for _, name := range splitNames(namesStr) {
		names = append(names, name)
	}
	return names
}

func splitNames(s string) []string {
	var result []string
	start := 0
	for i, r := range s {
		if r == ' ' {
			if start < i {
				result = append(result, s[start:i])
			}
			start = i + 1
		}
	}
	if start < len(s) {
		result = append(result, s[start:])
	}
	return result
}

func publishEvent(userID int, eventType string, data interface{}) {
	event := Event{
		Type:   eventType,
		Data:   data,
		UserID: userID,
	}
	payload, err := json.Marshal(event)
	if err != nil {
		log.Printf("Failed to marshal event: %v", err)
		return
	}

	channel := fmt.Sprintf("events:%d", userID)
	if err := rdb.Publish(context.Background(), channel, payload).Err(); err != nil {
		log.Printf("Failed to publish event: %v", err)
	}
}

func sanitizeNick(username string) string {
	allowed := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789[]\\`^{}-"
	result := ""
	for _, r := range username {
		for _, a := range allowed {
			if r == a {
				result += string(r)
				break
			}
		}
	}
	return result
}
