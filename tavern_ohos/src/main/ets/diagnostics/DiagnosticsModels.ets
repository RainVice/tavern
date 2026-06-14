import type {
  DiagnosticKind,
  DiagnosticStatus,
  HealthStatus,
} from '../contracts/PublicContracts';

/**
 * 描述诊断记录持久化或内存索引中的一条记录。
 */
export interface DiagnosticRecord {
  /**
   * 唯一标识。
   */
  id: string;
  /**
   * 诊断记录类型。
   */
  kind: DiagnosticKind;
  /**
   * 关联主体标识。
   */
  subjectId: string;
  /**
   * 来源模块标签。
   */
  label: string;
  /**
   * 诊断状态。
   */
  status: DiagnosticStatus;
  /**
   * 诊断消息内容。
   */
  message: string;
  /**
   * 记录创建时间戳。
   */
  createdAt: number;
}

/**
 * 描述诊断记录模块在运行时交换的数据结构。
 */
export interface DiagnosticBundle {
  /**
   * 唯一标识。
   */
  id: string;
  /**
   * 诊断包显示名称。
   */
  name: string;
  /**
   * 关联文件或目录路径。
   */
  path: string;
  /**
   * 包内包含的诊断记录列表。
   */
  records: Array<DiagnosticRecord>;
  /**
   * 包创建时间戳。
   */
  createdAt: number;
}

/**
 * 描述诊断系统运行健康状态的摘要数据结构。
 */
export interface DiagnosticHealthSummary {
  /**
   * 诊断记录总数。
   */
  totalRecords: number;
  /**
   * 错误级别记录数。
   */
  errorCount: number;
  /**
   * 警告级别记录数。
   */
  warningCount: number;
  /**
   * 整体健康状态。
   */
  status: HealthStatus;
}

/**
 * 诊断记录创建事件发布时携带的数据结构。
 */
export interface DiagnosticsRecordCreatedPayload {
  /**
   * 已创建的诊断记录。
   */
  record: DiagnosticRecord;
}

/**
 * 诊断包创建事件发布时携带的数据结构。
 */
export interface DiagnosticsBundleCreatedPayload {
  /**
   * 已创建的诊断包。
   */
  bundle: DiagnosticBundle;
}
