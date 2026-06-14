import { EventBus } from '../runtime/EventBus';
import type { ScrapeCompletedPayload, ScrapeRequest, ScrapeResult } from './WebScraperModels';

/**
 * 提供网页抓取相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class WebScraperRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus; private requests: Map<string,ScrapeRequest>=new Map(); private counter=0;
  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) { this.events=events; }

  /**
   * 创建一个新的网页抓取请求，返回请求标识供后续完成或失败时使用。
   * @param url 要抓取的目标 URL。
   * @param extractText 是否提取纯文本。
   * @param extractImages 是否提取图片。
   * @param maxChars 文本最大字符数上限。
   * @returns 新创建的请求标识（如 "scrape-1"）。
   */
  createRequest(url: string, extractText: boolean, extractImages: boolean, maxChars: number): string {
    this.counter+=1; const requestId=`scrape-${this.counter}`;
    this.requests.set(requestId, { url, extractText, extractImages, maxChars: Math.max(0, maxChars) });
    return requestId;
  }

  /**
   * 标记网页抓取成功，根据原始请求限制文本长度后返回结果。
   * @param requestId 目标请求标识。
   * @param title 网页标题。
   * @param textContent 抓取的纯文本内容。
   * @param imageUrls 提取到的图片 URL 列表。
   * @returns 包含抓取结果的 ScrapeResult 对象。
   */
  completeScrape(requestId: string, title: string, textContent: string, imageUrls: Array<string>): ScrapeResult {
    const req = this.requests.get(requestId);
    if (req===undefined) throw new Error(`抓取请求未找到: ${requestId}`);
    const result: ScrapeResult = { url:req.url, title, textContent:textContent.substring(0,req.maxChars), imageUrls:imageUrls.slice(), success:true, error:'' };
    this.requests.delete(requestId);
    this.publishResult(result);
    return result;
  }

  /**
   * 标记网页抓取失败，返回带错误信息的 ScrapeResult。
   * @param requestId 目标请求标识。
   * @param error 错误描述。
   * @returns 包含错误信息的 ScrapeResult 对象。
   */
  failScrape(requestId: string, error: string): ScrapeResult {
    const req=this.requests.get(requestId);
    if (req===undefined) throw new Error(`抓取请求未找到: ${requestId}`);
    const result: ScrapeResult = { url:req.url, title:'', textContent:'', imageUrls:[], success:false, error };
    this.requests.delete(requestId);
    this.publishResult(result);
    return result;
  }

  /**
   * 发布网页抓取完成事件，把状态变化通知给宿主或其他 Runtime。
   * @param result 抓取结果。
   */
  private publishResult(result: ScrapeResult): void {
    this.events.publish<ScrapeCompletedPayload>('webscraper.completed', { result });
  }
}
