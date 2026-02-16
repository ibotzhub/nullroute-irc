import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';

interface Role {
  id: number;
  name: string;
  color: string;
}

interface User {
  id: number;
  username: string;
  is_admin: boolean;
  is_master_admin?: boolean;
  is_approved: boolean;
  theme?: string;
  roles?: Role[];
}

interface AdminUsersProps {
  onClose: () => void;
}

export function AdminUsers({ onClose }: AdminUsersProps) {
  const { user: currentUser } = useAuth();
  const [users, setUsers] = useState<User[]>([]);
  const [roles, setRoles] = useState<Role[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedUser, setSelectedUser] = useState<User | null>(null);

  useEffect(() => {
    Promise.all([
      fetch('/api/admin/users', { credentials: 'include' }).then(res => res.json()),
      fetch('/api/admin/roles', { credentials: 'include' }).then(res => res.json())
    ]).then(([usersData, rolesData]) => {
      setUsers(usersData.users || []);
      setRoles(rolesData.roles || []);
      setLoading(false);
    }).catch(() => {
      setError('Failed to load data');
      setLoading(false);
    });
  }, []);

  const assignRole = async (userId: number, roleId: number) => {
    try {
      const res = await fetch('/api/admin/roles/assign', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ user_id: userId, role_id: roleId }),
      });
      if (res.ok) {
        // Reload users
        const usersRes = await fetch('/api/admin/users', { credentials: 'include' });
        const usersData = await usersRes.json();
        setUsers(usersData.users || []);
      } else {
        const data = await res.json();
        setError(data.error || 'Failed to assign role');
      }
    } catch {
      setError('Failed to assign role');
    }
  };

  const removeRole = async (userId: number, roleId: number) => {
    try {
      const res = await fetch('/api/admin/roles/remove', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ user_id: userId, role_id: roleId }),
      });
      if (res.ok) {
        // Reload users
        const usersRes = await fetch('/api/admin/users', { credentials: 'include' });
        const usersData = await usersRes.json();
        setUsers(usersData.users || []);
      } else {
        const data = await res.json();
        setError(data.error || 'Failed to remove role');
      }
    } catch {
      setError('Failed to remove role');
    }
  };

  const approve = async (id: number) => {
    try {
      const res = await fetch(`/api/admin/users/${id}/approve`, {
        method: 'POST',
        credentials: 'include',
      });
      if (res.ok) {
        setUsers((prev) => prev.map((u) => (u.id === id ? { ...u, is_approved: true } : u)));
      } else {
        setError('Failed to approve user');
      }
    } catch {
      setError('Failed to approve user');
    }
  };

  const setAdmin = async (id: number, isAdmin: boolean) => {
    // Only master admin can assign admin roles
    if (!currentUser?.is_master_admin) {
      setError('Only master admin can assign admin roles');
      return;
    }
    try {
      const res = await fetch(`/api/admin/users/${id}/admin`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ isAdmin }),
      });
      if (res.ok) {
        setUsers((prev) => prev.map((u) => (u.id === id ? { ...u, is_admin: isAdmin } : u)));
      } else {
        const data = await res.json();
        setError(data.error || 'Failed to update user');
      }
    } catch {
      setError('Failed to update user');
    }
  };

  const setMasterAdmin = async (id: number, isMasterAdmin: boolean) => {
    // Only master admin can assign master admin role
    if (!currentUser?.is_master_admin) {
      setError('Only master admin can assign master admin role');
      return;
    }
    try {
      const res = await fetch(`/api/admin/users/${id}/master_admin`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ isMasterAdmin }),
      });
      if (res.ok) {
        setUsers((prev) => prev.map((u) => (u.id === id ? { ...u, is_master_admin: isMasterAdmin } : u)));
      } else {
        const data = await res.json();
        setError(data.error || 'Failed to update user');
      }
    } catch {
      setError('Failed to update user');
    }
  };

  return (
    <div className="admin-users-overlay" onClick={onClose}>
      <div className="admin-users-modal" onClick={(e) => e.stopPropagation()}>
        <div className="admin-users-header">
          <h2>User Management</h2>
          <button type="button" className="admin-users-close" onClick={onClose}>×</button>
        </div>
        {error && <p className="admin-users-error">{error}</p>}
        {loading ? (
          <p>Loading...</p>
        ) : (
          <div className="admin-users-list">
            {users.map((u) => (
              <div key={u.id} className="admin-users-row">
                <span className="admin-users-name">{u.username}</span>
                <span className="admin-users-badges">
                  {u.is_master_admin && <span className="badge master-admin">Master Admin</span>}
                  {u.is_admin && !u.is_master_admin && <span className="badge admin">Admin</span>}
                  {u.roles?.map((r) => (
                    <span key={r.id} className="badge role-badge" style={{ backgroundColor: r.color }}>
                      {r.name}
                    </span>
                  ))}
                  {!u.is_approved && <span className="badge pending">pending</span>}
                </span>
                <span className="admin-users-actions">
                  {!u.is_approved && (
                    <button type="button" onClick={() => approve(u.id)}>Approve</button>
                  )}
                  {currentUser?.is_master_admin && (
                    <>
                      {!u.is_admin && u.is_approved && (
                        <button type="button" onClick={() => setAdmin(u.id, true)}>Make Admin</button>
                      )}
                      {u.is_admin && !u.is_master_admin && (
                        <>
                          <button type="button" className="danger" onClick={() => setAdmin(u.id, false)}>
                            Remove Admin
                          </button>
                          <button type="button" onClick={() => setMasterAdmin(u.id, true)}>Make Master</button>
                        </>
                      )}
                      {u.is_master_admin && u.id !== currentUser.id && (
                        <button type="button" className="danger" onClick={() => setMasterAdmin(u.id, false)}>
                          Remove Master
                        </button>
                      )}
                    </>
                  )}
                  <button type="button" onClick={() => setSelectedUser(u)}>Manage Roles</button>
                </span>
              </div>
            ))}
          </div>
        )}
      </div>

      {selectedUser && (
        <div className="role-assignment-overlay" onClick={() => setSelectedUser(null)}>
          <div className="role-assignment-modal" onClick={(e) => e.stopPropagation()}>
            <h3>Manage Roles for {selectedUser.username}</h3>
            <div className="role-assignment-list">
              {roles.map((role) => {
                const hasRole = selectedUser.roles?.some((r) => r.id === role.id);
                return (
                  <div key={role.id} className="role-assignment-item">
                    <span className="role-badge" style={{ backgroundColor: role.color }}>
                      {role.name}
                    </span>
                    {hasRole ? (
                      <button
                        type="button"
                        className="danger"
                        onClick={() => removeRole(selectedUser.id, role.id)}
                      >
                        Remove
                      </button>
                    ) : (
                      <button
                        type="button"
                        onClick={() => assignRole(selectedUser.id, role.id)}
                      >
                        Assign
                      </button>
                    )}
                  </div>
                );
              })}
            </div>
            <button type="button" onClick={() => setSelectedUser(null)}>Close</button>
          </div>
        </div>
      )}
    </div>
  );
}
