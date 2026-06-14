/**
 * 网络请求头模块导出。
 * NetworkService：提供按连接配置和 API 类型组装请求头、密钥值注入及预览掩盖的运行时能力。
 * 调用方在发起 API 请求前通过此服务解析目标连接的完整请求头，确保认证和鉴权信息正确。
 * NetworkModels：定义请求头覆盖规则的接口类型。
 * 用于按 host 自动追加自定义请求头的规则配置。
 */
export { NetworkService } from './NetworkService';
export type { NetworkHeaderOverrideRule } from './NetworkModels';
