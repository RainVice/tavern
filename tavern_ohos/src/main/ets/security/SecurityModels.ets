export interface SecurityRule { ruleId: string; pattern: string; action: 'block'|'warn'|'sanitize'; scope: string; enabled: boolean; }
export interface SecurityCheckResult { passed: boolean; ruleId: string; message: string; }
export interface SecurityAuditRecord { auditId: string; ruleId: string; input: string; result: SecurityCheckResult; timestamp: number; }
export interface SecurityCheckPayload { result: SecurityCheckResult; }
export interface SecurityExportData { rules: Array<SecurityRule>; }
