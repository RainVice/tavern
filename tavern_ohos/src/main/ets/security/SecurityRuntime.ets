import { EventBus } from '../runtime/EventBus';
import type { SecurityAuditRecord, SecurityCheckPayload, SecurityCheckResult, SecurityExportData, SecurityRule } from './SecurityModels';

/**
 * 提供安全检查相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 在对话流程中由输入/输出处理模块调用 checkInput 进行安全过滤，
 * 由 UI 层调用以管理安全规则（addRule / removeRule）和查看审计日志（listAudits）。
 */
export class SecurityRuntime {
  private events: EventBus; private rules: Map<string,SecurityRule>=new Map(); private audits: Array<SecurityAuditRecord>=[];
  private ruleCounter=0; private auditCounter=0;
  /**
   * 初始化当前运行时实例，绑定事件总线用于发布安全检查结果事件。
   * @param events 事件总线实例，用于在安全规则命中时发布 "security.check" 事件。
   */
  constructor(events: EventBus) { this.events=events; }

  /**
   * 添加一条安全规则，根据模式匹配对输入执行阻止、警告或清洗操作。
   * 由 UI 层或安全策略模块在配置安全规则时调用，将规则注册到内部索引供后续检查使用。
   * @param pattern 匹配模式文本，在 checkInput 中通过 indexOf 进行存在性匹配。
   * @param action 匹配后的处理动作：block（阻止操作继续进行）、warn（允许通过但发出警告）、sanitize（允许通过但标记需清洗）。
   * @param scope 该规则适用的作用域，在 checkInput 中通过 scope 过滤，仅限匹配作用域的规则参与检查。
   */
  addRule(pattern: string, action: 'block'|'warn'|'sanitize', scope: string): SecurityRule {
    this.ruleCounter+=1; const ruleId=`sec-rule-${this.ruleCounter}`;
    const rule: SecurityRule = { ruleId, pattern, action, scope, enabled: true };
    this.rules.set(ruleId, this.copyRule(rule)); return this.copyRule(rule);
  }

  /**
   * 移除指定的安全规则。
   * 由 UI 层在用户删除安全规则时调用，将该规则从内存索引中清除。
   * @param ruleId 要移除的规则标识，由用户选择的具体规则决定。
   */
  removeRule(ruleId: string): void {
    if (this.rules.get(ruleId)===undefined) throw new Error(`安全规则未找到: ${ruleId}`);
    this.rules.delete(ruleId);
  }

  /**
   * 对输入文本执行安全检查，遍历所有启用且作用域匹配的规则。
   * 由输入/输出处理模块在接收用户输入或 AI 输出时调用，在数据继续往下游传递前进行安全检查。
   * 命中规则后记录审计日志并发布 "security.check" 事件。
   * @param scope 要检查的作用域，与规则的 scope 字段匹配以确定适用于当前场景的规则。
   * @param input 待检查的输入文本，通常是用户消息或 AI 回复内容。
   * @returns 安全检查结果，包含是否通过及命中的规则信息。passed=false 时调用方应阻止当前操作。
   */
  checkInput(scope: string, input: string): SecurityCheckResult {
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
   * 返回所有已注册的安全规则列表。
   * 由 UI 层在安全规则管理界面初始化或刷新时调用，展示所有已注册的安全规则。
   * @returns 安全规则对象列表副本。
   */
  listRules(): Array<SecurityRule> {
    const result = new Array<SecurityRule>();
    const values=Array.from(this.rules.values());
    for (let i=0;i<values.length;i++) result.push(this.copyRule(values[i]));
    return result;
  }
  /**
   * 返回所有审计日志记录列表。
   * 由 UI 层在安全审计界面调用，展示所有历史安全检查记录供用户审查。
   * @returns 审计记录列表副本。
   */
  listAudits(): Array<SecurityAuditRecord> {
    const result = new Array<SecurityAuditRecord>();
    for (let i=0;i<this.audits.length;i++) result.push(this.copyAudit(this.audits[i]));
    return result;
  }

  /**
   * 导出数据，用于备份、迁移或与 SillyTavern 数据互通。
   * 由宿主在触发导出操作时调用，收集所有安全规则为可持久化格式。
   * @returns 可持久化或可传输的导出内容，包含所有规则的副本列表。
   */
  exportData(): SecurityExportData { return { rules: this.listRules() }; }
  /**
   * 从外部数据导入安全规则列表，合并到当前运行时。
   * 由宿主在触发导入操作时调用，data 来自 exportData() 的输出。
   * 导入后内部 ruleCounter 会根据已存在的规则 ID 自动推进。
   * @param data 包含规则列表的导出数据对象，通常来自 exportData() 的输出。
   */
  importData(data: SecurityExportData): void {
    for (let i=0;i<data.rules.length;i++) {
      const rule = this.copyRule(data.rules[i]);
      this.rules.set(rule.ruleId, rule);
      this.ruleCounter = Math.max(this.ruleCounter, this.parseRuleCounter(rule.ruleId));
    }
  }

  /**
   * 深拷贝安全规则对象。
   * @param rule 待拷贝的规则。
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
   * 深拷贝安全检查结果对象。
   * @param result 待拷贝的检查结果。
   */
  private copyResult(result: SecurityCheckResult): SecurityCheckResult {
    return {
      passed: result.passed,
      ruleId: result.ruleId,
      message: result.message,
    };
  }

  /**
   * 深拷贝审计记录对象。
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
   * 从规则 ID 中解析出自增计数器值，用于恢复计数状态。
   * @param ruleId 规则 ID 字符串，格式为 "sec-rule-{数字}"。
   * @returns 解析出的数值；格式不符时返回 0。
   */
  private parseRuleCounter(ruleId: string): number {
    if (!ruleId.startsWith('sec-rule-')) {
      return 0;
    }
    const parsed = Number(ruleId.substring(9));
    return parsed > 0 ? parsed : 0;
  }
}
