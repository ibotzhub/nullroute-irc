// Generate consistent colors for nicks

const COLORS = [
  '#4a9eff', '#4caf50', '#ff9800', '#f44336', '#9c27b0',
  '#00bcd4', '#ffeb3b', '#e91e63', '#795548', '#607d8b',
  '#3f51b5', '#009688', '#ff5722', '#673ab7', '#00acc1'
];

export function getNickColor(nick: string): string {
  if (!nick) return COLORS[0];
  
  let hash = 0;
  for (let i = 0; i < nick.length; i++) {
    hash = nick.charCodeAt(i) + ((hash << 5) - hash);
  }
  
  const index = Math.abs(hash) % COLORS.length;
  return COLORS[index];
}
