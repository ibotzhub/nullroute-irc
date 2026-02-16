defmodule AppWeb.UserChannel do
  use Phoenix.Channel
  require Logger
  alias App.Accounts.Permissions
  alias App.Chat.Messages
  alias App.Chat.IgnoreList
  alias App.Chat.ChannelOperators

  def join("user:" <> user_id, _params, socket) do
    Logger.info("🔵 UserChannel JOIN for user:#{user_id}")

    user_id_int = String.to_integer(user_id)
    username = socket.assigns.current_user.username

    # Subscribe to Redis events for this user
    App.IRCBridge.subscribe_events(user_id_int, self())

    # Request IRC connection from gateway (via Redis)
    Logger.info("🟢 IRCBridge sending connect for user_id=#{user_id_int} username=#{username}")
    App.IRCBridge.send_command(user_id_int, "connect", %{
      username: username
    })

    {:ok, socket}
  end

  def handle_in("irc:send_message", %{"target" => target, "message" => msg, "type" => type}, socket) do
    user_id = socket.assigns.current_user.id
    App.IRCBridge.send_command(user_id, "send_message", %{
      target: target,
      message: msg,
      type: type
    })
    {:noreply, socket}
  end

  def handle_in("irc:join_channel", %{"channel" => channel}, socket) do
    user_id = socket.assigns.current_user.id
    # Only admins can create new channels (channels starting with #)
    # Regular users can only join existing channels
    # For now, allow all joins - IRC server will handle permissions
    App.IRCBridge.send_command(user_id, "join", %{channel: channel})
    {:noreply, socket}
  end

  def handle_in("irc:create_channel", %{"channel" => channel, "password" => password, "mode" => mode}, socket) do
    # Check if user has permission to create channels
    user = socket.assigns.current_user
    user = App.Repo.preload(user, :roles)
    
    if Permissions.has_permission?(user, "channels", "create") do
      user_id = user.id
      App.IRCBridge.send_command(user_id, "create_channel", %{
        channel: channel,
        password: password,
        mode: mode  # "public", "locked", "password"
      })
      {:noreply, socket}
    else
      {:reply, {:error, %{reason: "Permission denied: create channels"}}, socket}
    end
  end

  def handle_in("irc:create_channel", %{"channel" => channel}, socket) do
    # Backward compatibility - create public channel
    handle_in("irc:create_channel", %{"channel" => channel, "password" => nil, "mode" => "public"}, socket)
  end

  def handle_in("irc:part_channel", %{"channel" => channel, "message" => msg}, socket) do
    user_id = socket.assigns.current_user.id
    App.IRCBridge.send_command(user_id, "part", %{channel: channel, message: msg})
    {:noreply, socket}
  end

  def handle_in("irc:change_nick", %{"nick" => nick}, socket) do
    user_id = socket.assigns.current_user.id
    App.IRCBridge.send_command(user_id, "change_nick", %{nick: nick})
    {:noreply, socket}
  end

  def handle_in("irc:set_topic", %{"channel" => channel, "topic" => topic}, socket) do
    # Check permission to modify channels
    user = socket.assigns.current_user
    user = App.Repo.preload(user, :roles)
    
    if Permissions.has_permission?(user, "channels", "modify") do
      user_id = user.id
      App.IRCBridge.send_command(user_id, "set_topic", %{channel: channel, topic: topic})
      {:noreply, socket}
    else
      {:reply, {:error, %{reason: "Permission denied: modify channels"}}, socket}
    end
  end

  def handle_in("irc:kick", %{"channel" => channel, "nick" => nick, "reason" => reason}, socket) do
    # Check permission to kick users
    user = socket.assigns.current_user
    user = App.Repo.preload(user, :roles)
    
    if Permissions.has_permission?(user, "users", "kick") do
      user_id = user.id
      App.IRCBridge.send_command(user_id, "kick", %{channel: channel, nick: nick, reason: reason})
      {:noreply, socket}
    else
      {:reply, {:error, %{reason: "Permission denied: kick users"}}, socket}
    end
  end

  def handle_in("irc:invite", %{"nick" => nick, "channel" => channel}, socket) do
    # Check permission to invite users (modify channels)
    user = socket.assigns.current_user
    user = App.Repo.preload(user, :roles)
    
    if Permissions.has_permission?(user, "channels", "modify") do
      user_id = user.id
      App.IRCBridge.send_command(user_id, "invite", %{nick: nick, channel: channel})
      {:noreply, socket}
    else
      {:reply, {:error, %{reason: "Permission denied: modify channels"}}, socket}
    end
  end

  def handle_in("irc:ban", %{"channel" => channel, "nick" => nick, "reason" => reason}, socket) do
    # Check permission to ban users
    user = socket.assigns.current_user
    user = App.Repo.preload(user, :roles)
    
    if Permissions.has_permission?(user, "users", "ban") do
      user_id = user.id
      App.IRCBridge.send_command(user_id, "ban", %{channel: channel, nick: nick, reason: reason})
      {:noreply, socket}
    else
      {:reply, {:error, %{reason: "Permission denied: ban users"}}, socket}
    end
  end

  def handle_in("irc:whois", %{"nick" => nick}, socket) do
    user_id = socket.assigns.current_user.id
    App.IRCBridge.send_command(user_id, "whois", %{nick: nick})
    {:noreply, socket}
  end

  def handle_in("irc:list_channels", _params, socket) do
    user_id = socket.assigns.current_user.id
    App.IRCBridge.send_command(user_id, "list_channels", %{})
    {:noreply, socket}
  end

  def handle_in("irc:request_nicklist", %{"channel" => channel}, socket) do
    user_id = socket.assigns.current_user.id
    App.IRCBridge.send_command(user_id, "get_nicklist", %{channel: channel})
    {:noreply, socket}
  end

  def handle_in("irc:set_away", %{"message" => message}, socket) do
    user_id = socket.assigns.current_user.id
    user = App.Accounts.get_user(user_id)
    App.Accounts.update_user(user, %{away: true, away_message: message})
    App.IRCBridge.send_command(user_id, "set_away", %{message: message})
    {:noreply, socket}
  end

  def handle_in("irc:unset_away", _params, socket) do
    user_id = socket.assigns.current_user.id
    user = App.Accounts.get_user(user_id)
    App.Accounts.update_user(user, %{away: false, away_message: nil})
    App.IRCBridge.send_command(user_id, "unset_away", %{})
    {:noreply, socket}
  end

  def handle_in("irc:ignore", %{"nick" => nick}, socket) do
    user_id = socket.assigns.current_user.id
    # Try to find user_id for the nick
    ignored_user_id = Messages.get_user_id_from_nick(nick)
    IgnoreList.add_to_ignore_list(user_id, nick, ignored_user_id)
    {:reply, {:ok, %{message: "Ignoring #{nick}"}}, socket}
  end

  def handle_in("irc:unignore", %{"nick" => nick}, socket) do
    user_id = socket.assigns.current_user.id
    IgnoreList.remove_from_ignore_list(user_id, nick)
    {:reply, {:ok, %{message: "No longer ignoring #{nick}"}}, socket}
  end

  def handle_in("irc:who", %{"nick" => nick}, socket) do
    user_id = socket.assigns.current_user.id
    App.IRCBridge.send_command(user_id, "who", %{nick: nick})
    {:noreply, socket}
  end

  def handle_in("irc:mode", %{"target" => target}, socket) do
    user_id = socket.assigns.current_user.id
    App.IRCBridge.send_command(user_id, "mode", %{target: target})
    {:noreply, socket}
  end

  def handle_in("irc:set_channel_mode", %{"channel" => channel, "mode" => mode}, socket) do
    user = socket.assigns.current_user
    user = App.Repo.preload(user, :roles)
    
    # Check if user has permission (must be op or admin)
    if Permissions.has_permission?(user, "channels", "modify") || 
       ChannelOperators.is_op?(channel, user.id) do
      user_id = user.id
      App.IRCBridge.send_command(user_id, "set_channel_mode", %{channel: channel, mode: mode})
      {:noreply, socket}
    else
      {:reply, {:error, %{reason: "Permission denied: modify channels"}}, socket}
    end
  end

  def handle_in("irc:set_operator", %{"channel" => channel, "nick" => nick, "type" => type}, socket) do
    user = socket.assigns.current_user
    user = App.Repo.preload(user, :roles)
    
    # Only ops or admins can set operators
    if Permissions.has_permission?(user, "channels", "modify") || 
       ChannelOperators.is_op?(channel, user.id) do
      user_id = user.id
      App.IRCBridge.send_command(user_id, "set_operator", %{channel: channel, nick: nick, type: type})
      {:noreply, socket}
    else
      {:reply, {:error, %{reason: "Permission denied"}}, socket}
    end
  end

  def handle_in("irc:ctcp", %{"target" => target, "command" => command}, socket) do
    user_id = socket.assigns.current_user.id
    App.IRCBridge.send_command(user_id, "ctcp", %{target: target, command: command})
    {:noreply, socket}
  end

  def handle_info({:irc_event, event}, socket) do
    # Filter ignored messages (guard against nil data)
    data = event["data"] || %{}
    should_filter = case event["type"] do
      "privmsg" -> data["nick"] && IgnoreList.is_ignored?(socket.assigns.current_user.id, data["nick"])
      "action" -> data["nick"] && IgnoreList.is_ignored?(socket.assigns.current_user.id, data["nick"])
      _ -> false
    end

    if should_filter do
      # Don't push ignored messages to client
      {:noreply, socket}
    else
      # Store messages in database
      data = event["data"] || %{}
      if event["type"] == "privmsg" do
        if data["channel"] && data["nick"] && data["message"] do
          user_id = Messages.get_user_id_from_nick(data["nick"])
          if user_id do
            Messages.create_message(%{
              user_id: user_id,
              channel: data["channel"],
              nick: data["nick"],
              content: data["message"],
              message_type: "message"
            })
            Messages.set_user_nick(user_id, data["nick"])
          end
        end
      end

      if event["type"] == "action" do
        if data["channel"] && data["nick"] && data["message"] do
          user_id = Messages.get_user_id_from_nick(data["nick"])
          if user_id do
            Messages.create_message(%{
              user_id: user_id,
              channel: data["channel"],
              nick: data["nick"],
              content: data["message"],
              message_type: "action"
            })
            Messages.set_user_nick(user_id, data["nick"])
          end
        end
      end

      if event["type"] == "nick_change" do
        if data["old_nick"] && data["new_nick"] do
          if Messages.get_user_id_from_nick(data["old_nick"]) == socket.assigns.current_user.id do
            Messages.set_user_nick(socket.assigns.current_user.id, data["new_nick"])
          end
        end
      end

      # Set nick mapping when user connects to IRC
      if event["type"] == "irc:connected" && data["nick"] do
        Messages.set_user_nick(socket.assigns.current_user.id, data["nick"])
      end

      # Auto-reconnect when IRC disconnects (Go restart, network hiccup, etc.)
      # Admin and all users stay connected as long as they're on the site
      if event["type"] == "irc:disconnected" do
        user_id = socket.assigns.current_user.id
        username = socket.assigns.current_user.username
        Process.send_after(self(), {:reconnect_irc, user_id, username}, 1_000)
      end

      push(socket, event["type"], event["data"])
      {:noreply, socket}
    end
  end

  def handle_info({:reconnect_irc, user_id, username}, socket) do
    App.IRCBridge.send_command(user_id, "connect", %{username: username})
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    user_id = socket.assigns.current_user.id
    App.IRCBridge.unsubscribe_events(user_id)
    App.IRCBridge.send_command(user_id, "disconnect", %{})
    :ok
  end
end
