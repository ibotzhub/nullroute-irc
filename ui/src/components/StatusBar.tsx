import { useIRC } from '../contexts/IRCContext';
import { useAuth } from '../contexts/AuthContext';
import './StatusBar.css';

interface StatusBarProps {
  channelModes?: string[];
  userCount?: number;
  operatorCount?: number;
}

export function StatusBar({ channelModes = [], userCount = 0, operatorCount = 0 }: StatusBarProps) {
  const irc = useIRC();
  const { user } = useAuth();
  const currentTime = new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
  
  const modeString = channelModes.length > 0 ? `+${channelModes.join('')}` : '';
  const statusText = irc.connected ? 'Connected' : 'Connecting...';
  const statusClass = irc.connected ? 'status-connected' : 'status-connecting';
  
  return (
    <div className="irc-status-bar">
      <div className="status-bar-left">
        <span className={`status-indicator ${statusClass}`}>●</span>
        <span className="status-text">{statusText}</span>
        {irc.nick && <span className="current-nick">{irc.nick}</span>}
        {user?.away && <span className="away-indicator">(Away)</span>}
      </div>
      <div className="status-bar-center">
        {irc.activeTarget && (
          <>
            <span className="channel-name">{irc.activeTarget}</span>
            {modeString && <span className="channel-modes">{modeString}</span>}
            {userCount > 0 && (
              <span className="user-count">
                {operatorCount > 0 && `${operatorCount} ops, `}
                {userCount} users
              </span>
            )}
          </>
        )}
      </div>
      <div className="status-bar-right">
        <span className="current-time">{currentTime}</span>
      </div>
    </div>
  );
}
