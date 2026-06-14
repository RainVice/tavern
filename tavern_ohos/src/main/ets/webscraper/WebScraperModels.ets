/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface ScrapeRequest {
  /**
   * 地址。
   */
  url: string;
  /**
   * extract Text 值，由当前实例内部维护。
   */
  extractText: boolean;
  /**
   * extract Images 列表。
   */
  extractImages: boolean;
  /**
   * max Chars 列表。
   */
  maxChars: number;
}
/**
 * 描述网页抓取操作完成后返回给调用方的结果。
 */
export interface ScrapeResult {
  /**
   * 地址。
   */
  url: string;
  /**
   * 标题，由当前实例内部维护。
   */
  title: string;
  /**
   * text Content 值，由当前实例内部维护。
   */
  textContent: string;
  /**
   * image Urls 列表。
   */
  imageUrls: Array<string>;
  /**
   * 成功状态。
   */
  success: boolean;
  /**
   * 错误信息，由当前实例内部维护。
   */
  error: string;
}
/**
 * 描述网页抓取事件发布时携带的数据结构。
 */
export interface ScrapeCompletedPayload {
  /**
   * 处理结果。
   */
  result: ScrapeResult;
}
