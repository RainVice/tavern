import { EventBus } from '../runtime/EventBus';
import type { ScrapeCompletedPayload, ScrapeRequest, ScrapeResult } from './WebScraperModels';

export class WebScraperRuntime {
  private events: EventBus; private requests: Map<string,ScrapeRequest>=new Map(); private counter=0;
  constructor(events: EventBus) { this.events=events; }

  createRequest(url: string, extractText: boolean, extractImages: boolean, maxChars: number): string {
    this.counter+=1; const requestId=`scrape-${this.counter}`;
    this.requests.set(requestId, { url, extractText, extractImages, maxChars: Math.max(0, maxChars) });
    return requestId;
  }

  completeScrape(requestId: string, title: string, textContent: string, imageUrls: Array<string>): ScrapeResult {
    const req = this.requests.get(requestId);
    if (req===undefined) throw new Error(`抓取请求未找到: ${requestId}`);
    const result: ScrapeResult = { url:req.url, title, textContent:textContent.substring(0,req.maxChars), imageUrls:imageUrls.slice(), success:true, error:'' };
    this.requests.delete(requestId);
    this.publishResult(result);
    return result;
  }

  failScrape(requestId: string, error: string): ScrapeResult {
    const req=this.requests.get(requestId);
    if (req===undefined) throw new Error(`抓取请求未找到: ${requestId}`);
    const result: ScrapeResult = { url:req.url, title:'', textContent:'', imageUrls:[], success:false, error };
    this.requests.delete(requestId);
    this.publishResult(result);
    return result;
  }

  private publishResult(result: ScrapeResult): void {
    this.events.publish<ScrapeCompletedPayload>('webscraper.completed', { result });
  }
}
