import type { ConnectionHeaderRecord } from '../connection/ConnectionProfileModels';

/**
 * 描述网络请求头模块在运行时交换的数据结构。
 */
export interface NetworkHeaderOverrideRule {
  /**
   * 此规则匹配到的请求应覆写的目标主机列表。
   */
  hosts: Array<string>;
  /**
   * 匹配命中后应用于请求的请求头列表。
   */
  headers: Array<ConnectionHeaderRecord>;
}
