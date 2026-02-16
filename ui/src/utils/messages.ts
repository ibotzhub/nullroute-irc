import api from '../api';

export interface Message {
  id: number;
  user_id: number;
  channel: string;
  nick: string;
  content: string;
  message_type: 'message' | 'action' | 'system';
  edited_at?: string;
  pinned: boolean;
  pinned_at?: string;
  inserted_at: string;
  reactions?: Reaction[];
  user?: {
    id: number;
    username: string;
    display_name?: string;
    unique_id?: string;
    avatar_url?: string;
  };
}

export interface Reaction {
  id: number;
  emoji: string;
  user_id: number;
  user?: {
    id: number;
    username: string;
    display_name?: string;
    unique_id?: string;
  };
}

export async function loadMessages(channel: string, limit = 50, beforeId?: number): Promise<Message[]> {
  try {
    const params: any = { channel, limit: limit.toString() };
    if (beforeId) params.before_id = beforeId.toString();
    const response = await api.get('/api/messages', { params });
    return response.data.messages || [];
  } catch (error) {
    console.error('Failed to load messages:', error);
    return [];
  }
}

export async function editMessage(messageId: number, content: string): Promise<Message | null> {
  try {
    const response = await api.put(`/api/messages/${messageId}`, { content });
    return response.data.message || null;
  } catch (error) {
    console.error('Failed to edit message:', error);
    return null;
  }
}

export async function deleteMessage(messageId: number): Promise<boolean> {
  try {
    await api.delete(`/api/messages/${messageId}`);
    return true;
  } catch (error) {
    console.error('Failed to delete message:', error);
    return false;
  }
}

export async function pinMessage(messageId: number): Promise<Message | null> {
  try {
    const response = await api.post(`/api/messages/${messageId}/pin`);
    return response.data.message || null;
  } catch (error) {
    console.error('Failed to pin message:', error);
    return null;
  }
}

export async function unpinMessage(messageId: number): Promise<Message | null> {
  try {
    const response = await api.post(`/api/messages/${messageId}/unpin`);
    return response.data.message || null;
  } catch (error) {
    console.error('Failed to unpin message:', error);
    return null;
  }
}

export async function addReaction(messageId: number, emoji: string): Promise<Reaction | null> {
  try {
    const response = await api.post(`/api/messages/${messageId}/reactions`, { emoji });
    return response.data.reaction || null;
  } catch (error) {
    console.error('Failed to add reaction:', error);
    return null;
  }
}

export async function removeReaction(messageId: number, emoji: string): Promise<boolean> {
  try {
    await api.delete(`/api/messages/${messageId}/reactions`, { params: { emoji } });
    return true;
  } catch (error) {
    console.error('Failed to remove reaction:', error);
    return false;
  }
}

export async function searchMessages(channel: string, query: string): Promise<Message[]> {
  try {
    const response = await api.get(`/api/messages/channel/${encodeURIComponent(channel)}/search`, {
      params: { query }
    });
    return response.data.messages || [];
  } catch (error) {
    console.error('Failed to search messages:', error);
    return [];
  }
}

export async function getPinnedMessages(channel: string): Promise<Message[]> {
  try {
    const response = await api.get(`/api/messages/channel/${encodeURIComponent(channel)}/pinned`);
    return response.data.messages || [];
  } catch (error) {
    console.error('Failed to load pinned messages:', error);
    return [];
  }
}

export async function uploadFile(file: File): Promise<{ url: string; filename: string } | null> {
  try {
    const formData = new FormData();
    formData.append('file', file);
    const response = await api.post('/api/upload', formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    });
    return response.data || null;
  } catch (error) {
    console.error('Failed to upload file:', error);
    return null;
  }
}
