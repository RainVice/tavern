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
 * 提供事件目录相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class EventRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * catalog 值，由当前实例内部维护。
   */
  private catalog: Map<string, EventCatalogEntry> = new Map<string, EventCatalogEntry>();
  /**
   * upstream Map 值，由当前实例内部维护。
   */
  private upstreamMap: Map<string, string> = new Map<string, string>();

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
    this.registerDefaultCatalog();
  }

  /**
   * 执行 emitServerStarted 的内部处理步骤，供当前模块复用。
   * @param source 来源类型。
   */
  emitServerStarted(source: RuntimeSource): RuntimeEvent<ServerStartedPayload> {
    const payload: ServerStartedPayload = {
      source: source,
    };
    return this.events.publish<ServerStartedPayload>('server-started', payload);
  }

  /**
   * 执行 emitRuntimeSignal 的内部处理步骤，供当前模块复用。
   */
  emitRuntimeSignal(signal: string, detail: string): RuntimeEvent<RuntimeSignalPayload> {
    const payload: RuntimeSignalPayload = {
      signal: signal,
      detail: detail,
    };
    return this.events.publish<RuntimeSignalPayload>('runtime.signal', payload);
  }

  /**
   * 读取Catalog列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 读取必须存在的Catalog Entry 值，缺失时抛出错误。
   * @param name 显示名称或注册名称。
   */
  requireCatalogEntry(name: string): EventCatalogEntry {
    const entry = this.catalog.get(name);
    if (entry === undefined) {
      throw new Error(`Runtime event not registered: ${name}`);
    }
    return this.cloneCatalogEntry(entry);
  }

  /**
   * 执行 mapUpstreamEventName 的内部处理步骤，供当前模块复用。
   * @param upstreamName upstream名称。
   */
  mapUpstreamEventName(upstreamName: string): string {
    const mapped = this.upstreamMap.get(upstreamName);
    if (mapped === undefined) {
      return upstreamName;
    }
    return mapped;
  }

  /**
   * 发布事件目录事件，把状态变化通知给宿主或其他 Runtime。
   * @param name 显示名称或注册名称。
   */
  publishCatalogEvent(name: string, detail: string): RuntimeEvent<EventCatalogPayload> {
    const payload: EventCatalogPayload = {
      entry: this.requireCatalogEntry(name),
      detail: detail,
    };
    return this.events.publish<EventCatalogPayload>('event.catalog.published', payload);
  }

  /**
   * 注册Default Catalog 值，使其可被后续运行时流程使用。
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
   * 注册Catalog Entry 值，使其可被后续运行时流程使用。
   * @param name 显示名称或注册名称。
   * @param upstreamName upstream名称。
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
   * 复制Catalog Entry 值，避免外部修改内部状态。
   * @param entry 条目记录。
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
