import { EventBus } from '../runtime/EventBus';
import type { RuntimeEvent } from '../runtime/EventBus';
import type {
  EventCatalogEntry,
  EventCatalogPayload,
  RuntimeSignalPayload,
  ServerStartedPayload,
} from './EventModels';

/**
 * 提供事件目录相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 事件目录用于集中注册和管理系统内所有可发布事件的元数据，
 * 供插件发现、事件路由以及 UI 事件监控界面使用。
 */
export class EventRuntime {
  /**
   * 事件总线，用于将目录变更事件（如 catalog 发布）广播给宿主和各模块。
   */
  private events: EventBus;
  /**
   * 事件目录条目映射，键为事件注册名称（如 'app.ready'），
   * 值为事件元数据（EventCatalogEntry），支持按名称查找事件信息。
   */
  private catalog: Map<string, EventCatalogEntry> = new Map<string, EventCatalogEntry>();
  /**
   * 上游名称到注册名称的映射，
   * 用于将外部插件使用的事件名转换为内部注册名，实现插件兼容性。
   */
  private upstreamMap: Map<string, string> = new Map<string, string>();

  /**
   * 初始化当前运行时实例，在构造过程中调用 registerDefaultCatalog 注册内置事件目录。
   * @param events 事件总线实例，用于在发布事件目录事件时向 EventBus 广播消息。
   */
  constructor(events: EventBus) {
    this.events = events;
    this.registerDefaultCatalog();
  }

  /**
   * 发布服务启动完成事件，通知各模块服务已就绪。
   * 通常在应用初始化流程的最后阶段由宿主调用。
   * @param source 事件来源标识，标明哪个模块或组件触发了服务启动，
   *               插件系统可据此跟踪启动序列。
   */
  emitServerStarted(source: string): RuntimeEvent<ServerStartedPayload> {
    const payload: ServerStartedPayload = {
      source: source,
    };
    return this.events.publish<ServerStartedPayload>('server-started', payload);
  }

  /**
   * 发布运行时信号事件，用于传递运行时状态变更信号。
   * 在运行时生命周期转换（启动/停止/错误）时调用，监听方可据此调整自身行为。
   * @param signal 运行时信号标识，例如 'start'、'stop'、'error'，标示当前所处的生命周期阶段。
   * @param detail 信号附带的结构化详情，如错误描述或启动耗时。
   */
  emitRuntimeSignal(signal: string, detail: string): RuntimeEvent<RuntimeSignalPayload> {
    const payload: RuntimeSignalPayload = {
      signal: signal,
      detail: detail,
    };
    return this.events.publish<RuntimeSignalPayload>('runtime.signal', payload);
  }

  /**
   * 返回事件目录中所有已注册条目的副本列表，按名称字母序排序。
   * 供 UI 事件管理界面或插件发现流程使用，列出系统支持的所有可发布事件。
   * @returns 事件目录条目列表，每个条目均为副本，修改返回值不影响内部状态。
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
   * 根据注册名称查找事件目录条目，如果不存在则抛出错误。
   * 在事件发布前由 publishCatalogEvent 等内部方法调用，确保事件已注册。
   * @param name 事件目录中的注册名称，例如 'app.ready'，必须在此之前已通过 registerCatalogEntry 注册。
   * @throws 当指定名称未在事件目录中注册时抛出错误。
   */
  requireCatalogEntry(name: string): EventCatalogEntry {
    const entry = this.catalog.get(name);
    if (entry === undefined) {
      throw new Error(`Runtime event not registered: ${name}`);
    }
    return this.cloneCatalogEntry(entry);
  }

  /**
   * 将上游（外部插件）事件名称映射为内部注册的事件名称，未注册时原样返回。
   * 在插件系统接收到外部事件时调用，用于名称转换后再进行内部路由。
   * @param upstreamName 上游/外部插件使用的事件名称，可能不是内部注册名。
   * @returns 映射后的内部注册名称；如果未找到映射关系则原样返回入参。
   */
  mapUpstreamEventName(upstreamName: string): string {
    const mapped = this.upstreamMap.get(upstreamName);
    if (mapped === undefined) {
      return upstreamName;
    }
    return mapped;
  }

  /**
   * 发布事件目录事件，按名称查找条目后发布到总线，通知宿主或其他模块。
   * 当某个模块需要广播目录事件时调用，监听方可通过 'event.catalog.published' 接收。
   * @param name 事件目录注册名称，决定发布的事件标识，必须已通过 registerCatalogEntry 注册。
   * @param detail 事件附带的操作或状态描述信息，携带本次发布的额外上下文。
   */
  publishCatalogEvent(name: string, detail: string): RuntimeEvent<EventCatalogPayload> {
    const payload: EventCatalogPayload = {
      entry: this.requireCatalogEntry(name),
      detail: detail,
    };
    return this.events.publish<EventCatalogPayload>('event.catalog.published', payload);
  }

  /**
   * 注册默认事件目录条目，覆盖应用生命周期、聊天、消息、角色、生成、流式传输、设置等核心业务事件。
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
   * 将一条事件条目注册到事件目录，同时建立上游名称到注册名称的映射。
   * @param name 事件注册名称，在目录中唯一标识该事件。
   * @param upstreamName 上游/外部插件使用的映射名称。
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
   * 深拷贝事件目录条目，防止外部代码通过返回值修改内部状态。
   * @param entry 要复制的原始事件目录条目。
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
