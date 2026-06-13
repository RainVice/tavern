import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  EventRuntime,
  type EventCatalogEntry,
  type EventCatalogPayload,
  type RuntimeEvent,
  type RuntimeSignalPayload,
  type ServerStartedPayload,
} from '../../Index';

/**
 * 描述单元测试事件发布时携带的数据结构。
 */
interface MutableEventPayload {
  /**
   * 标题，由当前实例内部维护。
   */
  title: string;
  /**
   * 项目列表。
   */
  items: Array<string>;
  /**
   * nested 值，由当前实例内部维护。
   */
  nested: MutableNestedPayload;
}

/**
 * 描述单元测试事件发布时携带的数据结构。
 */
interface MutableNestedPayload {
  /**
   * 字段值。
   */
  value: string;
}

export default function eventUnitTest() {
  describe('event runtime', () => {
    it('publishes server-started with the upstream event name', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new EventRuntime(bus);
      const received = new Array<string>();
      bus.subscribe<ServerStartedPayload>('server-started', (event: RuntimeEvent<ServerStartedPayload>) => {
        received.push(event.payload.source);
      });
      const published = runtime.emitServerStarted('entry');

      expect(published.name).assertEqual('server-started');
      expect(received.length).assertEqual(1);
      expect(received[0]).assertEqual('entry');
    });

    it('publishes lifecycle signals through runtime.signal', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new EventRuntime(bus);
      const received = new Array<string>();
      bus.subscribe<RuntimeSignalPayload>('runtime.signal', (event: RuntimeEvent<RuntimeSignalPayload>) => {
        received.push(`${event.payload.signal}:${event.payload.detail}`);
      });
      const ready = runtime.emitRuntimeSignal('runtime.ready', 'bootstrap finished');
      const background = runtime.emitRuntimeSignal('app.background', 'home pressed');

      expect(ready.payload.signal).assertEqual('runtime.ready');
      expect(background.payload.signal).assertEqual('app.background');
      expect(received[0]).assertEqual('runtime.ready:bootstrap finished');
      expect(received[1]).assertEqual('app.background:home pressed');
    });

    it('exposes a headless event catalog and maps upstream event names', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new EventRuntime(bus);
      const catalogEvents = new Array<string>();
      bus.subscribe<EventCatalogPayload>('event.catalog.published', (event: RuntimeEvent<EventCatalogPayload>) => {
        catalogEvents.push(event.payload.entry.name);
      });
      const appReady: EventCatalogEntry = runtime.requireCatalogEntry('app.ready');
      const messageAdded: EventCatalogEntry = runtime.requireCatalogEntry('message.added');
      const mappedMessage = runtime.mapUpstreamEventName('message_received');
      const mappedChat = runtime.mapUpstreamEventName('chatLoaded');
      const published = runtime.publishCatalogEvent('app.ready', 'runtime ready');

      expect(appReady.pluginVisible).assertTrue();
      expect(appReady.uiVisible).assertTrue();
      expect(appReady.payloadFields[0]).assertEqual('runtimeVersion');
      expect(messageAdded.payloadFields[0]).assertEqual('chatId');
      expect(mappedMessage).assertEqual('message.added');
      expect(mappedChat).assertEqual('chat.loaded');
      expect(published.payload.entry.name).assertEqual('app.ready');
      expect(catalogEvents[0]).assertEqual('app.ready');
    });

    it('isolates payload objects between subscribers and returned event', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      const observed = new Array<string>();
      bus.subscribe<MutableEventPayload>('mutable.event', (event: RuntimeEvent<MutableEventPayload>) => {
        event.payload.title = 'changed-title';
        event.payload.items[0] = 'changed-item';
        event.payload.nested.value = 'changed-nested';
      });
      bus.subscribe<MutableEventPayload>('mutable.event', (event: RuntimeEvent<MutableEventPayload>) => {
        observed.push(`${event.payload.title}:${event.payload.items[0]}:${event.payload.nested.value}`);
      });
      const original: MutableEventPayload = {
        title: 'original-title',
        items: ['original-item'],
        nested: { value: 'original-nested' },
      };
      const published = bus.publish<MutableEventPayload>('mutable.event', original);

      expect(observed[0]).assertEqual('original-title:original-item:original-nested');
      expect(published.payload.title).assertEqual('original-title');
      expect(published.payload.items[0]).assertEqual('original-item');
      expect(published.payload.nested.value).assertEqual('original-nested');
      expect(original.title).assertEqual('original-title');
      expect(original.items[0]).assertEqual('original-item');
      expect(original.nested.value).assertEqual('original-nested');
    });
  });
}
