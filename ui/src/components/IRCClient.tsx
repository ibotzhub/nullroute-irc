import { useState, useEffect, useRef, useCallback } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useIRC } from '../contexts/IRCContext';
import { UserSettings } from './UserSettings';
import { AdminSettings } from './AdminSettings';
import { AdminUsers } from './AdminUsers';
import { RoleManager } from './RoleManager';
import { UserProfile } from './UserProfile';
import { Message } from './Message';
import { StatusBar } from './StatusBar';
import { uploadFile, searchMessages, loadMessages } from '../utils/messages';
import { completeNick, completeChannel, completeCommand } from '../utils/tabCompletion';
import { saveToHistory, getHistory } from '../utils/commandHistory';
import { showNotification, playSound, detectMention } from '../utils/notifications';
import api from '../api';
import './IRCClient.css';
import './Message.css';
import './StatusBar.css';

export function IRCClient() {
  const { user } = useAuth();
  const irc = useIRC();
  const [showUserSettings, setShowUserSettings] = useState(false);
  const [showAdminSettings, setShowAdminSettings] = useState(false);
  const [showAdminUsers, setShowAdminUsers] = useState(false);
  const [showRoleManager, setShowRoleManager] = useState(false);
  const [showCreateChannel, setShowCreateChannel] = useState(false);
  const [newChannelName, setNewChannelName] = useState('');
  const [newChannelPassword, setNewChannelPassword] = useState('');
  const [newChannelMode, setNewChannelMode] = useState<'public' | 'locked' | 'password'>('public');
  const [joinChannelName, setJoinChannelName] = useState('');
  const [input, setInput] = useState('');
  const [showSearch, setShowSearch] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<any[]>([]);
  const [showPinned, setShowPinned] = useState(false);
  const [pinnedMessages, setPinnedMessages] = useState<any[]>([]);
  const [editingMessageId, setEditingMessageId] = useState<number | null>(null);
  const [commandHistoryIndex, setCommandHistoryIndex] = useState(-1);
  const [channelModes, setChannelModes] = useState<string[]>([]);
  const [userCount, setUserCount] = useState(0);
  const [operatorCount, setOperatorCount] = useState(0);
  const [ignoredUsers, setIgnoredUsers] = useState<string[]>([]);
  const [viewingProfile, setViewingProfile] = useState<number | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const commandHistoryRef = useRef<string[]>([]);

  // Apply theme
  useEffect(() => {
    if (user?.theme) {
      document.documentElement.setAttribute('data-theme', user.theme);
    }
  }, [user?.theme]);

  // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [irc.messages, irc.activeTarget]);

  // Focus input when target changes
  useEffect(() => {
    inputRef.current?.focus();
  }, [irc.activeTarget]);

  // Load command history
  useEffect(() => {
    commandHistoryRef.current = getHistory();
  }, []);

  // Load channel modes and operators
  useEffect(() => {
    if (irc.activeTarget && irc.activeTarget.startsWith('#')) {
      loadChannelInfo(irc.activeTarget);
    }
  }, [irc.activeTarget]);

  // Load ignore list
  useEffect(() => {
    loadIgnoreList();
  }, []);

  // Check for mentions and notify
  useEffect(() => {
    if (!irc.activeTarget || !irc.nick) return;
    const messages = irc.messages[irc.activeTarget] || [];
    const lastMessage = messages[messages.length - 1];
    if (lastMessage && detectMention(lastMessage.message || lastMessage.content || '', irc.nick)) {
      const msgTarget = lastMessage.target || irc.activeTarget;
      if (document.hidden || irc.activeTarget !== msgTarget) {
        showNotification(`Mentioned in ${msgTarget}`, {
          body: `${lastMessage.nick}: ${lastMessage.message || lastMessage.content}`
        });
        playSound();
      }
    }
  }, [irc.messages, irc.activeTarget, irc.nick]);

  const loadChannelInfo = async (channel: string) => {
    try {
      const [modesRes, operatorsRes] = await Promise.all([
        api.get(`/api/irc/channel/${encodeURIComponent(channel)}/modes`),
        api.get(`/api/irc/channel/${encodeURIComponent(channel)}/operators`)
      ]);
      setChannelModes(modesRes.data.modes || []);
      const operators = operatorsRes.data.operators || [];
      setOperatorCount(operators.filter((o: any) => o.type === 'op').length);
      setUserCount(irc.nicklist[channel]?.length || 0);
    } catch (e) {
      console.error('Failed to load channel info:', e);
    }
  };

  const loadIgnoreList = async () => {
    try {
      const res = await api.get('/api/irc/ignore');
      setIgnoredUsers(res.data.ignored.map((i: any) => i.nick));
    } catch (e) {
      console.error('Failed to load ignore list:', e);
    }
  };

  const refreshMessages = useCallback(async () => {
    if (!irc.activeTarget) return;
    const messages = await loadMessages(irc.activeTarget, 50);
    const ircMessages = messages.map(msg => ({
      nick: msg.nick,
      message: msg.content,
      content: msg.content,
      target: msg.channel,
      time: msg.inserted_at,
      type: msg.message_type || 'message',
      id: msg.id,
      edited_at: msg.edited_at,
      pinned: msg.pinned,
      reactions: msg.reactions || [],
      user: msg.user,
      user_id: msg.user_id,
      inserted_at: msg.inserted_at
    }));
    irc.setMessages((prev: any) => ({
      ...prev,
      [irc.activeTarget!]: ircMessages
    }));
  }, [irc.activeTarget, irc.setMessages]);

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !irc.activeTarget) return;
    
    const result = await uploadFile(file);
    if (result) {
      const fileMessage = `[File: ${result.filename}](${result.url})`;
      irc.sendMessage(irc.activeTarget, fileMessage);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const handleSearch = async () => {
    if (!irc.activeTarget || !searchQuery.trim()) return;
    const results = await searchMessages(irc.activeTarget, searchQuery);
    setSearchResults(results);
  };

  const loadPinnedMessages = async () => {
    if (!irc.activeTarget) return;
    const { getPinnedMessages } = await import('../utils/messages');
    const pinned = await getPinnedMessages(irc.activeTarget);
    setPinnedMessages(pinned);
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    // Tab completion
    if (e.key === 'Tab' && !e.shiftKey) {
      e.preventDefault();
      const activeNicklist = irc.activeTarget && irc.activeTarget.startsWith('#') 
        ? (irc.nicklist[irc.activeTarget] || []) 
        : [];
      
      let completed: string | null = null;
      if (input.startsWith('/')) {
        completed = completeCommand(input);
      } else if (irc.activeTarget?.startsWith('#')) {
        completed = completeChannel(input, irc.channels) || 
                   completeNick(input, activeNicklist, irc.nick);
      } else {
        completed = completeNick(input, irc.queries, irc.nick);
      }
      
      if (completed) {
        setInput(completed);
      }
      return;
    }

    // Command history (up/down arrows)
    if (e.key === 'ArrowUp' && inputRef.current === document.activeElement) {
      e.preventDefault();
      if (commandHistoryIndex < commandHistoryRef.current.length - 1) {
        const newIndex = commandHistoryIndex + 1;
        setCommandHistoryIndex(newIndex);
        setInput(commandHistoryRef.current[commandHistoryRef.current.length - 1 - newIndex] || '');
      }
      return;
    }

    if (e.key === 'ArrowDown' && inputRef.current === document.activeElement) {
      e.preventDefault();
      if (commandHistoryIndex > 0) {
        const newIndex = commandHistoryIndex - 1;
        setCommandHistoryIndex(newIndex);
        setInput(commandHistoryRef.current[commandHistoryRef.current.length - 1 - newIndex] || '');
      } else {
        setCommandHistoryIndex(-1);
        setInput('');
      }
      return;
    }

    // Reset history index when typing
    if (e.key.length === 1 || e.key === 'Backspace' || e.key === 'Delete') {
      setCommandHistoryIndex(-1);
    }
  };

  const handleSendMessage = (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || !irc.activeTarget) return;

    // Save to command history
    saveToHistory(input.trim());
    setCommandHistoryIndex(-1);

    // Handle slash commands
    if (input.startsWith('/')) {
      const parts = input.slice(1).trim().split(/\s+/);
      const cmd = parts[0]?.toLowerCase();

      if (cmd === 'join' && parts[1]) {
        const ch = parts[1].startsWith('#') ? parts[1] : `#${parts[1]}`;
        irc.joinChannel(ch);
        setInput('');
        return;
      }

      if (cmd === 'part' && irc.activeTarget) {
        irc.partChannel(irc.activeTarget);
        setInput('');
        return;
      }

      if (cmd === 'search' && parts[1]) {
        setSearchQuery(parts.slice(1).join(' '));
        setShowSearch(true);
        setTimeout(() => handleSearch(), 100);
        setInput('');
        return;
      }

      if (cmd === 'nick' && parts[1]) {
        irc.changeNick(parts[1]);
        setInput('');
        return;
      }

      if (cmd === 'me' && parts.slice(1).length) {
        irc.sendMessage(irc.activeTarget, parts.slice(1).join(' '), 'action');
        setInput('');
        return;
      }

      if (cmd === 'msg' && parts[1] && parts.slice(2).length) {
        irc.openQuery(parts[1]);
        setTimeout(() => {
          irc.sendMessage(parts[1], parts.slice(2).join(' '));
        }, 100);
        setInput('');
        return;
      }

      if (cmd === 'away') {
        if (parts[1]) {
          // Set away with message
          if (irc.channel) {
            irc.channel.push('irc:set_away', { message: parts.slice(1).join(' ') });
          }
        } else {
          // Unset away
          if (irc.channel) {
            irc.channel.push('irc:unset_away', {});
          }
        }
        setInput('');
        return;
      }

      if (cmd === 'ignore' && parts[1]) {
        if (irc.channel) {
          irc.channel.push('irc:ignore', { nick: parts[1] });
          loadIgnoreList();
        }
        setInput('');
        return;
      }

      if (cmd === 'unignore' && parts[1]) {
        if (irc.channel) {
          irc.channel.push('irc:unignore', { nick: parts[1] });
          loadIgnoreList();
        }
        setInput('');
        return;
      }

      if (cmd === 'who' && parts[1]) {
        if (irc.channel) {
          irc.channel.push('irc:who', { nick: parts[1] });
        }
        setInput('');
        return;
      }

      if (cmd === 'mode' && parts[1]) {
        if (irc.channel) {
          irc.channel.push('irc:mode', { target: parts[1] });
        }
        setInput('');
        return;
      }

      if (cmd === 'ctcp' && parts[1] && parts[2]) {
        if (irc.channel) {
          irc.channel.push('irc:ctcp', { target: parts[1], command: parts[2] });
        }
        setInput('');
        return;
      }

      // Unknown command, send as-is
    }

    // Regular message
    irc.sendMessage(irc.activeTarget!, input.trim());
    setInput('');
  };

  const handleJoinChannel = (e: React.FormEvent) => {
    e.preventDefault();
    if (!joinChannelName.trim()) return;
    const ch = joinChannelName.trim().startsWith('#') ? joinChannelName.trim() : `#${joinChannelName.trim()}`;
    irc.joinChannel(ch);
    setJoinChannelName('');
  };

  const handleCreateChannel = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newChannelName.trim() || (!user?.is_admin && !user?.is_master_admin)) return;
    const ch = newChannelName.trim().startsWith('#') ? newChannelName.trim() : `#${newChannelName.trim()}`;
    
    // Send create channel command with mode and password
    irc.createChannel(ch, newChannelMode, newChannelMode === 'password' ? newChannelPassword : undefined);
    
    setNewChannelName('');
    setNewChannelPassword('');
    setNewChannelMode('public');
    setShowCreateChannel(false);
  };

  const buffers = [...irc.channels, ...irc.queries];
  const activeMessages = irc.activeTarget ? (irc.messages[irc.activeTarget] || []) : [];
  const activeNicklist = irc.activeTarget && irc.activeTarget.startsWith('#') 
    ? (irc.nicklist[irc.activeTarget] || []) 
    : [];

  return (
    <div className="irc-client">
      <div className="irc-header">
        <div className="irc-header-left">
          <h1>IRC Client</h1>
          {!irc.connected && <span className="irc-status-connecting">Connecting...</span>}
          {irc.connected && <span className="irc-status-connected">Connected as {irc.nick || '...'}</span>}
        </div>
        <div className="irc-header-actions">
          <button type="button" onClick={() => setShowUserSettings(true)} title="Settings">
            ⚙️
          </button>
          {(user?.is_admin || user?.is_master_admin) && (
            <>
              <button type="button" onClick={() => setShowAdminSettings(true)} title="Server Settings">
                🔧
              </button>
              {(user?.is_master_admin || user?.is_admin) && (
                <button type="button" onClick={() => setShowAdminUsers(true)} title="User Management">
                  👥
                </button>
              )}
            </>
          )}
        </div>
      </div>

      <div className="irc-main">
        <div className="irc-sidebar">
          <div className="irc-sidebar-section">
            <h3>Channels</h3>
            {(user?.is_admin || user?.is_master_admin) && (
              <button 
                type="button" 
                className="irc-create-channel-btn"
                onClick={() => setShowCreateChannel(true)}
                title="Create Channel (Admin Only)"
              >
                + Create
              </button>
            )}
            <form onSubmit={handleJoinChannel} className="irc-join-form">
              <input
                type="text"
                value={joinChannelName}
                onChange={(e) => setJoinChannelName(e.target.value)}
                placeholder="Join channel..."
                className="irc-join-input"
              />
              <button type="submit">Join</button>
            </form>
            {irc.channels.map((ch) => (
              <div
                key={ch}
                className={`irc-channel-item ${irc.activeTarget === ch ? 'active' : ''}`}
                onClick={() => irc.setActiveTarget(ch)}
              >
                <span>{ch}</span>
                {irc.unread[ch] > 0 && <span className="irc-unread-badge">{irc.unread[ch]}</span>}
                <button
                  type="button"
                  className="irc-part-btn"
                  onClick={(e) => {
                    e.stopPropagation();
                    irc.partChannel(ch);
                  }}
                  title="Leave channel"
                >
                  ×
                </button>
              </div>
            ))}
          </div>

          <div className="irc-sidebar-section">
            <h3>Private Messages</h3>
            {irc.queries.map((nick) => (
              <div
                key={nick}
                className={`irc-channel-item ${irc.activeTarget === nick ? 'active' : ''}`}
                onClick={() => irc.setActiveTarget(nick)}
              >
                <span>{nick}</span>
                {irc.unread[nick] > 0 && <span className="irc-unread-badge">{irc.unread[nick]}</span>}
                <button
                  type="button"
                  className="irc-part-btn"
                  onClick={(e) => {
                    e.stopPropagation();
                    irc.closeQuery(nick);
                  }}
                  title="Close"
                >
                  ×
                </button>
              </div>
            ))}
          </div>

          {irc.activeTarget && irc.activeTarget.startsWith('#') && (
            <div className="irc-sidebar-section">
              <h3>Users in {irc.activeTarget}</h3>
              {activeNicklist.map((nick, idx) => (
                <div key={idx} className="irc-nick-item">
                  {nick}
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="irc-chat">
          {!irc.activeTarget ? (
            <div className="irc-welcome">
              <p>Select a channel or start a private message</p>
              <p>Use /join #channel to join a channel</p>
              <p>Use /msg nickname to start a private message</p>
            </div>
          ) : (
            <>
              <div className="irc-chat-header">
                <h2>{irc.activeTarget}</h2>
                {irc.activeTarget.startsWith('#') && irc.topics[irc.activeTarget] && (
                  <div className="irc-topic">{irc.topics[irc.activeTarget]}</div>
                )}
                <div className="irc-chat-header-actions">
                  {irc.activeTarget.startsWith('#') && (
                    <>
                      <button onClick={() => { setShowSearch(true); }} title="Search">🔍</button>
                      <button onClick={() => { setShowPinned(true); loadPinnedMessages(); }} title="Pinned Messages">📌</button>
                      <button onClick={refreshMessages} title="Refresh">🔄</button>
                    </>
                  )}
                </div>
              </div>
              <div className="irc-messages">
                {activeMessages.length === 0 ? (
                  <div className="irc-empty">No messages yet</div>
                ) : (
                  activeMessages.map((msg, idx) => (
                    <Message 
                      key={msg.id || idx} 
                      msg={msg}
                      currentNick={irc.nick}
                      onNickClick={(nick) => {
                        // TODO: Lookup user ID from nick
                        // For now, we'll need an API endpoint to get user by nick
                        setViewingProfile(null);
                      }}
                      onUpdate={refreshMessages}
                    />
                  ))
                )}
                <div ref={messagesEndRef} />
              </div>
              <StatusBar 
                channelModes={channelModes}
                userCount={userCount}
                operatorCount={operatorCount}
              />
              <form onSubmit={handleSendMessage} className="irc-input-form">
                <input
                  ref={fileInputRef}
                  type="file"
                  style={{ display: 'none' }}
                  onChange={handleFileUpload}
                />
                <button
                  type="button"
                  onClick={() => fileInputRef.current?.click()}
                  title="Upload file"
                >
                  📎
                </button>
                <input
                  ref={inputRef}
                  type="text"
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  onKeyDown={handleKeyDown}
                  placeholder={`Message ${irc.activeTarget}...`}
                  className="irc-input"
                  disabled={!irc.connected}
                />
                <button type="submit" disabled={!irc.connected || !input.trim()}>
                  Send
                </button>
              </form>
            </>
          )}
        </div>
      </div>

      {showCreateChannel && (
        <div className="irc-modal-overlay" onClick={() => setShowCreateChannel(false)}>
          <div className="irc-modal" onClick={(e) => e.stopPropagation()}>
            <h3>Create Channel (Admin Only)</h3>
            <form onSubmit={handleCreateChannel}>
              <label>
                Channel Name
                <input
                  type="text"
                  value={newChannelName}
                  onChange={(e) => setNewChannelName(e.target.value)}
                  placeholder="#channelname"
                  autoFocus
                  required
                />
              </label>
              <label>
                Channel Type
                <select
                  value={newChannelMode}
                  onChange={(e) => setNewChannelMode(e.target.value as 'public' | 'locked' | 'password')}
                >
                  <option value="public">Public (anyone can join)</option>
                  <option value="locked">Locked (invite only)</option>
                  <option value="password">Password Protected</option>
                </select>
              </label>
              {newChannelMode === 'password' && (
                <label>
                  Password
                  <input
                    type="password"
                    value={newChannelPassword}
                    onChange={(e) => setNewChannelPassword(e.target.value)}
                    placeholder="Channel password"
                    required
                  />
                </label>
              )}
              <div className="irc-modal-actions">
                <button type="button" onClick={() => {
                  setShowCreateChannel(false);
                  setNewChannelName('');
                  setNewChannelPassword('');
                  setNewChannelMode('public');
                }}>Cancel</button>
                <button type="submit">Create</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {showSearch && (
        <div className="irc-modal-overlay" onClick={() => setShowSearch(false)}>
          <div className="irc-modal" onClick={(e) => e.stopPropagation()}>
            <h3>Search Messages in {irc.activeTarget}</h3>
            <div className="irc-search-form">
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
                placeholder="Search..."
                autoFocus
              />
              <button onClick={handleSearch}>Search</button>
            </div>
            <div className="irc-search-results">
              {searchResults.length === 0 ? (
                <div className="irc-empty">No results</div>
              ) : (
                searchResults.map((msg) => (
                  <Message
                    key={msg.id}
                    msg={msg}
                    currentNick={irc.nick}
                    onNickClick={(nick) => setViewingProfile(null)}
                  />
                ))
              )}
            </div>
            <div className="irc-modal-actions">
              <button onClick={() => setShowSearch(false)}>Close</button>
            </div>
          </div>
        </div>
      )}

      {showPinned && (
        <div className="irc-modal-overlay" onClick={() => setShowPinned(false)}>
          <div className="irc-modal" onClick={(e) => e.stopPropagation()}>
            <h3>Pinned Messages in {irc.activeTarget}</h3>
            <div className="irc-pinned-messages">
              {pinnedMessages.length === 0 ? (
                <div className="irc-empty">No pinned messages</div>
              ) : (
                pinnedMessages.map((msg) => (
                  <Message
                    key={msg.id}
                    msg={msg}
                    currentNick={irc.nick}
                    onNickClick={(nick) => setViewingProfile(null)}
                    onUpdate={loadPinnedMessages}
                  />
                ))
              )}
            </div>
            <div className="irc-modal-actions">
              <button onClick={() => setShowPinned(false)}>Close</button>
            </div>
          </div>
        </div>
      )}

      {showUserSettings && <UserSettings onClose={() => setShowUserSettings(false)} />}
      {showAdminSettings && <AdminSettings onClose={() => setShowAdminSettings(false)} />}
      {showAdminUsers && <AdminUsers onClose={() => setShowAdminUsers(false)} />}
      {showRoleManager && <RoleManager onClose={() => setShowRoleManager(false)} />}
      {viewingProfile && <UserProfile userId={viewingProfile} onClose={() => setViewingProfile(null)} />}
    </div>
  );
}
