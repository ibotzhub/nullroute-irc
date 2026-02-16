import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import './RoleManager.css';

interface Role {
  id: number;
  name: string;
  color: string;
  permissions: {
    channels?: { create?: boolean; delete?: boolean; modify?: boolean; view?: boolean };
    users?: { kick?: boolean; ban?: boolean; mute?: boolean; view?: boolean };
    messages?: { delete?: boolean; pin?: boolean; moderate?: boolean };
    server?: { modify_settings?: boolean; view_logs?: boolean };
    roles?: { create?: boolean; assign?: boolean; modify?: boolean; delete?: boolean };
  };
  priority: number;
  user_count?: number;
}

interface RoleManagerProps {
  onClose: () => void;
}

export function RoleManager({ onClose }: RoleManagerProps) {
  const { user: currentUser } = useAuth();
  const [roles, setRoles] = useState<Role[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showCreateRole, setShowCreateRole] = useState(false);
  const [editingRole, setEditingRole] = useState<Role | null>(null);

  useEffect(() => {
    loadRoles();
  }, []);

  const loadRoles = async () => {
    try {
      const res = await fetch('/api/admin/roles', { credentials: 'include' });
      const data = await res.json();
      setRoles(data.roles || []);
      setLoading(false);
    } catch {
      setError('Failed to load roles');
      setLoading(false);
    }
  };

  const handleCreateRole = async (roleData: Partial<Role>) => {
    try {
      const res = await fetch('/api/admin/roles', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(roleData),
      });
      if (res.ok) {
        await loadRoles();
        setShowCreateRole(false);
      } else {
        const data = await res.json();
        setError(data.error || 'Failed to create role');
      }
    } catch {
      setError('Failed to create role');
    }
  };

  const handleUpdateRole = async (id: number, roleData: Partial<Role>) => {
    try {
      const res = await fetch(`/api/admin/roles/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(roleData),
      });
      if (res.ok) {
        await loadRoles();
        setEditingRole(null);
      } else {
        const data = await res.json();
        setError(data.error || 'Failed to update role');
      }
    } catch {
      setError('Failed to update role');
    }
  };

  const handleDeleteRole = async (id: number) => {
    if (!confirm('Are you sure you want to delete this role?')) return;
    try {
      const res = await fetch(`/api/admin/roles/${id}`, {
        method: 'DELETE',
        credentials: 'include',
      });
      if (res.ok) {
        await loadRoles();
      } else {
        const data = await res.json();
        setError(data.error || 'Failed to delete role');
      }
    } catch {
      setError('Failed to delete role');
    }
  };

  return (
    <div className="role-manager-overlay" onClick={onClose}>
      <div className="role-manager-modal" onClick={(e) => e.stopPropagation()}>
        <div className="role-manager-header">
          <h2>Role Management</h2>
          <button type="button" className="role-manager-close" onClick={onClose}>×</button>
        </div>
        {error && <p className="role-manager-error">{error}</p>}
        {loading ? (
          <p>Loading...</p>
        ) : (
          <>
            <div className="role-manager-actions">
              <button type="button" onClick={() => setShowCreateRole(true)}>
                + Create Role
              </button>
            </div>
            <div className="role-manager-list">
              {roles.map((role) => (
                <div key={role.id} className="role-manager-item">
                  <div className="role-manager-item-header">
                    <span className="role-badge" style={{ backgroundColor: role.color }}>
                      {role.name}
                    </span>
                    <span className="role-priority">Priority: {role.priority}</span>
                    {role.user_count !== undefined && (
                      <span className="role-user-count">{role.user_count} users</span>
                    )}
                  </div>
                  <div className="role-manager-item-actions">
                    <button type="button" onClick={() => setEditingRole(role)}>Edit</button>
                    <button type="button" className="danger" onClick={() => handleDeleteRole(role.id)}>
                      Delete
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </>
        )}
      </div>

      {showCreateRole && (
        <RoleEditor
          onSave={handleCreateRole}
          onCancel={() => setShowCreateRole(false)}
        />
      )}

      {editingRole && (
        <RoleEditor
          role={editingRole}
          onSave={(data) => handleUpdateRole(editingRole.id, data)}
          onCancel={() => setEditingRole(null)}
        />
      )}
    </div>
  );
}

interface RoleEditorProps {
  role?: Role;
  onSave: (data: Partial<Role>) => void;
  onCancel: () => void;
}

function RoleEditor({ role, onSave, onCancel }: RoleEditorProps) {
  const [name, setName] = useState(role?.name || '');
  const [color, setColor] = useState(role?.color || '#7289da');
  const [priority, setPriority] = useState(role?.priority || 0);
  const [permissions, setPermissions] = useState(role?.permissions || {
    channels: { create: false, delete: false, modify: false, view: true },
    users: { kick: false, ban: false, mute: false, view: true },
    messages: { delete: false, pin: false, moderate: false },
    server: { modify_settings: false, view_logs: false },
    roles: { create: false, assign: false, modify: false, delete: false },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSave({ name, color, priority, permissions });
  };

  const togglePermission = (category: string, action: string) => {
    setPermissions((prev) => ({
      ...prev,
      [category]: {
        ...prev[category as keyof typeof prev],
        [action]: !(prev[category as keyof typeof prev] as any)?.[action],
      },
    }));
  };

  return (
    <div className="role-editor-overlay" onClick={onCancel}>
      <div className="role-editor-modal" onClick={(e) => e.stopPropagation()}>
        <h3>{role ? 'Edit Role' : 'Create Role'}</h3>
        <form onSubmit={handleSubmit}>
          <label>
            Role Name
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              maxLength={32}
            />
          </label>
          <label>
            Color
            <input
              type="color"
              value={color}
              onChange={(e) => setColor(e.target.value)}
            />
          </label>
          <label>
            Priority (0-100, higher = more important)
            <input
              type="number"
              value={priority}
              onChange={(e) => setPriority(parseInt(e.target.value) || 0)}
              min={0}
              max={100}
            />
          </label>

          <div className="permissions-section">
            <h4>Permissions</h4>
            
            <div className="permission-category">
              <h5>Channels</h5>
              <label>
                <input
                  type="checkbox"
                  checked={permissions.channels?.create || false}
                  onChange={() => togglePermission('channels', 'create')}
                />
                Create Channels
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={permissions.channels?.delete || false}
                  onChange={() => togglePermission('channels', 'delete')}
                />
                Delete Channels
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={permissions.channels?.modify || false}
                  onChange={() => togglePermission('channels', 'modify')}
                />
                Modify Channels
              </label>
            </div>

            <div className="permission-category">
              <h5>Users</h5>
              <label>
                <input
                  type="checkbox"
                  checked={permissions.users?.kick || false}
                  onChange={() => togglePermission('users', 'kick')}
                />
                Kick Users
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={permissions.users?.ban || false}
                  onChange={() => togglePermission('users', 'ban')}
                />
                Ban Users
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={permissions.users?.mute || false}
                  onChange={() => togglePermission('users', 'mute')}
                />
                Mute Users
              </label>
            </div>

            <div className="permission-category">
              <h5>Messages</h5>
              <label>
                <input
                  type="checkbox"
                  checked={permissions.messages?.delete || false}
                  onChange={() => togglePermission('messages', 'delete')}
                />
                Delete Messages
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={permissions.messages?.pin || false}
                  onChange={() => togglePermission('messages', 'pin')}
                />
                Pin Messages
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={permissions.messages?.moderate || false}
                  onChange={() => togglePermission('messages', 'moderate')}
                />
                Moderate Messages
              </label>
            </div>

            <div className="permission-category">
              <h5>Server</h5>
              <label>
                <input
                  type="checkbox"
                  checked={permissions.server?.modify_settings || false}
                  onChange={() => togglePermission('server', 'modify_settings')}
                />
                Modify Server Settings
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={permissions.server?.view_logs || false}
                  onChange={() => togglePermission('server', 'view_logs')}
                />
                View Logs
              </label>
            </div>

            <div className="permission-category">
              <h5>Roles</h5>
              <label>
                <input
                  type="checkbox"
                  checked={permissions.roles?.create || false}
                  onChange={() => togglePermission('roles', 'create')}
                />
                Create Roles
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={permissions.roles?.assign || false}
                  onChange={() => togglePermission('roles', 'assign')}
                />
                Assign Roles
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={permissions.roles?.modify || false}
                  onChange={() => togglePermission('roles', 'modify')}
                />
                Modify Roles
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={permissions.roles?.delete || false}
                  onChange={() => togglePermission('roles', 'delete')}
                />
                Delete Roles
              </label>
            </div>
          </div>

          <div className="role-editor-actions">
            <button type="button" onClick={onCancel}>Cancel</button>
            <button type="submit">Save</button>
          </div>
        </form>
      </div>
    </div>
  );
}
