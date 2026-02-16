import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';

interface UserSettingsProps {
  onClose: () => void;
}

export function UserSettings({ onClose }: UserSettingsProps) {
  const { user } = useAuth();
  const [theme, setTheme] = useState('dark');
  const [autoJoinChannels, setAutoJoinChannels] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    fetch('/api/user/settings', { credentials: 'include' })
      .then(res => res.json())
      .then(data => {
        if (data.theme) {
          setTheme(data.theme);
        }
        if (data.auto_join_channels) {
          try {
            const channels = JSON.parse(data.auto_join_channels || '[]');
            setAutoJoinChannels(channels.join(', '));
          } catch {
            setAutoJoinChannels('');
          }
        }
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSaving(true);
    try {
      const channels = autoJoinChannels.split(',').map(c => c.trim()).filter(c => c);
      const res = await fetch('/api/user/settings', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ 
          theme,
          auto_join_channels: JSON.stringify(channels)
        }),
      });
      const data = await res.json();
      if (data.ok) {
        // Apply theme immediately
        document.documentElement.setAttribute('data-theme', theme);
        onClose();
      } else {
        setError(data.error || 'Failed to save settings');
      }
    } catch (err) {
      setError('Failed to save settings');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="settings-overlay" onClick={onClose}>
      <div className="settings-modal" onClick={(e) => e.stopPropagation()}>
        <div className="settings-header">
          <h2>Settings</h2>
          <button type="button" className="settings-close" onClick={onClose}>×</button>
        </div>
        {loading ? (
          <p>Loading...</p>
        ) : (
          <form onSubmit={handleSubmit}>
            {error && <p className="settings-error">{error}</p>}
            <label>
              Theme
              <select value={theme} onChange={(e) => setTheme(e.target.value)}>
                <option value="dark">Dark</option>
                <option value="light">Light</option>
              </select>
            </label>
            <label>
              Auto-join Channels (comma-separated)
              <input
                type="text"
                value={autoJoinChannels}
                onChange={(e) => setAutoJoinChannels(e.target.value)}
                placeholder="#channel1, #channel2"
              />
              <small>Channels to automatically join when connecting</small>
            </label>
            <div className="settings-actions">
              <button type="button" onClick={onClose}>Cancel</button>
              <button type="submit" disabled={saving}>
                {saving ? 'Saving...' : 'Save'}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}
