/**
 * 创建网页抓取请求时需要传入的参数。
 */
export interface ScrapeRequest {
  /**
   * 要抓取的目标网页 URL。
   */
  url: string;
  /**
   * 是否提取网页纯文本内容。
   */
  extractText: boolean;
  /**
   * 是否提取网页中的图片 URL。
   */
  extractImages: boolean;
  /**
   * 返回文本内容的最大字符数限制。
   */
  maxChars: number;
}
/**
 * 网页抓取完成后返回的结果数据。
 */
export interface ScrapeResult {
  /**
   * 抓取请求的 URL。
   */
  url: string;
  /**
   * 网页标题。
   */
  title: string;
  /**
   * 抓取到的纯文本内容。
   */
  textContent: string;
  /**
   * 从网页中提取到的图片 URL 列表。
   */
  imageUrls: Array<string>;
  /**
   * 抓取是否成功。
   */
  success: boolean;
  /**
   * 抓取失败时的错误描述。
   */
  error: string;
}
/**
 * 网页抓取完成事件发布时携带的数据载荷。
 */
export interface ScrapeCompletedPayload {
  /**
   * 抓取结果。
   */
  result: ScrapeResult;
}
