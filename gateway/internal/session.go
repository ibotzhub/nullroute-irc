package internal

import (
	"context"
	"crypto/tls"
	"fmt"
	"log"
	"net"

	"github.com/go-redis/redis/v8"
	"gopkg.in/irc.v3"
)

// SessionManager handles IRC session lifecycle
type SessionManager struct {
	rdb      *redis.Client
	sessions map[int]*IRCSession
}

type IRCSession struct {
	UserID   int
	Username string
	Client   *irc.Client
	Conn     net.Conn
	ctx      context.Context
	cancel   context.CancelFunc
}

func NewSessionManager(rdb *redis.Client) *SessionManager {
	return &SessionManager{
		rdb:      rdb,
		sessions: make(map[int]*IRCSession),
	}
}

func (sm *SessionManager) CreateSession(ctx context.Context, userID int, username string, ircHost, ircPort string, useTLS bool) error {
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

	addr := net.JoinHostPort(ircHost, ircPort)
	if useTLS {
		conn, err = tls.Dial("tcp", addr, &tls.Config{ServerName: ircHost})
	} else {
		conn, err = net.Dial("tcp", addr)
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
				sm.publishEvent(userID, "irc:connected", map[string]string{"nick": c.CurrentNick()})
			}
			sm.handleIRCMessage(userID, m)
		}),
	}

	client := irc.NewClient(conn, config)

	sess := &IRCSession{
		UserID:   userID,
		Username: username,
		Client:   client,
		Conn:     conn,
		ctx:      sessCtx,
		cancel:   cancel,
	}

	sm.sessions[userID] = sess

	go func() {
		if err := client.Run(); err != nil {
			log.Printf("IRC client error for user %d: %v", userID, err)
			sm.publishEvent(userID, "irc:error", map[string]string{"message": err.Error()})
			conn.Close()
			cancel()
			delete(sm.sessions, userID)
		}
	}()

	return nil
}

func (sm *SessionManager) handleIRCMessage(userID int, msg *irc.Message) {
	// Implementation can be expanded; main.go has full handling
}

func (sm *SessionManager) publishEvent(userID int, eventType string, data interface{}) {
	// Implementation moved to main.go for now
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

func (sm *SessionManager) GetSession(userID int) (*IRCSession, bool) {
	sess, ok := sm.sessions[userID]
	return sess, ok
}

func (sm *SessionManager) CloseSession(userID int) {
	if sess, ok := sm.sessions[userID]; ok {
		if sess.cancel != nil {
			sess.cancel()
		}
		if sess.Conn != nil {
			sess.Conn.Close()
		}
		delete(sm.sessions, userID)
	}
}
