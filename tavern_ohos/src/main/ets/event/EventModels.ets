import type { RuntimeSource } from '../contracts/PublicContracts';

/**
 * server-started 事件发布时携带的数据载荷。
 */
export interface ServerStartedPayload {
  /**
   * 触发事件的运行时来源类型。
   */
  source: RuntimeSource;
}

/**
 * runtime.signal 事件发布时携带的数据载荷。
 */
export interface RuntimeSignalPayload {
  /**
   * 信号标识。
   */
  signal: string;
  /**
   * 与信号关联的补充信息。
   */
  detail: string;
}

/**
 * 事件目录中的一条注册记录，描述事件的元信息。
 */
export interface EventCatalogEntry {
  /**
   * 事件的唯一注册名称。
   */
  name: string;
  /**
   * 事件在上游（插件层）对应的名称，用于上下游映射。
   */
  upstreamName: string;
  /**
   * 事件所属领域。
   */
  domain: string;
  /**
   * 事件载荷中包含的字段名称列表。
   */
  payloadFields: Array<string>;
  /**
   * 是否对插件可见。
   */
  pluginVisible: boolean;
  /**
   * 是否在 UI 层可见。
   */
  uiVisible: boolean;
}

/**
 * event.catalog.published 事件发布时携带的数据载荷。
 */
export interface EventCatalogPayload {
  /**
   * 对应的事件目录条目。
   */
  entry: EventCatalogEntry;
  /**
   * 事件发布时的附加说明。
   */
  detail: string;
}
