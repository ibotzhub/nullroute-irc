// Notification utilities for highlights and sounds

let notificationPermission: NotificationPermission | null = null;

export async function requestNotificationPermission(): Promise<boolean> {
  if (!('Notification' in window)) return false;
  
  if (Notification.permission === 'granted') return true;
  if (Notification.permission === 'denied') return false;
  
  notificationPermission = await Notification.requestPermission();
  return notificationPermission === 'granted';
}

export function showNotification(title: string, options?: NotificationOptions) {
  if (!('Notification' in window) || Notification.permission !== 'granted') {
    return;
  }
  
  try {
    new Notification(title, {
      icon: '/favicon.ico',
      badge: '/favicon.ico',
      ...options
    });
  } catch (e) {
    console.error('Failed to show notification:', e);
  }
}

export function playSound(url: string = '/notification.mp3') {
  try {
    const audio = new Audio(url);
    audio.volume = 0.5;
    audio.play().catch(e => console.error('Failed to play sound:', e));
  } catch (e) {
    console.error('Failed to play sound:', e);
  }
}

export function detectMention(text: string, currentNick: string): boolean {
  if (!currentNick) return false;
  const regex = new RegExp(`@?${escapeRegex(currentNick)}`, 'i');
  return regex.test(text);
}

function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
