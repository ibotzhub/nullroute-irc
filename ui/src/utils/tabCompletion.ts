// Tab completion for nicks, channels, and commands

export function completeNick(input: string, nicks: string[], currentNick?: string): string | null {
  if (!input.trim() || !nicks.length) return null;
  
  const lastWord = input.split(/\s+/).pop() || '';
  if (!lastWord || lastWord.startsWith('/')) return null;
  
  // Filter out current nick
  const filteredNicks = nicks.filter(n => n !== currentNick);
  
  // Find matching nicks
  const matches = filteredNicks.filter(nick => 
    nick.toLowerCase().startsWith(lastWord.toLowerCase())
  );
  
  if (matches.length === 1) {
    const prefix = input.substring(0, input.length - lastWord.length);
    return prefix + matches[0] + ' ';
  }
  
  if (matches.length > 1) {
    // Find common prefix
    const commonPrefix = findCommonPrefix(matches.map(n => n.toLowerCase()));
    if (commonPrefix.length > lastWord.length) {
      const prefix = input.substring(0, input.length - lastWord.length);
      return prefix + commonPrefix;
    }
  }
  
  return null;
}

export function completeChannel(input: string, channels: string[]): string | null {
  if (!input.trim() || !channels.length) return null;
  
  const lastWord = input.split(/\s+/).pop() || '';
  if (!lastWord.startsWith('#')) return null;
  
  const matches = channels.filter(ch => 
    ch.toLowerCase().startsWith(lastWord.toLowerCase())
  );
  
  if (matches.length === 1) {
    const prefix = input.substring(0, input.length - lastWord.length);
    return prefix + matches[0] + ' ';
  }
  
  if (matches.length > 1) {
    const commonPrefix = findCommonPrefix(matches.map(c => c.toLowerCase()));
    if (commonPrefix.length > lastWord.length) {
      const prefix = input.substring(0, input.length - lastWord.length);
      return prefix + commonPrefix;
    }
  }
  
  return null;
}

export function completeCommand(input: string): string | null {
  if (!input.startsWith('/')) return null;
  
  const commands = [
    '/join', '/part', '/nick', '/me', '/msg', '/whois', '/who', '/mode',
    '/away', '/ignore', '/unignore', '/kick', '/ban', '/invite', '/topic',
    '/list', '/search', '/help'
  ];
  
  const matches = commands.filter(cmd => 
    cmd.toLowerCase().startsWith(input.toLowerCase())
  );
  
  if (matches.length === 1) {
    return matches[0] + ' ';
  }
  
  if (matches.length > 1) {
    const commonPrefix = findCommonPrefix(matches.map(c => c.toLowerCase()));
    if (commonPrefix.length > input.length) {
      return commonPrefix;
    }
  }
  
  return null;
}

function findCommonPrefix(strings: string[]): string {
  if (strings.length === 0) return '';
  if (strings.length === 1) return strings[0];
  
  let prefix = strings[0];
  for (let i = 1; i < strings.length; i++) {
    while (!strings[i].startsWith(prefix)) {
      prefix = prefix.slice(0, -1);
      if (!prefix) return '';
    }
  }
  return prefix;
}
