import { EventBus } from '../runtime/EventBus';
import type { ScrapeCompletedPayload, ScrapeRequest, ScrapeResult } from './WebScraperModels';

/**
 * 提供网页抓取相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class WebScraperRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  private requests: Map<string, ScrapeRequest> = new Map();
  private counter = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建新的抓取请求，返回请求 ID 供后续查询使用。在用户发起网页内容抓取操作时调用。
   * @param url 目标网页 URL，指定要抓取的目标地址。
   * @param extractText 是否提取纯文本内容，控制抓取结果中是否包含文本。
   * @param extractImages 是否提取页面中的图片，控制抓取结果中是否包含图片列表。
   * @param maxChars 提取文本的最大字符数，用于限制返回文本长度。
   * @returns 新创建的请求 ID，供后续 completeScrape 或 failScrape 回调使用。
   */
  createRequest(url: string, extractText: boolean, extractImages: boolean, maxChars: number): string {
    this.counter += 1;
    const requestId = `scrape-${this.counter}`;
    this.requests.set(requestId, { url, extractText, extractImages, maxChars: Math.max(0, maxChars) });
    return requestId;
  }

  /**
   * 标记抓取成功，并发布完成事件。在宿主网络层完成网页请求并返回数据后回调。
   * @param requestId 请求标识，用于查找对应的 ScrapeRequest。
   * @param title 网页标题，从 HTML 头部提取的 <title> 内容。
   * @param textContent 提取的文本内容（会被截断至 maxChars），用于消息上下文或信息提取。
   * @param imageUrls 提取的图片 URL 列表，用于后续展示或处理。
   * @returns 完成的抓取结果，包含 URL、内容、标题和状态。
   */
  completeScrape(requestId: string, title: string, textContent: string, imageUrls: Array<string>): ScrapeResult {
    const req = this.requests.get(requestId);
    if (req === undefined) {
      throw new Error(`抓取请求未找到: ${requestId}`);
    }
    const result: ScrapeResult = {
      url: req.url,
      title,
      textContent: textContent.substring(0, req.maxChars),
      imageUrls: imageUrls.slice(),
      success: true,
      error: '',
    };
    this.requests.delete(requestId);
    this.publishResult(result);
    return result;
  }

  /**
   * 标记抓取失败，并保存错误信息。在宿主网络层请求失败后回调。
   * @param requestId 请求标识，用于查找对应的 ScrapeRequest。
   * @param error 错误描述，记录抓取失败的具体原因供后续排查。
   * @returns 失败的抓取结果，包含 URL、错误信息和 false 状态。
   */
  failScrape(requestId: string, error: string): ScrapeResult {
    const req = this.requests.get(requestId);
    if (req === undefined) {
      throw new Error(`抓取请求未找到: ${requestId}`);
    }
    const result: ScrapeResult = {
      url: req.url,
      title: '',
      textContent: '',
      imageUrls: [],
      success: false,
      error,
    };
    this.requests.delete(requestId);
    this.publishResult(result);
    return result;
  }

  /**
   * 发布网页抓取完成事件，通知宿主或其他 Runtime 处理结果。
   * @param result 抓取结果，包含完整的抓取数据，通过事件总线传递给订阅方。
   */
  private publishResult(result: ScrapeResult): void {
    this.events.publish<ScrapeCompletedPayload>('webscraper.completed', { result });
  }
}
