import type { ConnectionHeaderRecord } from '../connection/ConnectionProfileModels';

/**
 * 描述网络请求头模块在运行时交换的数据结构。
 */
export interface NetworkHeaderOverrideRule {
  /**
   * hosts 列表，由当前实例内部维护。
   */
  hosts: Array<string>;
  /**
   * 请求头列表，由当前实例内部维护。
   */
  headers: Array<ConnectionHeaderRecord>;
}
