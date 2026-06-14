import type { TavernScope } from '../contracts/PublicContracts';

/**
 * 描述安全检查模块在运行时交换的数据结构。
 */
export interface SecurityRule {
  /**
   * 规则标识。
   */
  ruleId: string;
  /**
   * 匹配模式。
   */
  pattern: string;
  /**
   * 处理动作。
   */
  action: 'block'|'warn'|'sanitize';
  /**
   * 作用域。
   */
  scope: TavernScope;
  /**
   * 启用状态。
   */
  enabled: boolean;
}
/**
 * 描述安全检查操作完成后返回给调用方的结果。
 */
export interface SecurityCheckResult {
  /**
   * 通过状态。
   */
  passed: boolean;
  /**
   * 规则标识。
   */
  ruleId: string;
  /**
   * 消息文本。
   */
  message: string;
}
/**
 * 描述安全检查持久化或内存索引中的一条记录。
 */
export interface SecurityAuditRecord {
  /**
   * audit 标识。
   */
  auditId: string;
  /**
   * 规则标识。
   */
  ruleId: string;
  /**
   * 输入内容。
   */
  input: string;
  /**
   * 处理结果。
   */
  result: SecurityCheckResult;
  /**
   * 时间戳。
   */
  timestamp: number;
}
/**
 * 描述安全检查事件发布时携带的数据结构。
 */
export interface SecurityCheckPayload {
  /**
   * 处理结果。
   */
  result: SecurityCheckResult;
}
/**
 * 描述安全检查模块在运行时交换的数据结构。
 */
export interface SecurityExportData {
  /**
   * 规则列表。
   */
  rules: Array<SecurityRule>;
}
