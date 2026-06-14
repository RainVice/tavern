import { EventBus } from '../runtime/EventBus';
import type { TavernScope } from '../contracts/PublicContracts';
import type { SecurityAuditRecord, SecurityCheckPayload, SecurityCheckResult, SecurityExportData, SecurityRule } from './SecurityModels';

/**
 * 提供安全检查相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class SecurityRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus; private rules: Map<string,SecurityRule>=new Map(); private audits: Array<SecurityAuditRecord>=[];
  private ruleCounter=0; private auditCounter=0;
  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) { this.events=events; }

  /**
   * 创建或写入Rule，完成持久化后返回可供调用方使用的结果。


   * @param scope 绑定或查询使用的作用域。
   */
  addRule(pattern: string, action: 'block'|'warn'|'sanitize', scope: TavernScope): SecurityRule {
    this.ruleCounter+=1; const ruleId=`sec-rule-${this.ruleCounter}`;
    const rule: SecurityRule = { ruleId, pattern, action, scope, enabled: true };
    this.rules.set(ruleId, this.copyRule(rule)); return this.copyRule(rule);
  }

  /**
   * 移除安全规则，用于解除注册、绑定或索引关系。
   * @param ruleId 目标规则标识。
   */
  removeRule(ruleId: string): void {
    if (this.rules.get(ruleId)===undefined) throw new Error(`安全规则未找到: ${ruleId}`);
    this.rules.delete(ruleId);
  }

  /**
   * 检查Input是否满足当前规则。
   * @param scope 绑定或查询使用的作用域。
   * @param input 待处理的输入对象。
   */
  checkInput(scope: TavernScope, input: string): SecurityCheckResult {
    const values=Array.from(this.rules.values());
    for (let i=0;i<values.length;i++) {
      if (!values[i].enabled||values[i].scope!==scope) continue;
      if (input.indexOf(values[i].pattern)>=0) {
        const result: SecurityCheckResult = { passed: values[i].action==='warn', ruleId: values[i].ruleId, message: `${values[i].action}: 匹配到规则 ${values[i].ruleId}` };
        this.auditCounter+=1;
        this.audits.push({ auditId:`audit-${this.auditCounter}`, ruleId: values[i].ruleId, input, result: this.copyResult(result), timestamp: Date.now() });
        this.events.publish<SecurityCheckPayload>('security.check', { result: this.copyResult(result) });
        return this.copyResult(result);
      }
    }
    return { passed: true, ruleId: '', message: '' };
  }

  /**
   * 读取Rules列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listRules(): Array<SecurityRule> {
    const result = new Array<SecurityRule>();
    const values=Array.from(this.rules.values());
    for (let i=0;i<values.length;i++) result.push(this.copyRule(values[i]));
    return result;
  }
  /**
   * 读取Audits列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listAudits(): Array<SecurityAuditRecord> {
    const result = new Array<SecurityAuditRecord>();
    for (let i=0;i<this.audits.length;i++) result.push(this.copyAudit(this.audits[i]));
    return result;
  }

  /**
   * 导出数据，用于备份、迁移或与 SillyTavern 数据互通。
   * @returns 可持久化或可传输的导出内容。
   */
  exportData(): SecurityExportData { return { rules: this.listRules() }; }
  /**
   * 从外部数据导入Data 值，转换为当前运行时的数据结构。
   * @param data 导入或恢复使用的序列化数据。
   */
  importData(data: SecurityExportData): void {
    for (let i=0;i<data.rules.length;i++) {
      const rule = this.copyRule(data.rules[i]);
      this.rules.set(rule.ruleId, rule);
      this.ruleCounter = Math.max(this.ruleCounter, this.parseRuleCounter(rule.ruleId));
    }
  }

  /**
   * 复制Rule 值，避免外部修改内部状态。
   * @param rule 待匹配的策略规则。
   */
  private copyRule(rule: SecurityRule): SecurityRule {
    return {
      ruleId: rule.ruleId,
      pattern: rule.pattern,
      action: rule.action,
      scope: rule.scope,
      enabled: rule.enabled,
    };
  }

  /**
   * 复制Result 值，避免外部修改内部状态。
   * @param result 返回结果。
   */
  private copyResult(result: SecurityCheckResult): SecurityCheckResult {
    return {
      passed: result.passed,
      ruleId: result.ruleId,
      message: result.message,
    };
  }

  /**
   * 复制Audit 值，避免外部修改内部状态。
   */
  private copyAudit(audit: SecurityAuditRecord): SecurityAuditRecord {
    return {
      auditId: audit.auditId,
      ruleId: audit.ruleId,
      input: audit.input,
      result: this.copyResult(audit.result),
      timestamp: audit.timestamp,
    };
  }

  /**
   * 解析RuleCounter，非法输入会返回失败标记或空结果。
   * @param ruleId 目标规则标识。
   */
  private parseRuleCounter(ruleId: string): number {
    if (!ruleId.startsWith('sec-rule-')) {
      return 0;
    }
    const parsed = Number(ruleId.substring(9));
    return parsed > 0 ? parsed : 0;
  }
}
