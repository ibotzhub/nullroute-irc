import { AuthProvider, useAuth } from './contexts/AuthContext';
import { IRCProvider } from './contexts/IRCContext';
import { IRCClient } from './components/IRCClient';
import { Login } from './components/Login';
import './App.css';

function AppContent() {
  const { user, loading } = useAuth();

  if (loading) {
    return <div className="app">Loading...</div>;
  }

  if (!user) {
    return <Login />;
  }

  return (
    <div className="app">
      <IRCProvider userId={user.id}>
        <IRCClient />
      </IRCProvider>
    </div>
  );
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}

export default App;
