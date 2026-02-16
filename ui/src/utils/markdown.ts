// Simple markdown parser for IRC messages
export function parseMarkdown(text: string): string {
  // Escape HTML first
  let html = escapeHtml(text);
  
  // Bold: **text** or __text__
  html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  html = html.replace(/__(.+?)__/g, '<strong>$1</strong>');
  
  // Italic: *text* or _text_
  html = html.replace(/\*(.+?)\*/g, '<em>$1</em>');
  html = html.replace(/_(.+?)_/g, '<em>$1</em>');
  
  // Code: `code`
  html = html.replace(/`(.+?)`/g, '<code>$1</code>');
  
  // Links: http://... or https://...
  html = html.replace(/(https?:\/\/[^\s]+)/g, '<a href="$1" target="_blank" rel="noopener noreferrer">$1</a>');
  
  // Line breaks
  html = html.replace(/\n/g, '<br>');
  
  return html;
}

function escapeHtml(text: string): string {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

export function detectMentions(text: string, currentNick: string): string {
  // Highlight mentions of current user's nick
  const regex = new RegExp(`@?${escapeRegex(currentNick)}`, 'gi');
  return text.replace(regex, `<span class="mention">@${currentNick}</span>`);
}

function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
