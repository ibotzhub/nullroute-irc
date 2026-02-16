import { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { parseMarkdown, detectMentions } from '../utils/markdown';
import { editMessage, deleteMessage, pinMessage, unpinMessage, addReaction, removeReaction, Message as MessageType } from '../utils/messages';
import { getNickColor } from '../utils/nickColors';
import './Message.css';

interface MessageProps {
  msg: MessageType & { nick?: string; message?: string; time?: string };
  currentNick?: string;
  onNickClick?: (nick: string) => void;
  onUpdate?: () => void;
}

const COMMON_EMOJIS = ['👍', '❤️', '😂', '😮', '😢', '🔥', '🎉', '👏'];

export function Message({ msg, currentNick, onNickClick, onUpdate }: MessageProps) {
  const { user } = useAuth();
  const [isEditing, setIsEditing] = useState(false);
  const [editContent, setEditContent] = useState(msg.content || msg.message || '');
  const [showReactions, setShowReactions] = useState(false);
  const isOwnMessage = user && (msg.user_id === user.id || msg.nick === currentNick);
  const canModerate = user?.is_admin || user?.is_master_admin;

  const time = msg.time || msg.inserted_at 
    ? new Date(msg.time || msg.inserted_at).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }) 
    : '';

  const handleEdit = async () => {
    if (!msg.id) return;
    const updated = await editMessage(msg.id, editContent);
    if (updated) {
      setIsEditing(false);
      onUpdate?.();
    }
  };

  const handleDelete = async () => {
    if (!msg.id || !confirm('Delete this message?')) return;
    const success = await deleteMessage(msg.id);
    if (success) {
      onUpdate?.();
    }
  };

  const handlePin = async () => {
    if (!msg.id) return;
    if (msg.pinned) {
      await unpinMessage(msg.id);
    } else {
      await pinMessage(msg.id);
    }
    onUpdate?.();
  };

  const handleReaction = async (emoji: string) => {
    if (!msg.id) return;
    const existing = msg.reactions?.find(r => r.emoji === emoji && r.user_id === user?.id);
    if (existing) {
      await removeReaction(msg.id, emoji);
    } else {
      await addReaction(msg.id, emoji);
    }
    onUpdate?.();
  };

  const content = msg.content || msg.message || '';
  const displayName = msg.user?.display_name || msg.nick || 'Unknown';
  const nick = msg.nick || displayName;
  
  // Parse markdown and detect mentions
  let htmlContent = parseMarkdown(content);
  if (currentNick) {
    htmlContent = detectMentions(htmlContent, currentNick);
  }

  if (msg.type === 'action') {
    return (
      <div className={`irc-message irc-message-action ${msg.pinned ? 'pinned' : ''}`}>
        <span className="irc-message-time">{time}</span>
        <span className="irc-message-text" dangerouslySetInnerHTML={{ __html: `* <span class="irc-message-nick clickable" onClick={() => onNickClick?.(nick)}>${nick}</span> ${htmlContent}` }} />
        {msg.edited_at && <span className="irc-message-edited">(edited)</span>}
        {msg.pinned && <span className="irc-message-pinned">📌</span>}
        {isOwnMessage && (
          <div className="irc-message-actions">
            <button onClick={() => setIsEditing(true)}>Edit</button>
            <button onClick={handleDelete}>Delete</button>
          </div>
        )}
        {canModerate && (
          <button onClick={handlePin}>{msg.pinned ? 'Unpin' : 'Pin'}</button>
        )}
      </div>
    );
  }

  if (isEditing) {
    return (
      <div className="irc-message irc-message-editing">
        <input
          value={editContent}
          onChange={(e) => setEditContent(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              handleEdit();
            }
            if (e.key === 'Escape') {
              setIsEditing(false);
              setEditContent(msg.content || msg.message || '');
            }
          }}
          autoFocus
        />
        <button onClick={handleEdit}>Save</button>
        <button onClick={() => {
          setIsEditing(false);
          setEditContent(msg.content || msg.message || '');
        }}>Cancel</button>
      </div>
    );
  }

  return (
    <div className={`irc-message ${msg.pinned ? 'pinned' : ''}`}>
      <span className="irc-message-time">{time}</span>
      <span 
        className="irc-message-nick clickable" 
        onClick={() => onNickClick?.(nick)}
        title="View profile"
        style={{ color: getNickColor(nick) }}
      >
        {displayName}
        {msg.user?.unique_id && <span className="irc-message-unique-id">#{msg.user.unique_id}</span>}
      </span>
      <span 
        className="irc-message-text" 
        dangerouslySetInnerHTML={{ __html: htmlContent }}
      />
      {msg.edited_at && <span className="irc-message-edited">(edited)</span>}
      {msg.pinned && <span className="irc-message-pinned">📌</span>}
      
      {/* Reactions */}
      {msg.reactions && msg.reactions.length > 0 && (
        <div className="irc-message-reactions">
          {Object.entries(
            msg.reactions.reduce((acc: Record<string, number[]>, r) => {
              if (!acc[r.emoji]) acc[r.emoji] = [];
              acc[r.emoji].push(r.user_id);
              return acc;
            }, {})
          ).map(([emoji, userIds]) => (
            <button
              key={emoji}
              className={`irc-reaction ${userIds.includes(user?.id || -1) ? 'active' : ''}`}
              onClick={() => handleReaction(emoji)}
              title={userIds.length.toString()}
            >
              {emoji} {userIds.length}
            </button>
          ))}
        </div>
      )}

      {/* Message actions */}
      <div className="irc-message-actions">
        <button onClick={() => setShowReactions(!showReactions)}>😀</button>
        {isOwnMessage && (
          <>
            <button onClick={() => setIsEditing(true)}>Edit</button>
            <button onClick={handleDelete}>Delete</button>
          </>
        )}
        {canModerate && (
          <button onClick={handlePin}>{msg.pinned ? 'Unpin' : 'Pin'}</button>
        )}
      </div>

      {/* Reaction picker */}
      {showReactions && (
        <div className="irc-reaction-picker">
          {COMMON_EMOJIS.map(emoji => (
            <button
              key={emoji}
              onClick={() => {
                handleReaction(emoji);
                setShowReactions(false);
              }}
            >
              {emoji}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
