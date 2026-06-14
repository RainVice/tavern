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
   * 添加一条安全规则并返回新创建的规则副本。
   * @param pattern 匹配模式字符串。
   * @param action 匹配到后的处置动作。
   * @param scope 规则适用的作用域。
   * @returns 新创建的规则副本。
   */
  addRule(pattern: string, action: 'block'|'warn'|'sanitize', scope: TavernScope): SecurityRule {
    this.ruleCounter+=1; const ruleId=`sec-rule-${this.ruleCounter}`;
    const rule: SecurityRule = { ruleId, pattern, action, scope, enabled: true };
    this.rules.set(ruleId, this.copyRule(rule)); return this.copyRule(rule);
  }

  /**
   * 移除一条安全规则。
   * @param ruleId 规则标识。
   * @throws 规则不存在时抛出异常。
   */
  removeRule(ruleId: string): void {
    if (this.rules.get(ruleId)===undefined) throw new Error(`安全规则未找到: ${ruleId}`);
    this.rules.delete(ruleId);
  }

  /**
   * 检查输入文本是否匹配当前所有已启用的规则。
   * @param scope 检查范围，只有与该作用域匹配的规则才会参与判定。
   * @param input 待检查的输入文本。
   * @returns 检查结果；passed 为 true 表示通过。
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
   * 获取所有安全规则的副本列表。
   * @returns 安全规则副本列表，修改返回值不会影响内部状态。
   */
  listRules(): Array<SecurityRule> {
    const result = new Array<SecurityRule>();
    const values=Array.from(this.rules.values());
    for (let i=0;i<values.length;i++) result.push(this.copyRule(values[i]));
    return result;
  }
  /**
   * 获取所有审核记录的副本列表。
   * @returns 审核记录副本列表，修改返回值不会影响内部状态。
   */
  listAudits(): Array<SecurityAuditRecord> {
    const result = new Array<SecurityAuditRecord>();
    for (let i=0;i<this.audits.length;i++) result.push(this.copyAudit(this.audits[i]));
    return result;
  }

  /**
   * 导出当前所有安全规则数据，用于备份或数据互通。
   * @returns 可持久化或传输的导出数据。
   */
  exportData(): SecurityExportData { return { rules: this.listRules() }; }
  /**
   * 从外部数据导入安全规则。
   * @param data 包含规则列表的导入数据。
   */
  importData(data: SecurityExportData): void {
    for (let i=0;i<data.rules.length;i++) {
      const rule = this.copyRule(data.rules[i]);
      this.rules.set(rule.ruleId, rule);
      this.ruleCounter = Math.max(this.ruleCounter, this.parseRuleCounter(rule.ruleId));
    }
  }

  /**
   * 创建一条安全规则的浅副本，防止外部修改影响内部状态。
   * @param rule 源规则对象。
   * @returns 规则副本。
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
   * 创建检查结果的浅副本，防止外部修改影响内部状态。
   * @param result 源检查结果对象。
   * @returns 检查结果副本。
   */
  private copyResult(result: SecurityCheckResult): SecurityCheckResult {
    return {
      passed: result.passed,
      ruleId: result.ruleId,
      message: result.message,
    };
  }

  /**
   * 创建审核记录的浅副本，防止外部修改影响内部状态。
   * @param audit 源审核记录对象。
   * @returns 审核记录副本。
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
   * 从规则标识中解析出自增计数。
   * @param ruleId 规则标识，格式为 "sec-rule-{数字}"。
   * @returns 解析出的数字；格式不合法时返回 0。
   */
  private parseRuleCounter(ruleId: string): number {
    if (!ruleId.startsWith('sec-rule-')) {
      return 0;
    }
    const parsed = Number(ruleId.substring(9));
    return parsed > 0 ? parsed : 0;
  }
}
