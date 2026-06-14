import { EventBus } from '../runtime/EventBus';
import type { RuntimeEvent } from '../runtime/EventBus';
import type { RuntimeSource } from '../contracts/PublicContracts';
import type {
  EventCatalogEntry,
  EventCatalogPayload,
  RuntimeSignalPayload,
  ServerStartedPayload,
} from './EventModels';

/**
 * 事件目录运行时，管理事件注册、查询、发布及上游名称映射。
 */
export class EventRuntime {
  /**
   * 事件总线实例，用于事件的发布与订阅。
   */
  private events: EventBus;
  /**
   * 事件目录映射，键为事件注册名称，值为目录条目。
   */
  private catalog: Map<string, EventCatalogEntry> = new Map<string, EventCatalogEntry>();
  /**
   * 上游事件名称到目录注册名称的映射表。
   */
  private upstreamMap: Map<string, string> = new Map<string, string>();

  /**
   * 初始化运行时实例并注册默认事件目录。
   * @param events 事件总线实例。
   */
  constructor(events: EventBus) {
    this.events = events;
    this.registerDefaultCatalog();
  }

  /**
   * 发布 server-started 事件，通知运行时启动完成。
   * @param source 来源类型。
   * @returns 已发布的事件实例。
   */
  emitServerStarted(source: RuntimeSource): RuntimeEvent<ServerStartedPayload> {
    const payload: ServerStartedPayload = {
      source: source,
    };
    return this.events.publish<ServerStartedPayload>('server-started', payload);
  }

  /**
   * 发布 runtime.signal 事件，传递运行时信号。
   * @param signal 信号标识。
   * @param detail 与信号关联的补充信息。
   * @returns 已发布的事件实例。
   */
  emitRuntimeSignal(signal: string, detail: string): RuntimeEvent<RuntimeSignalPayload> {
    const payload: RuntimeSignalPayload = {
      signal: signal,
      detail: detail,
    };
    return this.events.publish<RuntimeSignalPayload>('runtime.signal', payload);
  }

  /**
   * 读取事件目录列表，返回排序后的副本，外部修改不影响内部状态。
   * @returns 按名称排序的事件目录条目列表。
   */
  listCatalog(): Array<EventCatalogEntry> {
    const entries = Array.from(this.catalog.values());
    const result = new Array<EventCatalogEntry>();
    for (let index = 0; index < entries.length; index += 1) {
      result.push(this.cloneCatalogEntry(entries[index]));
    }
    result.sort((left: EventCatalogEntry, right: EventCatalogEntry) => left.name.localeCompare(right.name));
    return result;
  }

  /**
   * 根据名称获取事件目录条目，不存在时抛出异常。
   * @param name 事件的注册名称。
   * @returns 事件目录条目的副本。
   */
  requireCatalogEntry(name: string): EventCatalogEntry {
    const entry = this.catalog.get(name);
    if (entry === undefined) {
      throw new Error(`Runtime event not registered: ${name}`);
    }
    return this.cloneCatalogEntry(entry);
  }

  /**
   * 将上游事件名称映射为目录注册名称，未注册时直接返回原名称。
   * @param upstreamName 上游事件名称。
   * @returns 目录注册名称，或未注册时返回原名称。
   */
  mapUpstreamEventName(upstreamName: string): string {
    const mapped = this.upstreamMap.get(upstreamName);
    if (mapped === undefined) {
      return upstreamName;
    }
    return mapped;
  }

  /**
   * 发布事件目录变更事件，将目录状态变化通知给宿主或其他运行时。
   * @param name 事件的注册名称。
   * @param detail 事件发布时的附加说明。
   * @returns 已发布的事件实例。
   */
  publishCatalogEvent(name: string, detail: string): RuntimeEvent<EventCatalogPayload> {
    const payload: EventCatalogPayload = {
      entry: this.requireCatalogEntry(name),
      detail: detail,
    };
    return this.events.publish<EventCatalogPayload>('event.catalog.published', payload);
  }

  /**
   * 注册一组默认事件目录条目，覆盖核心运行时生命周期事件。
   */
  private registerDefaultCatalog(): void {
    this.registerCatalogEntry('app.ready', 'app_ready', 'app', ['runtimeVersion', 'userId'], true, true);
    this.registerCatalogEntry('app.initialized', 'app_initialized', 'app', ['runtimeVersion', 'userId'], true, true);
    this.registerCatalogEntry('chat.loaded', 'chatLoaded', 'chat', ['chatId'], true, true);
    this.registerCatalogEntry('chat.changed', 'chat_id_changed', 'chat', ['chatId'], true, true);
    this.registerCatalogEntry('message.added', 'message_received', 'message', ['chatId', 'messageId'], true, true);
    this.registerCatalogEntry('message.sent', 'message_sent', 'message', ['chatId', 'messageId'], true, true);
    this.registerCatalogEntry('message.updated', 'message_updated', 'message', ['chatId', 'messageId'], true, true);
    this.registerCatalogEntry('character.updated', 'character_edited', 'character', ['characterId', 'changes'], true, true);
    this.registerCatalogEntry('generation.started', 'generation_started', 'generation', ['taskId', 'chatId'], true, true);
    this.registerCatalogEntry('generation.ended', 'generation_ended', 'generation', ['taskId', 'chatId'], true, true);
    this.registerCatalogEntry('stream.delta', 'stream_token_received', 'stream', ['taskId', 'messageId', 'delta', 'snapshot'], true, true);
    this.registerCatalogEntry('settings.changed', 'settings_updated', 'settings', ['scope', 'key', 'oldValue', 'newValue'], true, true);
    this.registerCatalogEntry('secret.rotated', 'secret_rotated', 'secret', ['secretRef', 'providerId'], true, false);
    this.registerCatalogEntry('worldinfo.activated', 'world_info_activated', 'worldinfo', ['entries', 'matches'], true, true);
  }

  /**
   * 向事件目录注册一条事件记录，同时建立名称映射。
   * @param name 事件的唯一注册名称。
   * @param upstreamName 上游插件层使用的事件名称。
   * @param domain 事件所属领域。
   * @param payloadFields 事件载荷中包含的字段名称列表。
   * @param pluginVisible 是否对插件可见。
   * @param uiVisible 是否在 UI 层可见。
   */
  private registerCatalogEntry(
    name: string,
    upstreamName: string,
    domain: string,
    payloadFields: Array<string>,
    pluginVisible: boolean,
    uiVisible: boolean,
  ): void {
    const entry: EventCatalogEntry = {
      name: name,
      upstreamName: upstreamName,
      domain: domain,
      payloadFields: payloadFields.slice(),
      pluginVisible: pluginVisible,
      uiVisible: uiVisible,
    };
    this.catalog.set(name, entry);
    this.upstreamMap.set(upstreamName, name);
  }

  /**
   * 深拷贝事件目录条目，防止外部修改影响内部状态。
   * @param entry 待拷贝的事件目录条目。
   * @returns 拷贝后的新条目。
   */
  private cloneCatalogEntry(entry: EventCatalogEntry): EventCatalogEntry {
    return {
      name: entry.name,
      upstreamName: entry.upstreamName,
      domain: entry.domain,
      payloadFields: entry.payloadFields.slice(),
      pluginVisible: entry.pluginVisible,
      uiVisible: entry.uiVisible,
    };
  }
}
