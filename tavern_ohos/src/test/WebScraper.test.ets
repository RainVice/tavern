import { describe, it, expect } from '@ohos/hypium';
import { EventBus, WebScraperRuntime, type RuntimeEvent, type ScrapeCompletedPayload } from '../../Index';
export default function webScraperUnitTest() {
  describe('WebScraperRuntime', () => {
    it('创建请求并完成抓取', 0, () => {
      const rt = new WebScraperRuntime(new EventBus());
      // 标识。
      const id = rt.createRequest('https://example.com', true, false, 500);
      const result = rt.completeScrape(id, 'Example Domain', 'This domain is for use in examples', []);
      expect(result.success).assertTrue();
      expect(result.title).assertEqual('Example Domain');
      expect(result.url).assertEqual('https://example.com');
    });
    it('抓取失败', 0, () => {
      const rt = new WebScraperRuntime(new EventBus());
      // 标识。
      const id = rt.createRequest('https://invalid', true, false, 500);
      const result = rt.failScrape(id, 'DNS 解析失败');
      expect(result.success).assertFalse();
      expect(result.error).assertEqual('DNS 解析失败');
    });
    it('完成或失败后释放请求并发布统一结果事件', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      const rt = new WebScraperRuntime(bus);
      const events = new Array<string>();
      bus.subscribe<ScrapeCompletedPayload>('webscraper.completed', (event: RuntimeEvent<ScrapeCompletedPayload>) => {
        events.push(`${event.payload.result.success}:${event.payload.result.textContent}`);
      });
      // success 标识。
      const successId = rt.createRequest('https://example.com', true, false, -1);
      const success = rt.completeScrape(successId, 'Example', 'abcdef', []);
      // fail 标识。
      const failId = rt.createRequest('https://invalid', true, false, 100);
      const failed = rt.failScrape(failId, '失败');
      let reuseFailed = false;
      try {
        rt.completeScrape(successId, 'Again', 'again', []);
      } catch (error) {
        reuseFailed = true;
      }

      expect(success.textContent).assertEqual('');
      expect(failed.success).assertFalse();
      expect(events.length).assertEqual(2);
      expect(events[0]).assertEqual('true:');
      expect(events[1]).assertEqual('false:');
      expect(reuseFailed).assertTrue();
    });
  });
}
