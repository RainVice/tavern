import { webSocket } from '@kit.NetworkKit';
import util from '@ohos.util';
import type { BusinessError } from '@ohos.base';
import type { RealtimeClientEvent, RealtimeServerEvent, RealtimeWebSocketOptions } from '../../models/Realtime';
import type { OpenAIStream } from './Types';

/**
 * Realtime WebSocket 连接。
 *
 * API：Realtime WebSocket。
 * 说明：连接 `wss://api.openai.com/v1/realtime?model=...`，用 JSON 事件收发 Realtime 消息。
 */
export class OpenAIRealtimeWebSocket implements OpenAIStream {
  private socket: webSocket.WebSocket = webSocket.createWebSocket();
  private options: RealtimeWebSocketOptions;
  private closed: boolean = false;

  constructor(options: RealtimeWebSocketOptions) {
    this.options = options;
  }

  /** 建立 WebSocket 连接。API：Realtime WebSocket。说明：成功后可调用 sendEvent。 */
  async connect(): Promise<OpenAIRealtimeWebSocket> {
    this.bindHandlers();
    if (this.options.cancelToken !== undefined) {
      this.options.cancelToken.onCancel(() => {
        this.close();
      });
    }
    const requestOptions: webSocket.WebSocketRequestOptions = {
      header: this.buildHeaders(),
    };
    await this.socket.connect(this.buildURL(), requestOptions);
    return this;
  }

  /** 发送客户端事件。API：Realtime WebSocket。说明：例如 session.update、response.create。 */
  async sendEvent(event: RealtimeClientEvent): Promise<void> {
    await this.socket.send(JSON.stringify(event));
  }

  /** 关闭连接。API：Realtime WebSocket。说明：释放底层 WebSocket。 */
  close(): void {
    if (this.closed) {
      return;
    }
    this.closed = true;
    this.socket.close().catch(() => {
      this.socket = webSocket.createWebSocket();
    });
  }

  private bindHandlers(): void {
    const decoder = util.TextDecoder.create('utf-8');
    this.socket.on('message', (err: BusinessError, data: string | ArrayBuffer) => {
      if (err !== undefined && this.options.handlers !== undefined && this.options.handlers.onError !== undefined) {
        this.options.handlers.onError(err.message);
        return;
      }
      if (this.options.handlers === undefined || this.options.handlers.onEvent === undefined) {
        return;
      }
      const text = typeof data === 'string' ? data : decoder.decodeToString(new Uint8Array(data));
      this.options.handlers.onEvent(JSON.parse(text) as RealtimeServerEvent);
    });
    this.socket.on('error', (err: BusinessError) => {
      if (this.options.handlers !== undefined && this.options.handlers.onError !== undefined) {
        this.options.handlers.onError(err.message);
      }
    });
    this.socket.on('close', (_err: BusinessError, _result: webSocket.CloseResult) => {
      if (this.options.handlers !== undefined && this.options.handlers.onClose !== undefined) {
        this.options.handlers.onClose();
      }
    });
  }

  private buildURL(): string {
    if (this.options.url !== undefined && this.options.url.length > 0) {
      return this.options.url;
    }
    return 'wss://api.openai.com/v1/realtime?model=' + encodeURIComponent(this.options.model);
  }

  private buildHeaders(): Record<string, string> {
    const apiKey = this.options.apiKey === undefined ? '' : this.options.apiKey;
    const headers: Record<string, string> = {
      'Authorization': 'Bearer ' + apiKey,
      'OpenAI-Beta': 'realtime=v1',
    };
    if (this.options.headers !== undefined) {
      const keys = Object.keys(this.options.headers);
      for (let index = 0; index < keys.length; index++) {
        headers[keys[index]] = this.options.headers[keys[index]];
      }
    }
    return headers;
  }
}
