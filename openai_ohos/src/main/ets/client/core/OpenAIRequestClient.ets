import { HarmonyHttpTransport } from './HarmonyHttpTransport';
import { OpenAIAPIError } from './OpenAIAPIError';
import { OpenAISSEParser, type OpenAISSEEvent } from './OpenAISSEParser';
import type {
  OpenAIClientOptions,
  OpenAIMultipartFormData,
  OpenAIRequestOptions,
  OpenAIRequestSettings,
  OpenAIResponse,
  OpenAIStream,
  OpenAITransport,
} from './Types';
import { http } from '@kit.NetworkKit';

/**
 * OpenAI 底层请求客户端。
 *
 * API：所有 OpenAI REST API。
 * 说明：负责 baseURL 拼接、通用请求头、超时和非 2xx 错误转换；具体资源只调用 `get/post/delete`。
 */
export class OpenAIRequestClient {
  private apiKey: string = '';
  private baseURL: string = '';
  private organization: string | null = null;
  private project: string | null = null;
  private timeout: number = 60000;
  private readTimeout: number = 60000;
  private connectTimeout: number = 60000;
  private maxRetries: number = 2;
  private defaultHeaders: Record<string, string> = {};
  private transport: OpenAITransport = new HarmonyHttpTransport();

  constructor(options: OpenAIClientOptions) {
    this.apiKey = options.apiKey;
    this.baseURL = this.normalizeBaseURL(options.baseURL);
    this.organization = options.organization === undefined ? null : options.organization;
    this.project = options.project === undefined ? null : options.project;
    this.timeout = options.timeout === undefined ? 60000 : options.timeout;
    this.readTimeout = options.readTimeout === undefined ? this.timeout : options.readTimeout;
    this.connectTimeout = options.connectTimeout === undefined ? this.timeout : options.connectTimeout;
    this.maxRetries = this.normalizeMaxRetries(options.maxRetries);
    this.defaultHeaders = options.defaultHeaders === undefined ? {} : options.defaultHeaders;
    this.transport = options.transport === undefined ? new HarmonyHttpTransport() : options.transport;
  }

  /**
   * 发送 GET 请求并返回响应体。
   *
   * API：GET 类 OpenAI REST API。
   * 说明：当前由 `models.list()` 使用，后续 list/retrieve API 可复用。
   */
  async get(path: string, extraHeaders?: Record<string, string>, requestOptions?: OpenAIRequestSettings): Promise<string> {
    return this.executeRequest({
      url: this.buildURL(path),
      method: http.RequestMethod.GET,
      headers: this.buildHeaders(true, extraHeaders, requestOptions),
      timeout: this.resolveTimeout(requestOptions),
      readTimeout: this.resolveReadTimeout(requestOptions),
      connectTimeout: this.resolveConnectTimeout(requestOptions),
      cancelToken: requestOptions === undefined ? undefined : requestOptions.cancelToken,
    });
  }

  /**
   * 发送 GET 请求并把二进制响应转换成 base64 字符串。
   *
   * API：`GET /v1/videos/{video_id}/content` 等二进制下载 API。
   * 说明：Harmony HTTP 返回 ArrayBuffer 后由 transport 转为 base64 字符串。
   */
  async getBinary(path: string, extraHeaders?: Record<string, string>, requestOptions?: OpenAIRequestSettings): Promise<string> {
    return this.executeRequest({
      url: this.buildURL(path),
      method: http.RequestMethod.GET,
      headers: this.buildHeaders(false, extraHeaders, requestOptions),
      responseDataType: 'arraybuffer',
      timeout: this.resolveTimeout(requestOptions),
      readTimeout: this.resolveReadTimeout(requestOptions),
      connectTimeout: this.resolveConnectTimeout(requestOptions),
      cancelToken: requestOptions === undefined ? undefined : requestOptions.cancelToken,
    });
  }

  /**
   * 发送 POST JSON 请求并返回响应体。
   *
   * API：POST 类 OpenAI REST API。
   * 说明：Responses、Chat Completions、Embeddings、Moderations、Batches 等 JSON endpoint 共用。
   */
  async post(path: string, body: Object, extraHeaders?: Record<string, string>, requestOptions?: OpenAIRequestSettings): Promise<string> {
    return this.executeRequest({
      url: this.buildURL(path),
      method: http.RequestMethod.POST,
      headers: this.buildHeaders(true, extraHeaders, requestOptions),
      body: JSON.stringify(body),
      timeout: this.resolveTimeout(requestOptions),
      readTimeout: this.resolveReadTimeout(requestOptions),
      connectTimeout: this.resolveConnectTimeout(requestOptions),
      cancelToken: requestOptions === undefined ? undefined : requestOptions.cancelToken,
    });
  }

  /**
   * 发送 POST JSON 请求并把二进制响应转换成 base64 字符串。
   *
   * API：`POST /v1/audio/speech` 等二进制响应 API。
   * 说明：Harmony HTTP 返回 ArrayBuffer 后由 transport 转为 base64 字符串。
   */
  async postBinary(path: string, body: Object, extraHeaders?: Record<string, string>, requestOptions?: OpenAIRequestSettings): Promise<string> {
    return this.executeRequest({
      url: this.buildURL(path),
      method: http.RequestMethod.POST,
      headers: this.buildHeaders(true, extraHeaders, requestOptions),
      body: JSON.stringify(body),
      responseDataType: 'arraybuffer',
      timeout: this.resolveTimeout(requestOptions),
      readTimeout: this.resolveReadTimeout(requestOptions),
      connectTimeout: this.resolveConnectTimeout(requestOptions),
      cancelToken: requestOptions === undefined ? undefined : requestOptions.cancelToken,
    });
  }

  /**
   * 发送原始文本 POST 请求。
   *
   * API：Realtime WebRTC `/v1/realtime/calls`。
   * 说明：用于 `application/sdp` 等非 JSON 请求体。
   */
  async postText(path: string, body: string, contentType: string, extraHeaders?: Record<string, string>, requestOptions?: OpenAIRequestSettings): Promise<string> {
    let headers: Record<string, string> = {};
    if (extraHeaders !== undefined) {
      headers = { ...extraHeaders };
    }
    headers['Content-Type'] = contentType;
    return this.executeRequest({
      url: this.buildURL(path),
      method: http.RequestMethod.POST,
      headers: this.buildHeaders(true, headers, requestOptions),
      body: body,
      timeout: this.resolveTimeout(requestOptions),
      readTimeout: this.resolveReadTimeout(requestOptions),
      connectTimeout: this.resolveConnectTimeout(requestOptions),
      cancelToken: requestOptions === undefined ? undefined : requestOptions.cancelToken,
    });
  }

  /**
   * 发送 multipart POST 请求并返回响应体。
   *
   * API：Files、Audio transcriptions/translations、Images variations 等上传类 API。
   * 说明：不设置 JSON Content-Type，由 Harmony HTTP 生成 multipart boundary。
   */
  async postMultipart(path: string, parts: Array<OpenAIMultipartFormData>, extraHeaders?: Record<string, string>, requestOptions?: OpenAIRequestSettings): Promise<string> {
    return this.executeRequest({
      url: this.buildURL(path),
      method: http.RequestMethod.POST,
      headers: this.buildHeaders(false, extraHeaders, requestOptions),
      multipart: parts,
      timeout: this.resolveTimeout(requestOptions),
      readTimeout: this.resolveReadTimeout(requestOptions),
      connectTimeout: this.resolveConnectTimeout(requestOptions),
      cancelToken: requestOptions === undefined ? undefined : requestOptions.cancelToken,
    });
  }

  /**
   * 发送 DELETE 请求并返回响应体。
   *
   * API：DELETE 类 OpenAI REST API。
   * 说明：后续删除 response、file、model 等资源时复用。
   */
  async delete(path: string, extraHeaders?: Record<string, string>, requestOptions?: OpenAIRequestSettings): Promise<string> {
    return this.executeRequest({
      url: this.buildURL(path),
      method: http.RequestMethod.DELETE,
      headers: this.buildHeaders(true, extraHeaders, requestOptions),
      timeout: this.resolveTimeout(requestOptions),
      readTimeout: this.resolveReadTimeout(requestOptions),
      connectTimeout: this.resolveConnectTimeout(requestOptions),
      cancelToken: requestOptions === undefined ? undefined : requestOptions.cancelToken,
    });
  }

  /**
   * 发送 POST SSE 流式请求。
   *
   * API：Assistants streaming、Responses streaming。
   * 说明：底层按 chunk 解析 SSE，并把完整事件交给调用方。
   */
  streamPost(
    path: string,
    body: Object,
    extraHeaders: Record<string, string>,
    onEvent: (event: OpenAISSEEvent) => void,
    onError?: (message: string) => void,
    onDone?: () => void,
    requestOptions?: OpenAIRequestSettings
  ): OpenAIStream {
    const parser = new OpenAISSEParser();
    const headers = this.buildHeaders(true, this.buildStreamHeaders(extraHeaders), requestOptions);
    const stream = this.transport.stream({
      url: this.buildURL(path),
      method: http.RequestMethod.POST,
      headers: headers,
      body: JSON.stringify(body),
      timeout: this.resolveTimeout(requestOptions),
      readTimeout: this.resolveReadTimeout(requestOptions),
      connectTimeout: this.resolveConnectTimeout(requestOptions),
      cancelToken: requestOptions === undefined ? undefined : requestOptions.cancelToken,
    }, (chunk: string) => {
      const events = parser.push(chunk);
      for (let index = 0; index < events.length; index++) {
        onEvent(events[index]);
      }
    }, onError, () => {
      const events = parser.flush();
      for (let index = 0; index < events.length; index++) {
        onEvent(events[index]);
      }
      if (onDone !== undefined) {
        onDone();
      }
    });
    return stream;
  }

  private normalizeBaseURL(baseURL?: string): string {
    const value = baseURL === undefined || baseURL.length === 0 ? 'https://api.openai.com/v1' : baseURL;
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  private buildURL(path: string): string {
    if (path.startsWith('/')) {
      return this.baseURL + path;
    }
    return this.baseURL + '/' + path;
  }

  getBaseURL(): string {
    return this.baseURL;
  }

  getAPIKey(): string {
    return this.apiKey;
  }

  buildPublicHeaders(includeContentType: boolean = true, extraHeaders?: Record<string, string>, requestOptions?: OpenAIRequestSettings): Record<string, string> {
    return this.buildHeaders(includeContentType, extraHeaders, requestOptions);
  }

  private buildHeaders(includeContentType: boolean = true, extraHeaders?: Record<string, string>, requestOptions?: OpenAIRequestSettings): Record<string, string> {
    const headers: Record<string, string> = {
      'Authorization': 'Bearer ' + this.apiKey,
      'Accept': 'application/json',
    };
    const defaultKeys = Object.keys(this.defaultHeaders);
    for (let index = 0; index < defaultKeys.length; index++) {
      headers[defaultKeys[index]] = this.defaultHeaders[defaultKeys[index]];
    }
    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }
    if (this.organization !== null && this.organization.length > 0) {
      headers['OpenAI-Organization'] = this.organization;
    }
    if (this.project !== null && this.project.length > 0) {
      headers['OpenAI-Project'] = this.project;
    }
    if (extraHeaders !== undefined) {
      const keys = Object.keys(extraHeaders);
      for (let index = 0; index < keys.length; index++) {
        headers[keys[index]] = extraHeaders[keys[index]];
      }
    }
    if (requestOptions !== undefined && requestOptions.headers !== undefined) {
      const requestKeys = Object.keys(requestOptions.headers);
      for (let index = 0; index < requestKeys.length; index++) {
        headers[requestKeys[index]] = requestOptions.headers[requestKeys[index]];
      }
    }
    return headers;
  }

  private buildStreamHeaders(extraHeaders: Record<string, string>): Record<string, string> {
    const headers: Record<string, string> = {};
    const keys = Object.keys(extraHeaders);
    for (let index = 0; index < keys.length; index++) {
      headers[keys[index]] = extraHeaders[keys[index]];
    }
    headers['Accept'] = 'text/event-stream';
    return headers;
  }

  private resolveTimeout(requestOptions?: OpenAIRequestSettings): number {
    if (requestOptions !== undefined && requestOptions.timeout !== undefined) {
      return requestOptions.timeout;
    }
    return this.timeout;
  }

  private resolveReadTimeout(requestOptions?: OpenAIRequestSettings): number {
    if (requestOptions !== undefined && requestOptions.readTimeout !== undefined) {
      return requestOptions.readTimeout;
    }
    if (requestOptions !== undefined && requestOptions.timeout !== undefined) {
      return requestOptions.timeout;
    }
    return this.readTimeout;
  }

  private resolveConnectTimeout(requestOptions?: OpenAIRequestSettings): number {
    if (requestOptions !== undefined && requestOptions.connectTimeout !== undefined) {
      return requestOptions.connectTimeout;
    }
    if (requestOptions !== undefined && requestOptions.timeout !== undefined) {
      return requestOptions.timeout;
    }
    return this.connectTimeout;
  }

  private normalizeMaxRetries(maxRetries?: number): number {
    if (maxRetries === undefined) {
      return 2;
    }
    if (maxRetries < 0) {
      return 0;
    }
    return Math.floor(maxRetries);
  }

  private async executeRequest(options: OpenAIRequestOptions): Promise<string> {
    let attempt = 0;
    while (true) {
      try {
        const response: OpenAIResponse = await this.transport.request(options);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response.body;
        }
        if (attempt >= this.maxRetries || !this.isRetryableStatus(response.statusCode)) {
          throw new OpenAIAPIError(response.statusCode, response.body);
        }
      } catch (error) {
        if (error instanceof OpenAIAPIError) {
          throw error;
        }
        if (attempt >= this.maxRetries) {
          throw error;
        }
      }
      attempt += 1;
    }
  }

  private isRetryableStatus(statusCode: number): boolean {
    return statusCode === 408 || statusCode === 429 || statusCode >= 500;
  }
}
