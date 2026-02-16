import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import './UserProfile.css';

interface Profile {
  id: number;
  username: string;
  display_name: string;
  unique_id: string;
  avatar_url?: string;
  bio?: string;
  joined_at: string;
  roles?: Array<{ id: number; name: string; color: string }>;
}

interface UserProfileProps {
  userId: number;
  onClose: () => void;
}

export function UserProfile({ userId, onClose }: UserProfileProps) {
  const { user: currentUser } = useAuth();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(false);
  const [displayName, setDisplayName] = useState('');
  const [bio, setBio] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    loadProfile();
  }, [userId]);

  const loadProfile = async () => {
    try {
      const res = await fetch(`/api/profile/${userId}`, { credentials: 'include' });
      const data = await res.json();
      if (data.profile) {
        setProfile(data.profile);
        setDisplayName(data.profile.display_name);
        setBio(data.profile.bio || '');
      }
      setLoading(false);
    } catch {
      setError('Failed to load profile');
      setLoading(false);
    }
  };

  const handleSave = async () => {
    try {
      const res = await fetch('/api/profile', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          display_name: displayName,
          bio: bio,
        }),
      });
      if (res.ok) {
        await loadProfile();
        setEditing(false);
      } else {
        const data = await res.json();
        setError(data.error || 'Failed to update profile');
      }
    } catch {
      setError('Failed to update profile');
    }
  };

  if (loading) {
    return (
      <div className="profile-overlay" onClick={onClose}>
        <div className="profile-modal" onClick={(e) => e.stopPropagation()}>
          <p>Loading...</p>
        </div>
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="profile-overlay" onClick={onClose}>
        <div className="profile-modal" onClick={(e) => e.stopPropagation()}>
          <p>Profile not found</p>
          <button onClick={onClose}>Close</button>
        </div>
      </div>
    );
  }

  const isOwnProfile = currentUser?.id === userId;
  const joinedDate = new Date(profile.joined_at).toLocaleDateString();

  return (
    <div className="profile-overlay" onClick={onClose}>
      <div className="profile-modal" onClick={(e) => e.stopPropagation()}>
        <div className="profile-header">
          <h2>User Profile</h2>
          <button type="button" className="profile-close" onClick={onClose}>×</button>
        </div>

        {error && <p className="profile-error">{error}</p>}

        <div className="profile-content">
          <div className="profile-avatar">
            {profile.avatar_url ? (
              <img src={profile.avatar_url} alt={profile.display_name} />
            ) : (
              <div className="profile-avatar-placeholder">
                {profile.display_name.charAt(0).toUpperCase()}
              </div>
            )}
          </div>

          <div className="profile-info">
            {editing && isOwnProfile ? (
              <>
                <label>
                  Display Name
                  <input
                    type="text"
                    value={displayName}
                    onChange={(e) => setDisplayName(e.target.value)}
                    maxLength={32}
                  />
                </label>
                <label>
                  Bio
                  <textarea
                    value={bio}
                    onChange={(e) => setBio(e.target.value)}
                    maxLength={500}
                    rows={4}
                  />
                </label>
                <div className="profile-actions">
                  <button onClick={handleSave}>Save</button>
                  <button onClick={() => {
                    setEditing(false);
                    setDisplayName(profile.display_name);
                    setBio(profile.bio || '');
                  }}>Cancel</button>
                </div>
              </>
            ) : (
              <>
                <div className="profile-name">
                  <h3>{profile.display_name}</h3>
                  <span className="profile-username">
                    @{profile.username}#{profile.unique_id}
                  </span>
                </div>
                {profile.bio && <p className="profile-bio">{profile.bio}</p>}
                <div className="profile-meta">
                  <p>Joined: {joinedDate}</p>
                  {profile.roles && profile.roles.length > 0 && (
                    <div className="profile-roles">
                      {profile.roles.map((role) => (
                        <span
                          key={role.id}
                          className="role-badge"
                          style={{ backgroundColor: role.color }}
                        >
                          {role.name}
                        </span>
                      ))}
                    </div>
                  )}
                </div>
                {isOwnProfile && (
                  <button onClick={() => setEditing(true)}>Edit Profile</button>
                )}
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
