import type {
  RealtimeClientSecret,
  RealtimeClientSecretCreateParams,
  RealtimeTranscriptionSession,
  RealtimeTranscriptionSessionCreateParams,
  RealtimeWebRTCOptions,
  RealtimeWebSocketOptions,
} from '../../models/Realtime';
import { OpenAIRealtimeWebRTC } from '../core/OpenAIRealtimeWebRTC';
import { OpenAIRealtimeWebSocket } from '../core/OpenAIRealtimeWebSocket';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';

/**
 * Realtime 资源入口。
 *
 * API：`/v1/realtime`。
 * 说明：当前覆盖 REST token/session 创建；WebSocket/WebRTC 流式连接后续由专用 transport 实现。
 */
export interface OpenAIRealtimeResource {
  /** Client secrets 子资源。API：Realtime client secrets。说明：生成客户端短期凭证。 */
  clientSecrets: OpenAIRealtimeClientSecretsResource;
  /** Transcription sessions 子资源。API：Realtime transcription sessions。说明：创建实时转写 session。 */
  transcriptionSessions: OpenAIRealtimeTranscriptionSessionsResource;
  /** 建立 WebSocket 连接。API：Realtime WebSocket。说明：连接 Realtime 事件流。 */
  connectWebSocket(options: RealtimeWebSocketOptions): Promise<OpenAIRealtimeWebSocket>;
  /** 建立 WebRTC 连接。API：Realtime WebRTC。说明：使用 `@ohos/webrtc` 交换 SDP 并建立 data channel。 */
  connectWebRTC(options: RealtimeWebRTCOptions): Promise<OpenAIRealtimeWebRTC>;
}

/**
 * Realtime client secrets 子资源。
 *
 * API：`/v1/realtime/client_secrets`。
 * 说明：生成可暴露给客户端的短期凭证。
 */
export interface OpenAIRealtimeClientSecretsResource {
  /** 创建 client secret。API：Create Realtime client secret。说明：返回 `ek_...` 短期凭证。 */
  create(params: RealtimeClientSecretCreateParams): Promise<RealtimeClientSecret>;
}

/**
 * Realtime transcription sessions 子资源。
 *
 * API：`/v1/realtime/transcription_sessions`。
 * 说明：创建转写专用 session 和短期凭证。
 */
export interface OpenAIRealtimeTranscriptionSessionsResource {
  /** 创建 transcription session。API：Create transcription session。说明：返回带 client_secret 的 session。 */
  create(params: RealtimeTranscriptionSessionCreateParams): Promise<RealtimeTranscriptionSession>;
}

export class RealtimeResource implements OpenAIRealtimeResource {
  clientSecrets: OpenAIRealtimeClientSecretsResource;
  transcriptionSessions: OpenAIRealtimeTranscriptionSessionsResource;
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
    this.clientSecrets = new RealtimeClientSecretsResource(client);
    this.transcriptionSessions = new RealtimeTranscriptionSessionsResource(client);
  }

  async connectWebSocket(options: RealtimeWebSocketOptions): Promise<OpenAIRealtimeWebSocket> {
    const opts = { ...options };
    if (opts.apiKey === undefined) {
      opts.apiKey = this.client.getAPIKey();
    }
    if (opts.url === undefined) {
      opts.url = this.buildRealtimeWebSocketURL(opts.model);
    }
    const connection = new OpenAIRealtimeWebSocket(opts);
    return await connection.connect();
  }

  async connectWebRTC(options: RealtimeWebRTCOptions): Promise<OpenAIRealtimeWebRTC> {
    const opts = { ...options };
    if (opts.apiKey === undefined) {
      opts.apiKey = this.client.getAPIKey();
    }
    const connection = new OpenAIRealtimeWebRTC(this.client, opts);
    return await connection.connect();
  }

  private buildRealtimeWebSocketURL(model: string): string {
    const baseURL = this.client.getBaseURL();
    let websocketBase = baseURL;
    if (websocketBase.startsWith('https://')) {
      websocketBase = 'wss://' + websocketBase.substring('https://'.length);
    } else if (websocketBase.startsWith('http://')) {
      websocketBase = 'ws://' + websocketBase.substring('http://'.length);
    }
    return websocketBase + '/realtime?model=' + encodeURIComponent(model);
  }
}

class RealtimeClientSecretsResource implements OpenAIRealtimeClientSecretsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: RealtimeClientSecretCreateParams): Promise<RealtimeClientSecret> {
    const body = await this.client.post('/realtime/client_secrets', params);
    return JSON.parse(body) as RealtimeClientSecret;
  }
}

class RealtimeTranscriptionSessionsResource implements OpenAIRealtimeTranscriptionSessionsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: RealtimeTranscriptionSessionCreateParams): Promise<RealtimeTranscriptionSession> {
    const body = await this.client.post('/realtime/transcription_sessions', params);
    return JSON.parse(body) as RealtimeTranscriptionSession;
  }
}
