import type { JsonObject, OpenAIModel } from './Common';

/**
 * Realtime REST API model。
 *
 * API：`/v1/realtime/client_secrets`、`/v1/realtime/transcription_sessions`。
 * 说明：用于创建客户端可用的短期 Realtime 凭证和转写 session。WebSocket/WebRTC 事件流由后续 transport 扩展实现。
 */

/** Realtime session 类型。API：Realtime。说明：对话 session 为 `realtime`，转写 session 为 `transcription`。 */
export type RealtimeSessionType = 'realtime' | 'transcription';

/** Realtime 输出模态。API：Realtime session。说明：当前常用 `audio` 或 `text`。 */
export type RealtimeOutputModality = 'audio' | 'text';

/** Realtime include 字段。API：Realtime。说明：用于请求输入音频转写 logprobs。 */
export type RealtimeInclude = 'item.input_audio_transcription.logprobs';

/** Realtime 输入音频格式。API：Realtime transcription session。说明：客户端追加音频时使用的编码格式。 */
export type RealtimeInputAudioFormat = 'pcm16' | 'g711_ulaw' | 'g711_alaw';

/** Realtime VAD 类型。API：Realtime session。说明：服务端或语义 VAD。 */
export type RealtimeTurnDetectionType = 'server_vad' | 'semantic_vad';

/** Realtime 最大输出 token。API：Realtime session。说明：`inf` 表示使用模型允许的最大值。 */
export type RealtimeMaxOutputTokens = number | 'inf';

/** Realtime 取消令牌形状。API：Realtime transports。说明：兼容 SDK OpenAICancelToken。 */
export interface RealtimeCancelToken {
  /** 注册取消回调。API：Realtime transports。说明：取消时关闭底层连接。 */
  onCancel(callback: () => void): void;
}

/** Realtime 事件回调。API：Realtime WebSocket/WebRTC。说明：收到服务端事件 JSON 字符串时触发。 */
export type RealtimeEventHandler = (event: RealtimeServerEvent) => void;

/** Realtime 错误回调。API：Realtime WebSocket/WebRTC。说明：网络或解析错误时触发。 */
export type RealtimeErrorHandler = (message: string) => void;

/** Realtime 关闭回调。API：Realtime WebSocket/WebRTC。说明：连接关闭时触发。 */
export type RealtimeCloseHandler = () => void;

/** Realtime transport 事件处理器。API：Realtime WebSocket/WebRTC。说明：统一管理事件、错误和关闭回调。 */
export interface RealtimeTransportHandlers {
  /** 收到服务端事件。API：Realtime。说明：WebSocket message 或 WebRTC data channel message。 */
  onEvent?: RealtimeEventHandler;
  /** 发生错误。API：Realtime。说明：底层连接异常或 JSON 解析异常。 */
  onError?: RealtimeErrorHandler;
  /** 连接关闭。API：Realtime。说明：主动 close 或远端关闭。 */
  onClose?: RealtimeCloseHandler;
}

/** Realtime WebSocket 连接选项。API：Realtime WebSocket。说明：连接 `wss://.../v1/realtime?model=...`。 */
export interface RealtimeWebSocketOptions {
  /** 模型。API：Realtime WebSocket。说明：例如 gpt-realtime。 */
  model: OpenAIModel;
  /** API key 或 ephemeral token。API：Realtime WebSocket。说明：服务端 SDK 可用主 API key，客户端应使用 ephemeral token。 */
  apiKey?: string;
  /** 自定义 WebSocket URL。API：Realtime WebSocket。说明：不传时由 baseURL 自动转换为 wss URL。 */
  url?: string;
  /** 额外 header。API：Realtime WebSocket。说明：会覆盖默认 Authorization/OpenAI-Beta。 */
  headers?: Record<string, string>;
  /** 事件处理器。API：Realtime WebSocket。说明：处理服务端事件、错误和关闭。 */
  handlers?: RealtimeTransportHandlers;
  /** 取消令牌。API：Realtime WebSocket。说明：取消时关闭 WebSocket。 */
  cancelToken?: RealtimeCancelToken;
}

/** Realtime WebRTC 连接选项。API：Realtime WebRTC。说明：通过 `/v1/realtime/calls` 交换 SDP。 */
export interface RealtimeWebRTCOptions {
  /** 模型。API：Realtime WebRTC。说明：用于 `/v1/realtime/calls?model=...`。 */
  model: OpenAIModel;
  /** API key 或 ephemeral token。API：Realtime WebRTC。说明：推荐传入 client secret value。 */
  apiKey?: string;
  /** 本地 SDP。API：Realtime WebRTC。说明：测试或自定义 peer connection 可直接传入；不传时 SDK 创建 offer。 */
  localSdp?: string;
  /** 是否包含本地麦克风音频。API：Realtime WebRTC。说明：true 时创建 AudioDeviceModule 和音频 track。 */
  includeAudio?: boolean;
  /** ICE server 配置。API：Realtime WebRTC。说明：传给 `RTCPeerConnection`。 */
  iceServers?: Array<RealtimeIceServer>;
  /** 额外 header。API：Realtime WebRTC。说明：会覆盖默认 Authorization/OpenAI-Beta。 */
  headers?: Record<string, string>;
  /** 事件处理器。API：Realtime WebRTC。说明：处理 data channel 服务端事件、错误和关闭。 */
  handlers?: RealtimeTransportHandlers;
  /** 取消令牌。API：Realtime WebRTC。说明：取消时关闭 peer connection 并释放音频模块。 */
  cancelToken?: RealtimeCancelToken;
}

/** Realtime ICE server。API：Realtime WebRTC。说明：传给 `RTCPeerConnection` 的 STUN/TURN 配置。 */
export interface RealtimeIceServer {
  /** ICE URL。API：Realtime WebRTC。说明：例如 stun: 或 turn: URL。 */
  urls: string | Array<string>;
  /** TURN 用户名。API：Realtime WebRTC。说明：TURN server 需要时传入。 */
  username?: string;
  /** TURN 凭据。API：Realtime WebRTC。说明：TURN server 需要时传入。 */
  credential?: string;
}

/**
 * Realtime 客户端事件类型。
 *
 * API：Realtime Client events。
 * 说明：客户端通过 WebSocket/WebRTC data channel 发送这些事件控制会话、对话项、音频缓冲和响应生成。
 */
export type RealtimeClientEventType =
  'session.update' |
  'conversation.item.create' |
  'conversation.item.retrieve' |
  'conversation.item.delete' |
  'input_audio_buffer.append' |
  'input_audio_buffer.commit' |
  'input_audio_buffer.clear' |
  'response.create' |
  'response.cancel' |
  'conversation.item.truncate' |
  'output_audio_buffer.clear' |
  'transcription_session.update';

/**
 * Realtime 服务端事件类型。
 *
 * API：Realtime Server events。
 * 说明：服务端向客户端推送会话、对话项、输入音频、响应、转写和错误等事件。
 */
export type RealtimeServerEventType =
  'error' |
  'session.created' |
  'session.updated' |
  'conversation.created' |
  'conversation.item.created' |
  'conversation.item.retrieved' |
  'conversation.item.deleted' |
  'conversation.item.truncated' |
  'conversation.item.input_audio_transcription.completed' |
  'conversation.item.input_audio_transcription.delta' |
  'conversation.item.input_audio_transcription.failed' |
  'input_audio_buffer.committed' |
  'input_audio_buffer.cleared' |
  'input_audio_buffer.speech_started' |
  'input_audio_buffer.speech_stopped' |
  'response.created' |
  'response.done' |
  'response.output_item.added' |
  'response.output_item.done' |
  'response.content_part.added' |
  'response.content_part.done' |
  'response.audio.delta' |
  'response.audio.done' |
  'response.audio_transcript.delta' |
  'response.audio_transcript.done' |
  'response.text.delta' |
  'response.text.done' |
  'response.function_call_arguments.delta' |
  'response.function_call_arguments.done' |
  'output_audio_buffer.started' |
  'output_audio_buffer.stopped' |
  'output_audio_buffer.cleared' |
  'rate_limits.updated' |
  'transcription_session.created' |
  'transcription_session.updated';

/**
 * Realtime 事件基础字段。
 *
 * API：Realtime events。
 * 说明：客户端事件和服务端事件都可携带事件 ID，用于调试或关联响应。
 */
export interface RealtimeEventBase<TEventType> {
  /**
   * 事件类型。
   *
   * API：Realtime events。
   * 说明：用于区分具体事件结构。
   */
  type: TEventType;

  /**
   * 事件 ID。
   *
   * API：Realtime events。
   * 说明：客户端可生成，服务端也会返回唯一事件 ID。
   */
  event_id?: string;
}

/**
 * Realtime 对话内容项。
 *
 * API：Realtime conversation item。
 * 说明：支持文本、音频、转写和工具调用内容块；扩展字段用 JsonObject 承接。
 */
export interface RealtimeConversationItemContent {
  /**
   * 内容类型。
   *
   * API：Realtime conversation item。
   * 说明：例如 `input_text`、`input_audio`、`text`、`audio`。
   */
  type: string;

  /**
   * 文本内容。
   *
   * API：Realtime conversation item。
   * 说明：文本输入或模型输出文本。
   */
  text?: string;

  /**
   * base64 音频数据。
   *
   * API：Realtime conversation item。
   * 说明：音频输入或输出内容。
   */
  audio?: string;

  /**
   * 转写文本。
   *
   * API：Realtime conversation item。
   * 说明：音频内容对应的转写。
   */
  transcript?: string;

  /**
   * 扩展字段。
   *
   * API：Realtime conversation item。
   * 说明：保留官方后续新增字段。
   */
  details?: JsonObject;
}

/**
 * Realtime 对话项。
 *
 * API：Realtime conversation item。
 * 说明：表示 message、function_call 或 function_call_output。
 */
export interface RealtimeConversationItem {
  /**
   * 对话项 ID。
   *
   * API：Realtime conversation item。
   * 说明：服务端生成或客户端指定，用于删除、检索或截断。
   */
  id?: string;

  /**
   * 对话项类型。
   *
   * API：Realtime conversation item。
   * 说明：例如 `message`、`function_call`、`function_call_output`。
   */
  type: 'message' | 'function_call' | 'function_call_output';

  /**
   * 角色。
   *
   * API：Realtime conversation item。
   * 说明：message 类型常用 `user`、`assistant` 或 `system`。
   */
  role?: 'user' | 'assistant' | 'system';

  /**
   * 内容列表。
   *
   * API：Realtime conversation item。
   * 说明：消息内容块数组。
   */
  content?: Array<RealtimeConversationItemContent>;

  /**
   * 工具调用 ID。
   *
   * API：Realtime conversation item。
   * 说明：function call/output 用于关联工具调用。
   */
  call_id?: string;

  /**
   * 工具名称。
   *
   * API：Realtime conversation item。
   * 说明：function_call 使用。
   */
  name?: string;

  /**
   * 参数字符串。
   *
   * API：Realtime conversation item。
   * 说明：function_call 的 JSON 参数字符串。
   */
  arguments?: string;

  /**
   * 工具输出。
   *
   * API：Realtime conversation item。
   * 说明：function_call_output 的结果字符串。
   */
  output?: string;
}

/**
 * Realtime 响应配置。
 *
 * API：`response.create`。
 * 说明：客户端可临时覆盖 session 默认响应配置。
 */
export interface RealtimeResponseCreateOptions {
  /**
   * 输出模态。
   *
   * API：`response.create`。
   * 说明：例如 `['text']` 或 `['audio']`。
   */
  output_modalities?: Array<RealtimeOutputModality>;

  /**
   * 指令。
   *
   * API：`response.create`。
   * 说明：仅作用于本次 response 的附加指令。
   */
  instructions?: string;

  /**
   * 最大输出 token。
   *
   * API：`response.create`。
   * 说明：数字或 `inf`。
   */
  max_output_tokens?: RealtimeMaxOutputTokens;

  /**
   * 元数据。
   *
   * API：`response.create`。
   * 说明：业务侧附加信息。
   */
  metadata?: JsonObject | null;
}

/**
 * Realtime client secret 过期策略。
 *
 * API：Create Realtime client secret。
 * 说明：控制短期凭证有效期，不控制已建立 session 的生命周期。
 */
export interface RealtimeClientSecretExpiresAfter {
  /** 过期锚点。API：Create Realtime client secret。说明：当前支持 `created_at`。 */
  anchor: 'created_at';
  /** 秒数。API：Create Realtime client secret。说明：官方范围通常为 10 到 7200。 */
  seconds: number;
}

/**
 * Realtime client secret。
 *
 * API：Realtime client secrets、Realtime sessions。
 * 说明：给客户端连接 Realtime API 使用，避免泄露服务端 API key。
 */
export interface RealtimeClientSecretValue {
  /** 凭证值。API：Realtime client secrets。说明：形如 `ek_...`。 */
  value: string;
  /** 过期时间。API：Realtime client secrets。说明：Unix 秒级时间戳。 */
  expires_at: number;
}

/**
 * Realtime 音频转写配置。
 *
 * API：Realtime transcription session。
 * 说明：指定实时转写模型、提示词和语言。
 */
export interface RealtimeInputAudioTranscription {
  /** 模型。API：Realtime transcription session。说明：例如 `gpt-4o-transcribe`。 */
  model: OpenAIModel;
  /** 提示词。API：Realtime transcription session。说明：引导转写风格或术语。 */
  prompt?: string;
  /** 语言。API：Realtime transcription session。说明：ISO-639-1 语言码可改善延迟和准确率。 */
  language?: string;
}

/**
 * Realtime 噪声抑制配置。
 *
 * API：Realtime session。
 * 说明：控制输入音频的近场或远场降噪。
 */
export interface RealtimeNoiseReduction {
  /** 类型。API：Realtime session。说明：例如 `near_field`、`far_field`。 */
  type: string;
}

/**
 * Realtime turn detection 配置。
 *
 * API：Realtime session。
 * 说明：控制服务端何时认为用户开始或停止说话。
 */
export interface RealtimeTurnDetection {
  /** 类型。API：Realtime session。说明：`server_vad` 或 `semantic_vad`。 */
  type: RealtimeTurnDetectionType;
  /** 阈值。API：Realtime session。说明：VAD 灵敏度。 */
  threshold?: number;
  /** 前置 padding。API：Realtime session。说明：检测到语音前保留的毫秒数。 */
  prefix_padding_ms?: number;
  /** 静音时长。API：Realtime session。说明：检测停止说话的毫秒数。 */
  silence_duration_ms?: number;
  /** 空闲超时。API：Realtime session。说明：长时间无输入后的毫秒数。 */
  idle_timeout_ms?: number | null;
  /** 自动创建响应。API：Realtime session。说明：VAD 结束后是否自动触发模型响应。 */
  create_response?: boolean;
  /** 中断当前响应。API：Realtime session。说明：检测到用户说话时是否打断正在播放的响应。 */
  interrupt_response?: boolean;
}

/**
 * Realtime session 配置。
 *
 * API：Create Realtime client secret。
 * 说明：用于为 client secret 绑定默认 realtime 会话参数。
 */
export interface RealtimeSessionCreateParams {
  /** 类型。API：Create Realtime client secret。说明：固定为 `realtime`。 */
  type: 'realtime';
  /** 模型。API：Realtime session。说明：例如 `gpt-realtime`。 */
  model?: OpenAIModel;
  /** 指令。API：Realtime session。说明：默认 system/developer 指令。 */
  instructions?: string;
  /** 输出模态。API：Realtime session。说明：例如 `['audio']` 或 `['text']`。 */
  output_modalities?: Array<RealtimeOutputModality>;
  /** 最大输出 token。API：Realtime session。说明：数字或 `inf`。 */
  max_output_tokens?: RealtimeMaxOutputTokens;
  /** Include 字段。API：Realtime session。说明：请求额外输出字段。 */
  include?: Array<RealtimeInclude>;
  /** Prompt 配置。API：Realtime session。说明：引用 prompt 模板及变量。 */
  prompt?: JsonObject | null;
  /** Tracing 配置。API：Realtime session。说明：`auto` 或细粒度 trace 配置。 */
  tracing?: 'auto' | JsonObject | null;
}

/**
 * Realtime transcription session 创建参数。
 *
 * API：`POST /v1/realtime/transcription_sessions`。
 * 说明：创建浏览器/客户端可用的实时转写 session。
 */
export interface RealtimeTranscriptionSessionCreateParams {
  /** Include 字段。API：Create transcription session。说明：例如输入音频转写 logprobs。 */
  include?: Array<RealtimeInclude>;
  /** 输入音频格式。API：Create transcription session。说明：`pcm16`、`g711_ulaw` 或 `g711_alaw`。 */
  input_audio_format?: RealtimeInputAudioFormat;
  /** 输入音频转写配置。API：Create transcription session。说明：模型、语言和 prompt。 */
  input_audio_transcription?: RealtimeInputAudioTranscription;
  /** 噪声抑制。API：Create transcription session。说明：近场或远场降噪。 */
  input_audio_noise_reduction?: RealtimeNoiseReduction | null;
  /** Turn detection。API：Create transcription session。说明：控制语音分段。 */
  turn_detection?: RealtimeTurnDetection | null;
}

/** Realtime session 响应对象。API：Realtime client secrets。说明：代表服务端创建的 realtime session 配置。 */
export interface RealtimeSession {
  /** 对象类型。API：Realtime session。说明：固定为 `realtime.session`。 */
  object: 'realtime.session';
  /** 类型。API：Realtime session。说明：`realtime` 或 `transcription`。 */
  type: RealtimeSessionType;
  /** Session ID。API：Realtime session。说明：服务端 session ID。 */
  id: string;
  /** 模型。API：Realtime session。说明：session 使用的模型。 */
  model?: string;
  /** 过期时间。API：Realtime session。说明：Unix 秒级时间戳。 */
  expires_at?: number;
  /** 输出模态。API：Realtime session。说明：session 可输出的模态。 */
  output_modalities?: Array<RealtimeOutputModality>;
  /** Include 字段。API：Realtime session。说明：额外输出字段。 */
  include?: Array<RealtimeInclude> | null;
  /** 短期凭证。API：Realtime session。说明：部分 endpoint 会直接返回该字段。 */
  client_secret?: RealtimeClientSecretValue;
}

/**
 * Realtime transcription session 响应。
 *
 * API：Create transcription session。
 * 说明：包含客户端连接 Realtime transcription 所需的短期凭证。
 */
export interface RealtimeTranscriptionSession extends RealtimeSession {
  /** 类型。API：Realtime transcription session。说明：固定为 `transcription`。 */
  type: 'transcription';
  /** 短期凭证。API：Create transcription session。说明：客户端使用该值连接 Realtime。 */
  client_secret?: RealtimeClientSecretValue;
}

/**
 * 创建 Realtime client secret 参数。
 *
 * API：`POST /v1/realtime/client_secrets`。
 * 说明：为客户端生成短期凭证，可附带 realtime 或 transcription session 配置。
 */
export interface RealtimeClientSecretCreateParams {
  /** 过期策略。API：Create Realtime client secret。说明：控制短期凭证有效期。 */
  expires_after?: RealtimeClientSecretExpiresAfter;
  /** Session 配置。API：Create Realtime client secret。说明：选择 realtime 或 transcription 配置。 */
  session?: RealtimeSessionCreateParams | RealtimeTranscriptionSessionCreateParams;
}

/**
 * Realtime client secret 响应。
 *
 * API：Create Realtime client secret。
 * 说明：返回短期凭证和服务端应用后的 session 配置。
 */
export interface RealtimeClientSecret {
  /** 凭证值。API：Create Realtime client secret。说明：客户端连接时使用。 */
  value: string;
  /** 过期时间。API：Create Realtime client secret。说明：Unix 秒级时间戳。 */
  expires_at: number;
  /** Session。API：Create Realtime client secret。说明：该凭证绑定的 session 配置。 */
  session: RealtimeSession | RealtimeTranscriptionSession;
}

/**
 * Realtime session.update 事件。
 *
 * API：Realtime Client events。
 * 说明：更新当前 realtime 或 transcription session 配置。
 */
export interface RealtimeSessionUpdateEvent extends RealtimeEventBase<'session.update'> {
  /** Session 配置。API：session.update。说明：可传 realtime 或 transcription session 配置。 */
  session: RealtimeSessionCreateParams | RealtimeTranscriptionSessionCreateParams;
}

/**
 * Realtime transcription_session.update 事件。
 *
 * API：Realtime Client events。
 * 说明：更新 transcription session 配置。
 */
export interface RealtimeTranscriptionSessionUpdateEvent
  extends RealtimeEventBase<'transcription_session.update'> {
  /** Session 配置。API：transcription_session.update。说明：转写 session 新配置。 */
  session: RealtimeTranscriptionSessionCreateParams;
}

/**
 * Realtime conversation.item.create 事件。
 *
 * API：Realtime Client events。
 * 说明：向对话上下文追加 message、function_call 或 function_call_output。
 */
export interface RealtimeConversationItemCreateEvent extends RealtimeEventBase<'conversation.item.create'> {
  /** 对话项。API：conversation.item.create。说明：要追加的 item。 */
  item: RealtimeConversationItem;
  /** 前一个 item ID。API：conversation.item.create。说明：用于插入到指定位置之后。 */
  previous_item_id?: string | null;
}

/**
 * Realtime conversation.item.retrieve 事件。
 *
 * API：Realtime Client events。
 * 说明：按 ID 读取一个对话项。
 */
export interface RealtimeConversationItemRetrieveEvent extends RealtimeEventBase<'conversation.item.retrieve'> {
  /** 对话项 ID。API：conversation.item.retrieve。说明：要读取的 item ID。 */
  item_id: string;
}

/**
 * Realtime conversation.item.delete 事件。
 *
 * API：Realtime Client events。
 * 说明：按 ID 删除一个对话项。
 */
export interface RealtimeConversationItemDeleteEvent extends RealtimeEventBase<'conversation.item.delete'> {
  /** 对话项 ID。API：conversation.item.delete。说明：要删除的 item ID。 */
  item_id: string;
}

/**
 * Realtime input_audio_buffer.append 事件。
 *
 * API：Realtime Client events。
 * 说明：向服务端输入音频缓冲区追加一段 base64 音频。
 */
export interface RealtimeInputAudioBufferAppendEvent extends RealtimeEventBase<'input_audio_buffer.append'> {
  /** base64 音频。API：input_audio_buffer.append。说明：格式必须匹配 session 的 input audio format。 */
  audio: string;
}

/**
 * Realtime input_audio_buffer.commit 事件。
 *
 * API：Realtime Client events。
 * 说明：提交音频缓冲，创建一个用户音频消息。
 */
export interface RealtimeInputAudioBufferCommitEvent extends RealtimeEventBase<'input_audio_buffer.commit'> {
}

/**
 * Realtime input_audio_buffer.clear 事件。
 *
 * API：Realtime Client events。
 * 说明：清空当前音频缓冲区。
 */
export interface RealtimeInputAudioBufferClearEvent extends RealtimeEventBase<'input_audio_buffer.clear'> {
}

/**
 * Realtime response.create 事件。
 *
 * API：Realtime Client events。
 * 说明：让模型基于当前对话上下文生成一个 response。
 */
export interface RealtimeResponseCreateEvent extends RealtimeEventBase<'response.create'> {
  /** Response 配置。API：response.create。说明：可覆盖本次响应的输出模态、指令和 token 上限。 */
  response?: RealtimeResponseCreateOptions;
}

/**
 * Realtime response.cancel 事件。
 *
 * API：Realtime Client events。
 * 说明：取消正在生成的 response。
 */
export interface RealtimeResponseCancelEvent extends RealtimeEventBase<'response.cancel'> {
  /** Response ID。API：response.cancel。说明：不传时取消当前活动 response。 */
  response_id?: string;
}

/** 截断助手音频消息事件。API：Realtime。说明：中断场景必需。 */
export interface RealtimeConversationItemTruncateEvent {
  type: 'conversation.item.truncate';
  event_id?: string;
  item_id: string;
  content_index: number;
  audio_end_ms: number;
}

/** 清除输出音频缓冲事件。API：Realtime。说明：WebRTC 场景。 */
export interface RealtimeOutputAudioBufferClearEvent {
  type: 'output_audio_buffer.clear';
  event_id?: string;
}

/**
 * Realtime 客户端事件。
 *
 * API：Realtime Client events。
 * 说明：SDK model 层用于描述客户端发往 Realtime 连接的事件。
 */
export type RealtimeClientEvent =
  RealtimeSessionUpdateEvent |
  RealtimeTranscriptionSessionUpdateEvent |
  RealtimeConversationItemCreateEvent |
  RealtimeConversationItemRetrieveEvent |
  RealtimeConversationItemDeleteEvent |
  RealtimeConversationItemTruncateEvent |
  RealtimeInputAudioBufferAppendEvent |
  RealtimeInputAudioBufferCommitEvent |
  RealtimeInputAudioBufferClearEvent |
  RealtimeResponseCreateEvent |
  RealtimeResponseCancelEvent |
  RealtimeOutputAudioBufferClearEvent;

/**
 * Realtime 错误对象。
 *
 * API：Realtime Server events。
 * 说明：服务端错误事件中的错误详情。
 */
export interface RealtimeServerError {
  /** 错误类型。API：Realtime error。说明：机器可读错误类别。 */
  type?: string;
  /** 错误代码。API：Realtime error。说明：机器可读错误码。 */
  code?: string;
  /** 错误消息。API：Realtime error。说明：开发者可读错误描述。 */
  message: string;
  /** 错误参数。API：Realtime error。说明：触发错误的参数名或路径。 */
  param?: string | null;
  /** 关联事件 ID。API：Realtime error。说明：导致错误的客户端事件 ID。 */
  event_id?: string | null;
}

/**
 * Realtime 通用服务端事件。
 *
 * API：Realtime Server events。
 * 说明：对低风险或高频扩展事件使用该结构承载公共字段。
 */
export interface RealtimeServerEventBase<TEventType> extends RealtimeEventBase<TEventType> {
}

/** Realtime error 事件。API：Realtime Server events。说明：服务端处理事件失败时返回。 */
export interface RealtimeErrorEvent extends RealtimeServerEventBase<'error'> {
  /** 错误详情。API：error。说明：包含消息、代码和关联事件。 */
  error: RealtimeServerError;
}

/** Realtime session.created 事件。API：Realtime Server events。说明：连接建立后返回当前 session。 */
export interface RealtimeSessionCreatedEvent extends RealtimeServerEventBase<'session.created'> {
  /** Session。API：session.created。说明：服务端当前 session 配置。 */
  session: RealtimeSession | RealtimeTranscriptionSession;
}

/** Realtime session.updated 事件。API：Realtime Server events。说明：session.update 成功后返回。 */
export interface RealtimeSessionUpdatedEvent extends RealtimeServerEventBase<'session.updated'> {
  /** Session。API：session.updated。说明：更新后的 session 配置。 */
  session: RealtimeSession | RealtimeTranscriptionSession;
}

/** Realtime conversation.item.created 事件。API：Realtime Server events。说明：对话项创建完成。 */
export interface RealtimeConversationItemCreatedEvent
  extends RealtimeServerEventBase<'conversation.item.created'> {
  /** 对话项。API：conversation.item.created。说明：已创建的 item。 */
  item: RealtimeConversationItem;
  /** 前一个 item ID。API：conversation.item.created。说明：新 item 插入位置。 */
  previous_item_id?: string | null;
}

/** Realtime conversation.item.retrieved 事件。API：Realtime Server events。说明：返回检索到的对话项。 */
export interface RealtimeConversationItemRetrievedEvent
  extends RealtimeServerEventBase<'conversation.item.retrieved'> {
  /** 对话项。API：conversation.item.retrieved。说明：检索结果。 */
  item: RealtimeConversationItem;
}

/** Realtime conversation.item.deleted 事件。API：Realtime Server events。说明：对话项删除完成。 */
export interface RealtimeConversationItemDeletedEvent
  extends RealtimeServerEventBase<'conversation.item.deleted'> {
  /** 对话项 ID。API：conversation.item.deleted。说明：被删除的 item ID。 */
  item_id: string;
}

/** Realtime conversation.item.truncated 事件。API：Realtime Server events。说明：音频响应被截断。 */
export interface RealtimeConversationItemTruncatedEvent
  extends RealtimeServerEventBase<'conversation.item.truncated'> {
  /** 对话项 ID。API：conversation.item.truncated。说明：被截断的 item。 */
  item_id: string;
  /** 内容索引。API：conversation.item.truncated。说明：被截断的 content index。 */
  content_index: number;
  /** 音频结束毫秒。API：conversation.item.truncated。说明：截断后的音频结束位置。 */
  audio_end_ms: number;
}

/** Realtime 输入音频转写完成事件。API：Realtime Server events。说明：音频转写完成。 */
export interface RealtimeInputAudioTranscriptionCompletedEvent
  extends RealtimeServerEventBase<'conversation.item.input_audio_transcription.completed'> {
  /** 对话项 ID。API：input_audio_transcription.completed。说明：对应音频 item。 */
  item_id: string;
  /** 内容索引。API：input_audio_transcription.completed。说明：对应 content index。 */
  content_index: number;
  /** 转写文本。API：input_audio_transcription.completed。说明：最终转写结果。 */
  transcript: string;
  /** Logprobs。API：input_audio_transcription.completed。说明：按 include 配置返回。 */
  logprobs?: Array<JsonObject>;
}

/** Realtime 输入音频转写增量事件。API：Realtime Server events。说明：流式返回转写片段。 */
export interface RealtimeInputAudioTranscriptionDeltaEvent
  extends RealtimeServerEventBase<'conversation.item.input_audio_transcription.delta'> {
  item_id: string;
  content_index: number;
  delta: string;
  logprobs?: Array<JsonObject>;
}

/** Realtime 输入音频转写失败事件。API：Realtime Server events。说明：转写失败。 */
export interface RealtimeInputAudioTranscriptionFailedEvent
  extends RealtimeServerEventBase<'conversation.item.input_audio_transcription.failed'> {
  item_id: string;
  content_index: number;
  error: RealtimeServerError;
}

/** Realtime response 基础对象。API：Realtime Server events。说明：response.created/done 携带。 */
export interface RealtimeResponse {
  id: string;
  object?: 'realtime.response';
  status?: 'in_progress' | 'completed' | 'cancelled' | 'failed' | 'incomplete';
  output?: Array<RealtimeConversationItem>;
  metadata?: JsonObject | null;
}

/** Realtime response.created 事件。API：Realtime Server events。说明：response 开始生成。 */
export interface RealtimeResponseCreatedEvent extends RealtimeServerEventBase<'response.created'> {
  response: RealtimeResponse;
}

/** Realtime response.done 事件。API：Realtime Server events。说明：response 生成完成或停止。 */
export interface RealtimeResponseDoneEvent extends RealtimeServerEventBase<'response.done'> {
  response: RealtimeResponse;
}

/** Realtime response 输出 item 事件。API：Realtime Server events。说明：输出项添加或完成。 */
export interface RealtimeResponseOutputItemEvent
  extends RealtimeServerEventBase<'response.output_item.added' | 'response.output_item.done'> {
  response_id: string;
  output_index: number;
  item: RealtimeConversationItem;
}

/** Realtime response 内容片段事件。API：Realtime Server events。说明：内容块添加或完成。 */
export interface RealtimeResponseContentPartEvent
  extends RealtimeServerEventBase<'response.content_part.added' | 'response.content_part.done'> {
  response_id: string;
  item_id: string;
  output_index: number;
  content_index: number;
  part: RealtimeConversationItemContent;
}

/** Realtime response 增量事件。API：Realtime Server events。说明：音频、文本、转写或函数参数的增量。 */
export interface RealtimeResponseDeltaEvent
  extends RealtimeServerEventBase<'response.audio.delta' | 'response.audio_transcript.delta' |
    'response.text.delta' | 'response.function_call_arguments.delta'> {
  response_id: string;
  item_id: string;
  output_index: number;
  content_index?: number;
  delta: string;
}

/** Realtime response done 细分事件。API：Realtime Server events。说明：音频、文本、转写或函数参数完成。 */
export interface RealtimeResponseContentDoneEvent
  extends RealtimeServerEventBase<'response.audio.done' | 'response.audio_transcript.done' |
    'response.text.done' | 'response.function_call_arguments.done'> {
  response_id: string;
  item_id: string;
  output_index: number;
  content_index?: number;
  text?: string;
  transcript?: string;
  arguments?: string;
}

/** Realtime rate limit。API：rate_limits.updated。说明：服务端返回的限流状态。 */
export interface RealtimeRateLimit {
  name: string;
  limit: number;
  remaining: number;
  reset_seconds: number;
}

/** Realtime rate_limits.updated 事件。API：Realtime Server events。说明：限流信息更新。 */
export interface RealtimeRateLimitsUpdatedEvent extends RealtimeServerEventBase<'rate_limits.updated'> {
  rate_limits: Array<RealtimeRateLimit>;
}

/** 输出音频缓冲开始事件。API：Realtime。说明：服务端开始推送音频。 */
export interface RealtimeOutputAudioBufferStartedEvent {
  type: 'output_audio_buffer.started';
  event_id?: string;
  response_id: string;
}

/** 输出音频缓冲停止事件。API：Realtime。说明：音频缓冲已排空。 */
export interface RealtimeOutputAudioBufferStoppedEvent {
  type: 'output_audio_buffer.stopped';
  event_id?: string;
  response_id: string;
}

/** 输出音频缓冲清除事件。API：Realtime。说明：缓冲被清除。 */
export interface RealtimeOutputAudioBufferClearedEvent {
  type: 'output_audio_buffer.cleared';
  event_id?: string;
  response_id: string;
}

/**
 * Realtime 服务端事件。
 *
 * API：Realtime Server events。
 * 说明：SDK model 层用于描述 Realtime 连接上收到的服务端事件。
 */
export type RealtimeServerEvent =
  RealtimeErrorEvent |
  RealtimeSessionCreatedEvent |
  RealtimeSessionUpdatedEvent |
  RealtimeConversationItemCreatedEvent |
  RealtimeConversationItemRetrievedEvent |
  RealtimeConversationItemDeletedEvent |
  RealtimeConversationItemTruncatedEvent |
  RealtimeInputAudioTranscriptionCompletedEvent |
  RealtimeInputAudioTranscriptionDeltaEvent |
  RealtimeInputAudioTranscriptionFailedEvent |
  RealtimeResponseCreatedEvent |
  RealtimeResponseDoneEvent |
  RealtimeResponseOutputItemEvent |
  RealtimeResponseContentPartEvent |
  RealtimeResponseDeltaEvent |
  RealtimeResponseContentDoneEvent |
  RealtimeOutputAudioBufferStartedEvent |
  RealtimeOutputAudioBufferStoppedEvent |
  RealtimeOutputAudioBufferClearedEvent |
  RealtimeRateLimitsUpdatedEvent;
