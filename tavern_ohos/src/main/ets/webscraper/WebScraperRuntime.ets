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
   * 创建新的请求记录，写入存储并返回副本。




   * @returns 条件命中时返回 true，否则返回 false。
   */
  createRequest(url: string, extractText: boolean, extractImages: boolean, maxChars: number): string {
    this.counter+=1; const requestId=`scrape-${this.counter}`;
    this.requests.set(requestId, { url, extractText, extractImages, maxChars: Math.max(0, maxChars) });
    return requestId;
  }

  /**
   * 标记Scrape 值完成，并写入最终结果。
   * @param requestId 目标请求标识。
   * @param title 标题。


   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 标记Scrape 值失败，并保存错误信息。
   * @param requestId 目标请求标识。
   * @param error 错误信息。
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
   * 发布网页抓取事件，把状态变化通知给宿主或其他 Runtime。
   * @param result 返回结果。
   */
  private publishResult(result: ScrapeResult): void {
    this.events.publish<ScrapeCompletedPayload>('webscraper.completed', { result });
  }
}
