import { EventBus } from '../runtime/EventBus';
import type { SecurityAuditRecord, SecurityCheckPayload, SecurityCheckResult, SecurityExportData, SecurityRule } from './SecurityModels';

export class SecurityRuntime {
  private events: EventBus; private rules: Map<string,SecurityRule>=new Map(); private audits: Array<SecurityAuditRecord>=[];
  private ruleCounter=0; private auditCounter=0;
  constructor(events: EventBus) { this.events=events; }

  addRule(pattern: string, action: 'block'|'warn'|'sanitize', scope: string): SecurityRule {
    this.ruleCounter+=1; const ruleId=`sec-rule-${this.ruleCounter}`;
    const rule: SecurityRule = { ruleId, pattern, action, scope, enabled: true };
    this.rules.set(ruleId, this.copyRule(rule)); return this.copyRule(rule);
  }

  removeRule(ruleId: string): void {
    if (this.rules.get(ruleId)===undefined) throw new Error(`安全规则未找到: ${ruleId}`);
    this.rules.delete(ruleId);
  }

  // 安全检查
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

  listRules(): Array<SecurityRule> {
    const result = new Array<SecurityRule>();
    const values=Array.from(this.rules.values());
    for (let i=0;i<values.length;i++) result.push(this.copyRule(values[i]));
    return result;
  }
  listAudits(): Array<SecurityAuditRecord> {
    const result = new Array<SecurityAuditRecord>();
    for (let i=0;i<this.audits.length;i++) result.push(this.copyAudit(this.audits[i]));
    return result;
  }

  exportData(): SecurityExportData { return { rules: this.listRules() }; }
  importData(data: SecurityExportData): void {
    for (let i=0;i<data.rules.length;i++) {
      const rule = this.copyRule(data.rules[i]);
      this.rules.set(rule.ruleId, rule);
      this.ruleCounter = Math.max(this.ruleCounter, this.parseRuleCounter(rule.ruleId));
    }
  }

  private copyRule(rule: SecurityRule): SecurityRule {
    return {
      ruleId: rule.ruleId,
      pattern: rule.pattern,
      action: rule.action,
      scope: rule.scope,
      enabled: rule.enabled,
    };
  }

  private copyResult(result: SecurityCheckResult): SecurityCheckResult {
    return {
      passed: result.passed,
      ruleId: result.ruleId,
      message: result.message,
    };
  }

  private copyAudit(audit: SecurityAuditRecord): SecurityAuditRecord {
    return {
      auditId: audit.auditId,
      ruleId: audit.ruleId,
      input: audit.input,
      result: this.copyResult(audit.result),
      timestamp: audit.timestamp,
    };
  }

  private parseRuleCounter(ruleId: string): number {
    if (!ruleId.startsWith('sec-rule-')) {
      return 0;
    }
    const parsed = Number(ruleId.substring(9));
    return parsed > 0 ? parsed : 0;
  }
}
