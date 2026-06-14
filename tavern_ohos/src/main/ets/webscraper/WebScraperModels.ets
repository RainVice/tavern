/**
 * 描述发送给外部服务或宿主网络层的请求数据。
 */
export interface ScrapeRequest {
  /**
   * 要抓取的网页 URL，用于发送 HTTP 请求获取网页内容。
   */
  url: string;
  /**
   * 是否提取纯文本内容，决定返回结果中是否包含 textContent 字段。
   */
  extractText: boolean;
  /**
   * 是否提取页面中的图片 URL 列表，决定返回结果中是否包含 imageUrls 字段。
   */
  extractImages: boolean;
  /**
   * 提取文本的最大字符数限制，用于控制返回文本的长度和内存占用。
   */
  maxChars: number;
}
/**
 * 描述网页抓取操作完成后返回给调用方的结果，包含抓取的内容和状态。
 */
export interface ScrapeResult {
  /**
   * 抓取的目标 URL，用于标识请求来源和结果归属。
   */
  url: string;
  /**
   * 网页标题，从 HTML <title> 标签中提取，用于展示页面摘要。
   */
  title: string;
  /**
   * 提取的纯文本内容，去除 HTML 标签后的页面正文，用于后续处理或模型输入。
   */
  textContent: string;
  /**
   * 从页面中提取的图片 URL 列表，用于后续处理或展示。
   */
  imageUrls: Array<string>;
  /**
   * 抓取是否成功，用于调用方判断是否需要使用备用方案。
   */
  success: boolean;
  /**
   * 失败时的错误描述，用于调用方记录错误原因和排查问题。
   */
  error: string;
}
/**
 * 描述网页抓取完成事件发布时携带的数据结构，供事件订阅方获取抓取结果。
 */
export interface ScrapeCompletedPayload {
  /**
   * 处理结果，包含 URL、标题、内容和错误信息等完整抓取数据。
   */
  result: ScrapeResult;
}
