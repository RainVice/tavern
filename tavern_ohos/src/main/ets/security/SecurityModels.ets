/**
 * 描述安全检查模块在运行时交换的数据结构。
 * 由 addRule 方法创建，用于在 checkInput 方法中遍历匹配，决定对输入文本的处理方式。
 */
export interface SecurityRule {
  /**
   * 规则标识，格式如 "sec-rule-{数字}"，在 rules 映射表中作为唯一键，
   * 用于 removeRule 移除和 checkInput 匹配命中后记录。。
   */
  ruleId: string;
  /**
   * 匹配模式文本，在 checkInput 中通过 indexOf 检查输入是否包含该模式字符串。
   * 当输入文本中出现该模式时触发对应的处理动作。
   */
  pattern: string;
  /**
   * 处理动作，在 checkInput 匹配命中时决定对输入的处置方式：
   * "block" 的规则导致 checkInput 返回 passed=false（阻止通过）；
   * "warn" 的规则导致 checkInput 返回 passed=true 但附带警告（仅警告）；
   * "sanitize" 的规则同样导致 passed=true（当前仅为标记，实际清洗由调用方处理）。
   */
  action: 'block'|'warn'|'sanitize';
  /**
   * 作用域，在 checkInput 中用于限定规则适用的上下文范围（如 "input"、"output"、"command"），
   * 只有 scope 匹配的规则才会被检查。
   */
  scope: string;
  /**
   * 启用状态。enabled 为 true 时规则参与 checkInput 检查，false 时被跳过。
   */
  enabled: boolean;
}
/**
 * 描述安全检查操作完成后返回给调用方的结果。
 * 由 checkInput 方法返回，调用方根据 passed 判断是否允许后续操作继续进行。
 */
export interface SecurityCheckResult {
  /**
   * 通过状态，为 true 表示所有匹配的规则均为 warn/sanitize 类型（仅警告），
   * 为 false 表示命中 block 类型规则，应阻止当前操作继续执行。
   */
  passed: boolean;
  /**
   * 规则标识，当有规则匹配时记录触发该结果的规则 ID，为空字符串表示无规则匹配。
   */
  ruleId: string;
  /**
   * 消息文本，描述匹配结果（如 "block: 匹配到规则 sec-rule-1"），
   * 供 UI 层展示安全警告或拦截原因。
   */
  message: string;
}
/**
 * 描述安全检查持久化或内存索引中的一条记录。
 * 由 checkInput 在命中规则时自动创建并保存到 audits 数组中，
 * 供 listAudits 方法返回审计历史。
 */
export interface SecurityAuditRecord {
  /**
   * audit 标识，格式如 "audit-{数字}"，在审计记录列表中唯一标识一次检查。
   */
  auditId: string;
  /**
   * 规则标识，记录本次审计命中的安全规则 ID。
   */
  ruleId: string;
  /**
   * 输入内容，被检查的原始文本，用于审计回溯时查看触发安全规则的输入。
   */
  input: string;
  /**
   * 处理结果，包含是否通过及规则信息，在审计记录中保存完整的检查结论。
   */
  result: SecurityCheckResult;
  /**
   * 时间戳（毫秒），记录安全检查发生的时间，用于按时间排序审计记录。
   */
  timestamp: number;
}
/**
 * 描述安全检查事件发布时携带的数据结构。
 * 当 checkInput 方法命中规则时，通过事件总线发布给宿主或其他模块（如 UI 警告显示）。
 */
export interface SecurityCheckPayload {
  /**
   * 处理结果，宿主可监听 "security.check" 事件获取检查结果并在 UI 中展示警告或拦截提示。
   */
  result: SecurityCheckResult;
}
/**
 * 描述安全检查模块在运行时交换的数据结构。
 * 用于数据导出（备份/迁移/SillyTavern 互通），包含所有已注册的安全规则列表。
 */
export interface SecurityExportData {
  /**
   * 规则列表，包含所有已注册的 SecurityRule 对象。
   * 在 exportData() 中收集并返回，供 importData() 恢复使用。
   */
  rules: Array<SecurityRule>;
}
