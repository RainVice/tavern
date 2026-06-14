import type { TavernScope } from '../contracts/PublicContracts';

/**
 * 一条安全规则的完整定义，包含匹配模式与处置动作。
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
 * 安全检查操作完成后返回给调用方的结果。
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
 * 安全检查的一次审核记录，包含输入内容与最终结果。
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
 * 安全检查事件发布时携带的 payload，内含检查结果。
 */
export interface SecurityCheckPayload {
  /**
   * 处理结果。
   */
  result: SecurityCheckResult;
}
/**
 * 模块数据导出时使用的容器，包含所有安全规则的快照。
 */
export interface SecurityExportData {
  /**
   * 规则列表。
   */
  rules: Array<SecurityRule>;
}
