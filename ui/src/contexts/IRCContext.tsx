import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { Socket } from 'phoenix';
import { showNotification } from '../utils/notifications';

const IRCContext = createContext<IRCContextType | null>(null);

interface IRCContextType {
  socket: Socket | null;
  channel: any;  // Phoenix Channel object
  connected: boolean;  // true when ircConnected (for backward compat)
  nick: string;
  channels: string[];
  queries: string[];
  buffers: string[];
  activeTarget: string | null;
  setActiveTarget: (target: string | null) => void;
  messages: Record<string, IRCMessage[]>;
  setMessages: React.Dispatch<React.SetStateAction<Record<string, IRCMessage[]>>>;
  nicklist: Record<string, string[]>;
  topics: Record<string, string>;
  notices: Notice[];
  unread: Record<string, number>;
  channelList: ChannelListItem[];
  whoisResult: any;
  clearUnread: (target: string) => void;
  isChannel: (target: string) => boolean;
  sendMessage: (target: string, message: string, type?: string) => void;
  sendNotice: (target: string, message: string) => void;
  setTopic: (channel: string, topic: string) => void;
  joinChannel: (channel: string) => void;
  createChannel: (channel: string, mode?: 'public' | 'locked' | 'password', password?: string) => void;
  partChannel: (channel: string, message?: string) => void;
  changeNick: (newNick: string) => void;
  requestHistory: (channel: string, limit?: number) => void;
  requestNicklist: (channel: string) => void;
  requestWhois: (nick: string) => void;
  requestChannelList: () => void;
  inviteUser: (nick: string, channel: string) => void;
  kickUser: (channel: string, nick: string, reason?: string) => void;
  disconnectIRC: () => void;
  clearBuffer: (target: string) => void;
  openQuery: (nick: string) => void;
  closeQuery: (nick: string) => void;
  setWhoisResult: (result: any) => void;
  setChannelList: (list: ChannelListItem[]) => void;
}

interface IRCMessage {
  nick: string;
  message: string;
  target: string;
  time?: string;
  type?: 'message' | 'action' | 'system';
  subtype?: string;
}

interface Notice {
  nick: string;
  message: string;
  time: number;
}

interface ChannelListItem {
  channel: string;
  users?: string;
  topic?: string;
}

export function useIRC() {
  const ctx = useContext(IRCContext);
  if (!ctx) throw new Error('useIRC must be used within IRCProvider');
  return ctx;
}

export function IRCProvider({ children, userId }: { children: React.ReactNode; userId: number }) {
  const [socket, setSocket] = useState<Socket | null>(null);
  const [channel, setChannel] = useState<any>(null);
  const [channelReady, setChannelReady] = useState(false);  // Phoenix channel joined
  const [ircConnected, setIrcConnected] = useState(false);   // IRC connected (from Go)
  const [nick, setNick] = useState('');
  const [channels, setChannels] = useState<string[]>([]);
  const [queries, setQueries] = useState<string[]>([]);
  const [activeTarget, setActiveTarget] = useState<string | null>(null);
  const [messages, setMessages] = useState<Record<string, IRCMessage[]>>({});
  const [nicklist, setNicklist] = useState<Record<string, string[]>>({});
  const [topics, setTopics] = useState<Record<string, string>>({});
  const [notices] = useState<Notice[]>([]);
  const [unread, setUnread] = useState<Record<string, number>>({});
  const [channelList, setChannelList] = useState<ChannelListItem[]>([]);
  const [whoisResult, setWhoisResult] = useState<any>(null);

  useEffect(() => {
    let s: Socket;
    let ch: any;
    const connect = async () => {
      // Fetch signed token via HTTP (cookies sent) - works when WebSocket proxy strips cookies
      const res = await fetch('/api/auth/socket_token', { credentials: 'include' });
      const token = res.ok ? (await res.json()).token : null;
      const params = token ? { token } : {};
      const socketUrl = `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.host}/socket`;
      s = new Socket(socketUrl, { params, longPollFallbackMs: 4000 });
      s.connect();
      setSocket(s);
      if (typeof window !== 'undefined') (window as any).socket = s;

      ch = s.channel(`user:${userId}`, {});

      // Handle IRC events from Phoenix
    ch.on('irc:error', (data: any) => {
      const msg = data?.message || 'IRC error';
      showNotification('IRC Error', { body: msg });
    });

    ch.on('irc:connected', async (data: any) => {
      setIrcConnected(true);
      setNick(data.nick);
      // Auto-join channels from user settings
      try {
        const res = await fetch('/api/user/settings', { credentials: 'include' });
        const settings = await res.json();
        if (settings.auto_join_channels) {
          try {
            const channels = JSON.parse(settings.auto_join_channels || '[]');
            channels.forEach((channel: string) => {
              if (channel.startsWith('#')) {
                ch.push('irc:join_channel', { channel });
              }
            });
          } catch (e) {
            console.error('Failed to parse auto-join channels:', e);
          }
        }
      } catch (e) {
        console.error('Failed to load auto-join channels:', e);
      }
    });

    ch.on('irc:message', (msg: IRCMessage) => {
      const target = msg.target.startsWith('#') ? msg.target : msg.nick;
      setMessages((prev) => ({
        ...prev,
        [target]: [...(prev[target] || []), msg],
      }));
      if (!msg.target.startsWith('#')) {
        setQueries((prev) => (prev.includes(msg.nick) ? prev : [...prev, msg.nick]));
      }
      setUnread((prev) => {
        if (activeTarget === target) return prev;
        return { ...prev, [target]: (prev[target] || 0) + 1 };
      });
    });

    ch.on('irc:joined', async (data: any) => {
      setChannels((prev) => [...prev.filter((c) => c !== data.channel), data.channel]);
      if (!activeTarget) setActiveTarget(data.channel);
      // Load message history for the channel
      const { loadMessages } = await import('../utils/messages');
      const storedMessages = await loadMessages(data.channel, 50);
      const ircMessages = storedMessages.map(msg => ({
        nick: msg.nick,
        message: msg.content,
        target: msg.channel,
        time: msg.inserted_at,
        type: msg.message_type || 'message',
        id: msg.id,
        edited_at: msg.edited_at,
        pinned: msg.pinned,
        reactions: msg.reactions || [],
        user: msg.user
      }));
      setMessages((prev) => ({
        ...prev,
        [data.channel]: ircMessages
      }));
    });

    ch.on('irc:user_join', (data: any) => {
      setNicklist((prev) => {
        const names = prev[data.channel] || [];
        if (names.some((n) => n.replace(/^[@+%]/, '').toLowerCase() === data.nick?.toLowerCase())) return prev;
        return { ...prev, [data.channel]: [...names, data.nick] };
      });
    });

    ch.on('irc:user_part', (data: any) => {
      setNicklist((prev) => {
        const names = (prev[data.channel] || []).filter((n) => n.replace(/^[@+%]/, '').toLowerCase() !== data.nick?.toLowerCase());
        return names.length === (prev[data.channel] || []).length ? prev : { ...prev, [data.channel]: names };
      });
      if (data.nick?.toLowerCase() === nick?.toLowerCase()) {
        setChannels((prev) => prev.filter((c) => c !== data.channel));
        if (activeTarget === data.channel) {
          setActiveTarget(channels.find((c) => c !== data.channel) || null);
        }
      }
    });

    ch.on('irc:nicklist', (data: any) => {
      setNicklist((prev) => ({ ...prev, [data.channel]: data.names || [] }));
    });

    ch.on('irc:topic', (data: any) => {
      setTopics((prev) => ({ ...prev, [data.channel]: data.topic || '' }));
    });

    ch.on('irc:channel_list_item', (data: any) => {
      setChannelList((prev) => [...prev, data]);
    });

    ch.on('irc:channel_list_end', () => {
      // Channel list complete
    });

    ch.on('irc:disconnected', () => {
      setIrcConnected(false);
      setNick('');
      // Phoenix auto-re-sends connect; we'll get irc:connected again
    });

    ch.on('irc:whois', (data: any) => {
      setWhoisResult(data);
    });

      ch.join()
        .receive('ok', () => { setChannel(ch); setChannelReady(true); })
        .receive('error', (err: any) => { console.error('Channel join error:', err); });
    };
    connect();

    return () => {
      if (ch) ch.leave();
      if (s) s.disconnect();
    };
  }, [userId]);

  const sendMessage = (target: string, message: string, type = 'message') => {
    if (channel) {
      channel.push('irc:send_message', { target, message, type });
    }
  };

  const joinChannel = (ch: string) => {
    if (channel) channel.push('irc:join_channel', { channel: ch });
  };

  const createChannel = (ch: string, mode: 'public' | 'locked' | 'password' = 'public', password?: string) => {
    if (channel) {
      channel.push('irc:create_channel', {
        channel: ch,
        mode: mode,
        password: mode === 'password' ? password : null
      });
    }
  };

  const partChannel = (ch: string, msg?: string) => {
    if (channel) channel.push('irc:part_channel', { channel: ch, message: msg });
  };

  const changeNick = (newNick: string) => {
    if (channel) channel.push('irc:change_nick', { nick: newNick });
  };

  const requestHistory = async (ch: string, limit?: number) => {
    try {
      const { loadMessages } = await import('../utils/messages');
      const storedMessages = await loadMessages(ch, limit || 50);
      // Convert stored messages to IRC message format
      const ircMessages = storedMessages.map(msg => ({
        nick: msg.nick,
        message: msg.content,
        target: msg.channel,
        time: msg.inserted_at,
        type: msg.message_type || 'message',
        id: msg.id,
        edited_at: msg.edited_at,
        pinned: msg.pinned,
        reactions: msg.reactions || [],
        user: msg.user
      }));
      setMessages(prev => ({
        ...prev,
        [ch]: [...(prev[ch] || []), ...ircMessages]
      }));
    } catch (error) {
      console.error('Failed to load message history:', error);
    }
  };

  const requestNicklist = (ch: string) => {
    if (channel) channel.push('irc:request_nicklist', { channel: ch });
  };

  const sendNotice = (_target: string, _message: string) => {
    // TODO: implement
  };

  const setTopic = (ch: string, topic: string) => {
    if (channel) channel.push('irc:set_topic', { channel: ch, topic });
  };

  const requestWhois = (nick: string) => {
    if (channel) {
      setWhoisResult(null);
      channel.push('irc:whois', { nick });
    }
  };

  const requestChannelList = () => {
    if (channel) {
      setChannelList([]);
      channel.push('irc:list_channels', {});
    }
  };

  const inviteUser = (nick: string, ch: string) => {
    if (channel) channel.push('irc:invite', { nick, channel: ch });
  };

  const kickUser = (ch: string, nick: string, reason?: string) => {
    if (channel) channel.push('irc:kick', { channel: ch, nick, reason });
  };

  const disconnectIRC = () => {
    if (channel) channel.push('irc:disconnect', {});
  };

  const clearBuffer = (target: string) => {
    setMessages((prev) => ({ ...prev, [target]: [] }));
  };

  const openQuery = (nick: string) => {
    setQueries((prev) => {
      if (prev.includes(nick)) {
        setActiveTarget(nick);
        return prev;
      }
      return [...prev, nick];
    });
    setActiveTarget(nick);
  };

  const closeQuery = (nick: string) => {
    setQueries((prev) => {
      const next = prev.filter((q) => q !== nick);
      if (activeTarget === nick) {
        setActiveTarget(channels[0] || next[0] || null);
      }
      return next;
    });
  };

  const clearUnread = useCallback((target: string) => {
    setUnread((prev) => {
      const next = { ...prev };
      delete next[target];
      return next;
    });
  }, []);

  const buffers = [...channels, ...queries];
  const isChannel = (t: string | null) => t !== null && t.startsWith('#');

  return (
    <IRCContext.Provider
      value={{
        socket,
        channel,
        connected: ircConnected,
        nick,
        channels,
        queries,
        buffers,
        activeTarget,
        setActiveTarget,
        messages,
        setMessages,
        nicklist,
        topics,
        notices,
        unread,
        channelList,
        whoisResult,
        clearUnread,
        isChannel,
        sendMessage,
        sendNotice,
        setTopic,
        joinChannel,
        createChannel,
        partChannel,
        changeNick,
        requestHistory,
        requestNicklist,
        requestWhois,
        requestChannelList,
        inviteUser,
        kickUser,
        disconnectIRC,
        clearBuffer,
        openQuery,
        closeQuery,
        setWhoisResult,
        setChannelList,
      }}
    >
      {children}
    </IRCContext.Provider>
  );
}
