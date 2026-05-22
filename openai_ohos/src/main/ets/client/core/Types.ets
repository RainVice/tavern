import { http } from "@kit.NetworkKit";

/**
 * SDK 支持的基础 HTTP 方法。
 *
 * API：OpenAI REST API。
 * 说明：当前先用于 `GET /v1/models`，后续请求体 API 可复用同一请求层。
 */
export type OpenAIHttpMethod = http.RequestMethod;

/**
 * OpenAI 响应数据类型。
 *
 * API：所有 OpenAI REST API。
 * 说明：JSON API 使用 `string`，音频 speech 等二进制 API 使用 `arraybuffer` 并由 transport 转成 base64 字符串。
 */
export type OpenAIResponseDataType = 'string' | 'arraybuffer';

/** 取消回调。API：所有 OpenAI REST API。说明：请求取消时由 transport 释放底层网络资源。 */
export type OpenAICancelCallback = () => void;

/**
 * OpenAI 请求取消令牌。
 *
 * API：所有 OpenAI REST API、Realtime transport。
 * 说明：调用 `cancel()` 后，HTTP transport 会销毁 Harmony HttpRequest，Realtime 连接会关闭底层连接。
 */
export class OpenAICancelToken {
  private cancelled: boolean = false;
  private callbacks: Array<OpenAICancelCallback> = [];

  /** 是否已经取消。API：请求控制。说明：用于调用方或 transport 判断是否继续处理响应。 */
  isCancelled(): boolean {
    return this.cancelled;
  }

  /** 注册取消回调。API：请求控制。说明：如果已取消会立即触发该回调。 */
  onCancel(callback: OpenAICancelCallback): void {
    if (this.cancelled) {
      callback();
      return;
    }
    this.callbacks.push(callback);
  }

  /** 取消请求。API：请求控制。说明：幂等操作，多次调用只触发一次回调。 */
  cancel(): void {
    if (this.cancelled) {
      return;
    }
    this.cancelled = true;
    for (let index = 0; index < this.callbacks.length; index++) {
      this.callbacks[index]();
    }
    this.callbacks = [];
  }
}

/**
 * 单次请求覆盖选项。
 *
 * API：所有 OpenAI REST API。
 * 说明：可覆盖当前请求的超时、header 和取消令牌，不影响 client 默认配置。
 */
export interface OpenAIRequestSettings {
  /** 兼容快捷超时。API：所有 REST API。说明：同时覆盖 connectTimeout 和 readTimeout。 */
  timeout?: number;
  /** 读取超时。API：所有 REST API。说明：单位毫秒。 */
  readTimeout?: number;
  /** 连接超时。API：所有 REST API。说明：单位毫秒。 */
  connectTimeout?: number;
  /** 单次请求额外 header。API：所有 REST API。说明：会覆盖同名默认 header。 */
  headers?: Record<string, string>;
  /** 取消令牌。API：所有 REST API。说明：用于提前终止请求。 */
  cancelToken?: OpenAICancelToken;
}

/**
 * OpenAI stream 句柄。
 *
 * API：SSE streaming、Realtime transports。
 * 说明：调用 `close()` 主动关闭底层连接。
 */
export interface OpenAIStream {
  /** 关闭流。API：streaming。说明：释放底层 HTTP/WebSocket/WebRTC 资源。 */
  close(): void;
}

/** SSE chunk 回调。API：SSE streaming。说明：transport 收到文本分片时调用。 */
export type OpenAIStreamChunkHandler = (chunk: string) => void;

/** SSE 错误回调。API：SSE streaming。说明：底层网络错误时调用。 */
export type OpenAIStreamErrorHandler = (message: string) => void;

/** SSE 结束回调。API：SSE streaming。说明：数据流结束时调用。 */
export type OpenAIStreamDoneHandler = () => void;

/**
 * multipart 表单字段。
 *
 * API：Files、Audio transcriptions/translations、Images edits/variations 等上传类 API。
 * 说明：用于把 Harmony `MultiFormData` 与 SDK 请求层解耦。
 */
export interface OpenAIMultipartFormData {
  /**
   * 表单字段名。
   *
   * API：multipart OpenAI REST API。
   * 说明：例如 `file`、`purpose`、`model`。
   */
  name: string;

  /**
   * 内容类型。
   *
   * API：multipart OpenAI REST API。
   * 说明：文件一般使用 `application/octet-stream`，普通字段使用 `text/plain`。
   */
  contentType: string;

  /**
   * 远程文件名。
   *
   * API：multipart OpenAI REST API。
   * 说明：文件字段可设置，普通字段不需要。
   */
  remoteFileName?: string;

  /**
   * 字段字符串数据。
   *
   * API：multipart OpenAI REST API。
   * 说明：普通字段使用；如果设置了 `filePath`，该字段可省略。
   */
  data?: string;

  /**
   * 本地文件路径。
   *
   * API：multipart OpenAI REST API。
   * 说明：Harmony HTTP 会从该路径读取文件内容。
   */
  filePath?: string;
}

/**
 * OpenAI 客户端配置。
 *
 * API：所有 OpenAI REST API。
 * 说明：创建 `new OpenAI(...)` 时传入，和官方 SDK 的使用入口保持一致。
 */
export interface OpenAIClientOptions {
  /**
   * API Key。
   *
   * API：所有 OpenAI REST API。
   * 说明：会被放入 `Authorization: Bearer <apiKey>` 请求头。
   */
  apiKey: string;

  /**
   * API base URL。
   *
   * API：所有 OpenAI REST API。
   * 说明：默认 `https://api.openai.com/v1`；兼容代理、网关或私有转发地址。
   */
  baseURL?: string;

  /**
   * 组织 ID。
   *
   * API：所有 OpenAI REST API。
   * 说明：传入后会设置 `OpenAI-Organization` 请求头。
   */
  organization?: string;

  /**
   * 项目 ID。
   *
   * API：所有 OpenAI REST API。
   * 说明：传入后会设置 `OpenAI-Project` 请求头。
   */
  project?: string;

  /**
   * 请求超时。
   *
   * API：所有 OpenAI REST API。
   * 说明：单位毫秒，同时用于 Harmony HTTP 的连接超时和读取超时；默认 60000。
   */
  timeout?: number;

  /**
   * 读取超时。
   *
   * API：所有 OpenAI REST API。
   * 说明：单位毫秒；不传则使用 `timeout` 或默认 60000。
   */
  readTimeout?: number;

  /**
   * 连接超时。
   *
   * API：所有 OpenAI REST API。
   * 说明：单位毫秒；不传则使用 `timeout` 或默认 60000。
   */
  connectTimeout?: number;

  /**
   * 自动重试次数。
   *
   * API：所有 OpenAI REST API。
   * 说明：默认 2 次；会重试 408、409、429 和 5xx 这类临时错误，0 表示不自动重试。
   */
  maxRetries?: number;

  /**
   * Webhook 签名密钥。
   *
   * API：Webhook signature verification。
   * 说明：传入后可直接使用 `client.webhooks.unwrap(payload, headers)` 校验并解析事件；也可在调用时覆盖。
   */
  webhookSecret?: string;

  /**
   * 默认额外请求头。
   *
   * API：所有 OpenAI REST API。
   * 说明：会合并到每次请求；单次请求 headers 可覆盖同名字段。
   */
  defaultHeaders?: Record<string, string>;

  /**
   * 自定义 transport。
   *
   * API：所有 OpenAI REST API。
   * 说明：单元测试或后续自定义网络栈可注入；不传则使用 Harmony `@kit.NetworkKit` HTTP。
   */
  transport?: OpenAITransport;
}

/**
 * OpenAI HTTP 请求选项。
 *
 * API：所有 OpenAI REST API。
 * 说明：client 内部传给 transport 的归一化请求。
 */
export interface OpenAIRequestOptions {
  /**
   * 完整请求 URL。
   *
   * API：所有 OpenAI REST API。
   * 说明：由 `baseURL` 和 API path 拼接得到。
   */
  url: string;

  /**
   * HTTP 方法。
   *
   * API：所有 OpenAI REST API。
   * 说明：当前模型列表请求为 `GET`。
   */
  method: OpenAIHttpMethod;

  /**
   * 请求头。
   *
   * API：所有 OpenAI REST API。
   * 说明：包含鉴权头、JSON accept/content-type，以及可选组织/项目头。
   */
  headers: Record<string, string>;

  /**
   * 请求体。
   *
   * API：POST/PUT 类 API。
   * 说明：当前 `GET /v1/models` 不使用该字段，后续 JSON 请求会复用。
   */
  body?: string;

  /**
   * multipart 表单数据。
   *
   * API：上传类 OpenAI REST API。
   * 说明：与 `body` 二选一；存在时 transport 使用 Harmony multipart。
   */
  multipart?: Array<OpenAIMultipartFormData>;

  /**
   * 响应数据类型。
   *
   * API：所有 OpenAI REST API。
   * 说明：默认 `string`；二进制响应会转为 base64 字符串放入 `OpenAIResponse.body`。
   */
  responseDataType?: OpenAIResponseDataType;

  /**
   * 请求超时。
   *
   * API：所有 OpenAI REST API。
   * 说明：单位毫秒。
   */
  timeout: number;

  /**
   * 读取超时。
   *
   * API：所有 OpenAI REST API。
   * 说明：传给 Harmony HTTP 的 readTimeout。
   */
  readTimeout: number;

  /**
   * 连接超时。
   *
   * API：所有 OpenAI REST API。
   * 说明：传给 Harmony HTTP 的 connectTimeout。
   */
  connectTimeout: number;

  /**
   * 取消令牌。
   *
   * API：所有 OpenAI REST API。
   * 说明：transport 可监听该令牌来释放底层请求。
   */
  cancelToken?: OpenAICancelToken;
}

/**
 * OpenAI HTTP 响应。
 *
 * API：所有 OpenAI REST API。
 * 说明：transport 返回的最小响应对象。
 */
export interface OpenAIResponse {
  /**
   * HTTP 状态码。
   *
   * API：所有 OpenAI REST API。
   * 说明：2xx 表示成功，非 2xx 会被转换为 `OpenAIAPIError`。
   */
  statusCode: number;

  /**
   * 响应体字符串。
   *
   * API：所有 OpenAI REST API。
   * 说明：JSON API 会在 resource 层解析。
   */
  body: string;
}

/**
 * OpenAI HTTP transport。
 *
 * API：所有 OpenAI REST API。
 * 说明：抽象网络请求，便于测试和未来替换 Harmony HTTP 实现。
 */
export interface OpenAITransport {
  /**
   * 发起请求。
   *
   * API：所有 OpenAI REST API。
   * 说明：返回状态码和响应体字符串。
   */
  request(options: OpenAIRequestOptions): Promise<OpenAIResponse>;

  /**
   * 发起流式请求。
   *
   * API：Responses/Assistants SSE streaming。
   * 说明：收到每个文本分片时调用 `onChunk`，并返回可关闭的 stream 句柄。
   */
  stream(
    options: OpenAIRequestOptions,
    onChunk: OpenAIStreamChunkHandler,
    onError?: OpenAIStreamErrorHandler,
    onDone?: OpenAIStreamDoneHandler
  ): OpenAIStream;
}
