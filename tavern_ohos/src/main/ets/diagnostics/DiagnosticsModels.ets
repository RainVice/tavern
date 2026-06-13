/**
 * 描述诊断记录持久化或内存索引中的一条记录。
 */
export interface DiagnosticRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * kind 值，由当前实例内部维护。
   */
  kind: string;
  /**
   * subject 标识。
   */
  subjectId: string;
  /**
   * label 值，由当前实例内部维护。
   */
  label: string;
  /**
   * 状态值，由当前实例内部维护。
   */
  status: string;
  /**
   * 消息数据。
   */
  message: string;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
}

/**
 * 描述诊断记录模块在运行时交换的数据结构。
 */
export interface DiagnosticBundle {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * 路径。
   */
  path: string;
  /**
   * 记录副本列表，由当前实例内部维护。
   */
  records: Array<DiagnosticRecord>;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
}

/**
 * 描述诊断记录模块在运行时交换的数据结构。
 */
export interface DiagnosticHealthSummary {
  /**
   * total Records 列表，由当前实例内部维护。
   */
  totalRecords: number;
  /**
   * error Count 值，由当前实例内部维护。
   */
  errorCount: number;
  /**
   * warning Count 值，由当前实例内部维护。
   */
  warningCount: number;
  /**
   * 状态值，由当前实例内部维护。
   */
  status: string;
}

/**
 * 描述诊断记录事件发布时携带的数据结构。
 */
export interface DiagnosticsRecordCreatedPayload {
  /**
   * 记录数据。
   */
  record: DiagnosticRecord;
}

/**
 * 描述诊断记录事件发布时携带的数据结构。
 */
export interface DiagnosticsBundleCreatedPayload {
  /**
   * bundle 值，由当前实例内部维护。
   */
  bundle: DiagnosticBundle;
}
