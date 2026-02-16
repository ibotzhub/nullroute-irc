import { useState, useEffect } from 'react';

interface AdminSettingsProps {
  onClose: () => void;
  onSaved?: () => void;
}

export function AdminSettings({ onClose, onSaved }: AdminSettingsProps) {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [form, setForm] = useState({
    appTitle: 'NullRoute IRC',
    registrationMode: 'open',
    requireApproval: false,
    autoJoinChannels: '#lobby,#general',
    theme: 'dark',
  });

  useEffect(() => {
    fetch('/api/admin/settings', { credentials: 'include' })
      .then(res => res.json())
      .then(data => {
        setForm({
          appTitle: data.appTitle || 'NullRoute IRC',
          registrationMode: data.registrationMode || 'open',
          requireApproval: data.requireApproval ?? false,
          autoJoinChannels: (data.autoJoinChannels || ['#lobby']).join(', '),
          theme: data.theme || 'dark',
        });
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSaving(true);
    const autoJoin = form.autoJoinChannels
      .split(',')
      .map((c) => c.trim())
      .filter(Boolean);
    try {
      const res = await fetch('/api/admin/settings', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          appTitle: form.appTitle,
          registrationMode: form.registrationMode,
          requireApproval: form.requireApproval,
          autoJoinChannels: autoJoin.length ? autoJoin : ['#lobby'],
          theme: form.theme,
        }),
      });
      if (res.ok) {
        onSaved?.();
        onClose();
      } else {
        const data = await res.json();
        setError(data.error || 'Failed to save');
      }
    } catch (err) {
      setError('Failed to save');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="admin-settings-overlay" onClick={onClose}>
      <div className="admin-settings-modal" onClick={(e) => e.stopPropagation()}>
        <div className="admin-settings-header">
          <h2>Server Settings</h2>
          <button type="button" className="admin-settings-close" onClick={onClose}>×</button>
        </div>
        {loading ? (
          <p>Loading...</p>
        ) : (
          <form onSubmit={handleSubmit}>
            {error && <p className="admin-settings-error">{error}</p>}
            <label>
              App title
              <input
                type="text"
                value={form.appTitle}
                onChange={(e) => setForm((f) => ({ ...f, appTitle: e.target.value }))}
                placeholder="NullRoute IRC"
                maxLength={64}
              />
            </label>
            <label>
              Registration
              <select
                value={form.registrationMode}
                onChange={(e) => setForm((f) => ({ ...f, registrationMode: e.target.value }))}
              >
                <option value="open">Open (anyone can register)</option>
                <option value="approval">Approval required</option>
                <option value="closed">Closed (admin adds users)</option>
              </select>
            </label>
            <label>
              <input
                type="checkbox"
                checked={form.requireApproval}
                onChange={(e) => setForm((f) => ({ ...f, requireApproval: e.target.checked }))}
              />
              Require approval for new accounts
            </label>
            <label>
              Auto-join channels (comma-separated)
              <input
                type="text"
                value={form.autoJoinChannels}
                onChange={(e) => setForm((f) => ({ ...f, autoJoinChannels: e.target.value }))}
                placeholder="#lobby, #general"
              />
            </label>
            <label>
              Default theme
              <select
                value={form.theme}
                onChange={(e) => setForm((f) => ({ ...f, theme: e.target.value }))}
              >
                <option value="dark">Dark</option>
                <option value="light">Light</option>
              </select>
            </label>
            <div className="admin-settings-actions">
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
