import axios from 'axios';

export function getErrorMessage(err: any, fallback = 'Something went wrong'): string {
  if (!err) return fallback;
  const data = err.response?.data;
  const status = err.response?.status;

  if (data && typeof data === 'object' && typeof data.error === 'string') {
    return data.error;
  }

  if (typeof data === 'string' && (data.trim().startsWith('<') || data.includes('<!DOCTYPE'))) {
    if (status === 502 || status === 503) return 'Server temporarily unavailable - try again in a moment';
    if (status === 404) return 'Server route not found - the app may need to be restarted';
    if (status >= 500) return 'Server error - please try again later';
    return 'Connection problem - please try again';
  }

  if (err.message === 'Network Error' || !err.response) {
    return 'Cannot connect - check your connection and try again';
  }

  if (err.message?.includes('Unexpected token') || err.message?.includes('JSON')) {
    return 'Server returned an invalid response - please try again';
  }

  return err.message || fallback;
}

const api = axios.create({
  withCredentials: true,
  headers: { 'Content-Type': 'application/json' },
  transformResponse: (data) => {
    if (typeof data !== 'string') return data;
    const trimmed = data.trim();
    if (trimmed.startsWith('<') || trimmed.startsWith('<!')) {
      return data;
    }
    try {
      return JSON.parse(data);
    } catch {
      return data;
    }
  },
});

export default api;
