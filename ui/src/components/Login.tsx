import { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import './Login.css';

export function Login() {
  const { login, register } = useAuth();
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      if (mode === 'register') {
        if (password !== confirmPassword) {
          setError('Passwords do not match');
          setLoading(false);
          return;
        }
        if (password.length < 8) {
          setError('Password must be at least 8 characters');
          setLoading(false);
          return;
        }
        const data = await register(username, password);
        if (data.error) setError(data.error || 'Registration failed');
      } else {
        const data = await login(username, password);
        if (data.error) setError(data.error || 'Invalid username or password');
      }
    } catch {
      setError('Something went wrong. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <h1 className="login-title">NullRoute IRC</h1>
        <p className="login-subtitle">
          {mode === 'login' ? 'Sign in to continue' : 'Create an account'}
        </p>

        <form onSubmit={handleSubmit} className="login-form">
          <input
            type="text"
            placeholder="Username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            className="login-input"
            required
            autoComplete="username"
            autoFocus
          />
          <input
            type="password"
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="login-input"
            required
            autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
          />
          {mode === 'register' && (
            <input
              type="password"
              placeholder="Confirm password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              className="login-input"
              required
              autoComplete="new-password"
            />
          )}
          {error && <p className="login-error">{error}</p>}
          <button type="submit" className="login-button" disabled={loading}>
            {loading ? 'Please wait...' : mode === 'login' ? 'Log in' : 'Register'}
          </button>
        </form>

        <button
          type="button"
          className="login-toggle"
          onClick={() => {
            setMode(mode === 'login' ? 'register' : 'login');
            setError('');
            setConfirmPassword('');
          }}
        >
          {mode === 'login'
            ? "Don't have an account? Register"
            : 'Already have an account? Log in'}
        </button>
      </div>
    </div>
  );
}
