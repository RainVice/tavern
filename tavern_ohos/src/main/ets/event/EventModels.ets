import type { RuntimeSource } from '../contracts/PublicContracts';

/**
 * 描述事件目录事件发布时携带的数据结构。
 */
export interface ServerStartedPayload {
  /**
   * 来源类型，由当前实例内部维护。
   */
  source: RuntimeSource;
}

/**
 * 描述事件目录事件发布时携带的数据结构。
 */
export interface RuntimeSignalPayload {
  /**
   * signal 值，由当前实例内部维护。
   */
  signal: string;
  /**
   * detail 值，由当前实例内部维护。
   */
  detail: string;
}

/**
 * 描述事件目录持久化或内存索引中的一条记录。
 */
export interface EventCatalogEntry {
  /**
   * 名称。
   */
  name: string;
  /**
   * upstream 名称。
   */
  upstreamName: string;
  /**
   * domain 值，由当前实例内部维护。
   */
  domain: string;
  /**
   * payload Fields 列表，由当前实例内部维护。
   */
  payloadFields: Array<string>;
  /**
   * plugin Visible 值，由当前实例内部维护。
   */
  pluginVisible: boolean;
  /**
   * ui Visible 值，由当前实例内部维护。
   */
  uiVisible: boolean;
}

/**
 * 描述事件目录事件发布时携带的数据结构。
 */
export interface EventCatalogPayload {
  /**
   * 条目记录，由当前实例内部维护。
   */
  entry: EventCatalogEntry;
  /**
   * detail 值，由当前实例内部维护。
   */
  detail: string;
}
