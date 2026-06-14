import type { ConnectionHeaderRecord } from '../connection/ConnectionProfileModels';

/**
 * 描述网络请求头覆盖规则，按 host 匹配后追加指定请求头。
 * 用于 NetworkService 在组装 API 请求头时，根据目标服务器地址自动追加额外的自定义头。
 */
export interface NetworkHeaderOverrideRule {
  /**
   * 规则匹配的域名或主机名列表，用于在 resolveHeadersForProfile 中匹配服务器 URL 的 host 部分。
   */
  hosts: Array<string>;
  /**
   * 匹配成功后追加到请求的请求头列表，用于向特定服务器注入自定义请求头。
   */
  headers: Array<ConnectionHeaderRecord>;
}
