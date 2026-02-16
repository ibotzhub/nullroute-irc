declare module 'phoenix' {
  export class Socket {
    constructor(endPoint: string, opts?: { params?: Record<string, string> });
    connect(): void;
    disconnect(callback?: () => void): void;
    channel(topic: string, params?: Record<string, any>): Channel;
  }

  export class Channel {
    join(timeout?: number): Push;
    leave(timeout?: number): Push;
    on(event: string, callback: (payload: any) => void): void;
    off(event: string, callback?: (payload: any) => void): void;
    push(event: string, payload: Record<string, any>): Push;
  }

  export class Push {
    receive(status: string, callback: (response: any) => void): Push;
  }
}
