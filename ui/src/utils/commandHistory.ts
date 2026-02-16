// Command history management using localStorage

const HISTORY_KEY = 'irc_command_history';
const MAX_HISTORY = 100;

export function saveToHistory(command: string) {
  if (!command.trim() || command.length < 2) return;
  
  try {
    const history = getHistory();
    // Remove duplicates
    const filtered = history.filter(c => c !== command);
    // Add to front
    const newHistory = [command, ...filtered].slice(0, MAX_HISTORY);
    localStorage.setItem(HISTORY_KEY, JSON.stringify(newHistory));
  } catch (e) {
    console.error('Failed to save command history:', e);
  }
}

export function getHistory(): string[] {
  try {
    const stored = localStorage.getItem(HISTORY_KEY);
    return stored ? JSON.parse(stored) : [];
  } catch (e) {
    return [];
  }
}

export function clearHistory() {
  try {
    localStorage.removeItem(HISTORY_KEY);
  } catch (e) {
    console.error('Failed to clear command history:', e);
  }
}
