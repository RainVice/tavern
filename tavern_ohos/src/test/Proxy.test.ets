import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  ProxyRuntime,
  type ProxyResolutionRecord,
  type ProxySettings,
} from '../../Index';

export default function proxyUnitTest() {
  describe('proxy runtime', () => {
    it('returns direct mode when proxy is disabled', 0, () => {
      // 运行时实例。
      const runtime = new ProxyRuntime(new EventBus());
      runtime.configure(makeSettings(false, 'http://127.0.0.1:7890'));
      const resolution: ProxyResolutionRecord = runtime.resolve('https://openai.com/v1');

      expect(resolution.mode).assertEqual('direct');
      expect(resolution.reason).assertEqual('disabled');
      expect(resolution.proxyUrl).assertEqual('');
    });

    it('returns proxy mode for non-bypassed targets when proxy url is valid', 0, () => {
      // 运行时实例。
      const runtime = new ProxyRuntime(new EventBus());
      runtime.configure(makeSettings(true, 'http://127.0.0.1:7890'));
      const resolution: ProxyResolutionRecord = runtime.resolve('https://openai.com/v1/chat/completions');

      expect(resolution.mode).assertEqual('proxy');
      expect(resolution.reason).assertEqual('proxy-enabled');
      expect(resolution.proxyUrl).assertEqual('http://127.0.0.1:7890');
      expect(resolution.keepAlive).assertTrue();
    });

    it('bypasses matching hosts and reports proxy/filter conflict warnings', 0, () => {
      // 运行时实例。
      const runtime = new ProxyRuntime(new EventBus());
      const settings = makeSettings(true, 'http://127.0.0.1:7890');
      settings.bypass = ['api.internal.test', '.lan'];
      settings.privateRequestFilterEnabled = true;
      runtime.configure(settings);
      const bypassed: ProxyResolutionRecord = runtime.resolve('https://api.internal.test/v1');
      const warned: ProxyResolutionRecord = runtime.resolve('https://openai.com/v1');

      expect(bypassed.mode).assertEqual('direct');
      expect(bypassed.reason).assertEqual('bypass');
      expect(bypassed.bypassed).assertTrue();
      expect(warned.mode).assertEqual('proxy');
      expect(warned.warning).assertEqual('private-request-filter-bypassed');
    });

    it('falls back to direct mode when proxy url is missing or invalid', 0, () => {
      // 运行时实例。
      const runtime = new ProxyRuntime(new EventBus());
      runtime.configure(makeSettings(true, 'not-a-url'));
      const resolution: ProxyResolutionRecord = runtime.resolve('https://openai.com/v1');

      expect(resolution.mode).assertEqual('direct');
      expect(resolution.reason).assertEqual('invalid-proxy-url');
      expect(resolution.proxyUrl).assertEqual('');
    });
  });
}

/**
 * 封装单元测试中的 makeSettings 步骤，供公开方法复用。
 * @param enabled 是否启用该能力。

 * @returns 条件命中时返回 true，否则返回 false。
 */
function makeSettings(enabled: boolean, url: string): ProxySettings {
  return {
    enabled: enabled,
    url: url,
    bypass: new Array<string>(),
    enableKeepAlive: true,
    privateRequestFilterEnabled: false,
  };
}
