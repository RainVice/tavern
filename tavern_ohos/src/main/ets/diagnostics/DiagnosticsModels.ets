/**
 * 诊断记录 —— 描述一次诊断事件的基本信息，包括类型、主体、状态和消息，由 DiagnosticsRuntime 的各 trace 方法创建。
 * 用于链路追踪和问题排查，在模块调用链的各个关键节点记录执行上下文。
 */
export interface DiagnosticRecord {
  /** 记录的唯一标识，由 record 方法自动生成（格式为 "diagnostic-record-{数字}"），用于索引和过滤。 */
  id: string;
  /** 诊断类别（如 prompt / event / plugin / command / script / tool / stream），决定该记录归属于哪条追踪链路。 */
  kind: string;
  /** 诊断所关联的主体标识（如角色 ID、请求 ID、对话 ID），用于将分散的诊断记录关联到同一个主体。 */
  subjectId: string;
  /** 诊断标签，用于在 UI 中归类显示（如 PromptInspector、EventInspector），标识记录来源的检测器名称。 */
  label: string;
  /** 诊断状态（如 error / warning / info / debug），影响该记录在健康摘要中的统计归类。 */
  status: string;
  /** 诊断的具体消息内容，可能经过敏感信息脱敏处理（如 Bearer token、API key 被替换为 "redacted"）。 */
  message: string;
  /** 记录的创建时间戳（毫秒），由 record 方法在创建时写入。 */
  createdAt: number;
}

/**
 * 诊断包 —— 按指定条件筛选出的诊断记录集合，用于批量导出或分析，由 createBundle 方法创建。
 */
export interface DiagnosticBundle {
  /** 包的唯一标识，由 createBundle 自动生成（格式为 "diagnostic-bundle-{数字}"）。 */
  id: string;
  /** 包的显示名称，供调用方在 createBundle 时指定，用于 UI 展示和识别。 */
  name: string;
  /** 包的保存或导出路径，记录存档位置供后续查阅。 */
  path: string;
  /** 包中包含的诊断记录列表，按 createBundle 的 kinds 参数筛选而来。 */
  records: Array<DiagnosticRecord>;
  /** 包的创建时间戳（毫秒），由 createBundle 在打包时写入。 */
  createdAt: number;
}

/**
 * 诊断健康摘要 —— 汇总当前诊断记录中的错误和警告数量，提供整体健康状态判定，由 getHealthSummary 生成。
 */
export interface DiagnosticHealthSummary {
  /** 诊断记录总数，用于评估系统整体的诊断数据量。 */
  totalRecords: number;
  /** 状态为 error 的记录数，高数值表示系统存在较多异常需要关注。 */
  errorCount: number;
  /** 状态为 warning 的记录数，用于提示非致命但值得关注的问题。 */
  warningCount: number;
  /** 整体健康状态（"healthy" / "degraded" ），errorCount > 0 时为 "degraded"，否则为 "healthy"。 */
  status: string;
}

/**
 * 诊断记录创建时发布的事件负载，由 record 方法触发，供订阅方（如 UI 诊断面板）实时接收新记录。
 */
export interface DiagnosticsRecordCreatedPayload {
  /** 新创建的诊断记录，包含完整诊断信息，供订阅方追加到诊断列表。 */
  record: DiagnosticRecord;
}

/**
 * 诊断包创建时发布的事件负载，由 createBundle 方法触发，供订阅方接收打包完成的诊断数据。
 */
export interface DiagnosticsBundleCreatedPayload {
  /** 新创建的诊断包，包含筛选后的记录集合和元信息。 */
  bundle: DiagnosticBundle;
}
