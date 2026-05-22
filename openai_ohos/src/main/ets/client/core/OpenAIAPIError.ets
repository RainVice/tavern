/**
 * OpenAI API 错误。
 *
 * API：所有 OpenAI REST API。
 * 说明：当 HTTP 状态码不是 2xx 时抛出。
 */
export class OpenAIAPIError extends Error {
  /**
   * HTTP 状态码。
   *
   * API：所有 OpenAI REST API。
   * 说明：例如 401、429、500。
   */
  statusCode: number = 0;

  /**
   * 原始响应体。
   *
   * API：所有 OpenAI REST API。
   * 说明：保留服务端错误 JSON，方便业务层记录或排查。
   */
  responseBody: string = '';

  constructor(statusCode: number, responseBody: string) {
    super('OpenAI API request failed with status ' + statusCode.toString());
    this.statusCode = statusCode;
    this.responseBody = responseBody;
  }
}

/**
 * OpenAI 网络错误。
 *
 * API：所有 OpenAI REST API。
 * 说明：当 Harmony HTTP 在收到服务端响应前失败时抛出，例如无网络、DNS 失败、超时或权限问题。
 */
export class OpenAINetworkError extends Error {
  /**
   * 底层错误消息。
   *
   * API：所有 OpenAI REST API。
   * 说明：保留 Harmony HTTP 抛出的错误文本，方便定位网络和权限问题。
   */
  causeMessage: string = '';

  constructor(causeMessage: string) {
    super('OpenAI network request failed: ' + causeMessage);
    this.causeMessage = causeMessage;
  }
}
