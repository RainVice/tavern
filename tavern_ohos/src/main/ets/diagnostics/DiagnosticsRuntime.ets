import { EventBus } from '../runtime/EventBus';
import type {
  DiagnosticKind,
  DiagnosticStatus,
} from '../contracts/PublicContracts';
import type {
  DiagnosticBundle,
  DiagnosticHealthSummary,
  DiagnosticRecord,
  DiagnosticsBundleCreatedPayload,
  DiagnosticsRecordCreatedPayload,
} from './DiagnosticsModels';

/**
 * 提供诊断记录相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class DiagnosticsRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 诊断记录列表。
   */
  private records: Array<DiagnosticRecord> = new Array<DiagnosticRecord>();
  /**
   * 诊断包列表。
   */
  private bundles: Array<DiagnosticBundle> = new Array<DiagnosticBundle>();
  /**
   * 记录计数器，用于生成自增 ID。
   */
  private recordCounter: number = 0;
  /**
   * 包计数器，用于生成自增 ID。
   */
  private bundleCounter: number = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建一条提示词诊断记录，完成记录写入并通过事件总线通知监听方。
   * @param subjectId 关联主体标识。
   * @param message 诊断消息内容。
   * @param status 诊断状态。
   * @returns 创建的诊断记录副本。
   */
  recordPromptTrace(subjectId: string, message: string, status: DiagnosticStatus): DiagnosticRecord {
    return this.record('prompt', subjectId, 'PromptInspector', message, status);
  }

  /**
   * 创建一条事件诊断记录，完成记录写入并通过事件总线通知监听方。
   * @param subjectId 关联主体标识。
   * @param message 诊断消息内容。
   * @param status 诊断状态。
   * @returns 创建的诊断记录副本。
   */
  recordEventTrace(subjectId: string, message: string, status: DiagnosticStatus): DiagnosticRecord {
    return this.record('event', subjectId, 'EventInspector', message, status);
  }

  /**
   * 创建一条插件诊断记录，完成记录写入并通过事件总线通知监听方。
   * @param subjectId 关联主体标识。
   * @param message 诊断消息内容。
   * @param status 诊断状态。
   * @returns 创建的诊断记录副本。
   */
  recordPluginTrace(subjectId: string, message: string, status: DiagnosticStatus): DiagnosticRecord {
    return this.record('plugin', subjectId, 'PluginInspector', message, status);
  }

  /**
   * 创建一条命令诊断记录，完成记录写入并通过事件总线通知监听方。
   * @param subjectId 关联主体标识。
   * @param message 诊断消息内容。
   * @param status 诊断状态。
   * @returns 创建的诊断记录副本。
   */
  recordCommandTrace(subjectId: string, message: string, status: DiagnosticStatus): DiagnosticRecord {
    return this.record('command', subjectId, 'CommandDebugger', message, status);
  }

  /**
   * 创建一条脚本诊断记录，完成记录写入并通过事件总线通知监听方。
   * @param subjectId 关联主体标识。
   * @param message 诊断消息内容。
   * @param status 诊断状态。
   * @returns 创建的诊断记录副本。
   */
  recordScriptTrace(subjectId: string, message: string, status: DiagnosticStatus): DiagnosticRecord {
    return this.record('script', subjectId, 'ScriptTrace', message, status);
  }

  /**
   * 创建一条工具调用诊断记录，完成记录写入并通过事件总线通知监听方。
   * @param subjectId 关联主体标识。
   * @param message 诊断消息内容。
   * @param status 诊断状态。
   * @returns 创建的诊断记录副本。
   */
  recordToolCallTrace(subjectId: string, message: string, status: DiagnosticStatus): DiagnosticRecord {
    return this.record('tool', subjectId, 'ToolCallTrace', message, status);
  }

  /**
   * 创建一条流式任务诊断记录，完成记录写入并通过事件总线通知监听方。
   * @param subjectId 关联主体标识。
   * @param message 诊断消息内容。
   * @param status 诊断状态。
   * @returns 创建的诊断记录副本。
   */
  recordStreamTrace(subjectId: string, message: string, status: DiagnosticStatus): DiagnosticRecord {
    return this.record('stream', subjectId, 'StreamTrace', message, status);
  }

  /**
   * 获取全部诊断记录的副本列表，外部修改不会影响内部状态。
   * @returns 诊断记录列表副本。
   */
  listRecords(): Array<DiagnosticRecord> {
    const result = new Array<DiagnosticRecord>();
    for (let index = 0; index < this.records.length; index += 1) {
      result.push(this.copyRecord(this.records[index]));
    }
    return result;
  }

  /**
   * 按诊断记录类型筛选并返回副本列表。
   * @param kind 要筛选的记录类型。
   * @returns 匹配类型的诊断记录列表副本。
   */
  listByKind(kind: DiagnosticKind): Array<DiagnosticRecord> {
    const result = new Array<DiagnosticRecord>();
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].kind === kind) {
        result.push(this.copyRecord(this.records[index]));
      }
    }
    return result;
  }

  /**
   * 筛选所有错误级别的诊断记录并返回副本列表。
   * @returns 错误级别的诊断记录列表副本。
   */
  listErrors(): Array<DiagnosticRecord> {
    const result = new Array<DiagnosticRecord>();
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].status === 'error') {
        result.push(this.copyRecord(this.records[index]));
      }
    }
    return result;
  }

  /**
   * 创建新的诊断包：筛选匹配指定类型的记录归入包内，写入存储并通过事件总线通知监听方。
   * @param name 诊断包显示名称。
   * @param kinds 要包含的记录类型列表；传空数组则包含全部记录。
   * @param path 关联的文件或目录路径。
   * @returns 创建的诊断包副本。
   */
  createBundle(name: string, kinds: Array<string>, path: string): DiagnosticBundle {
    this.bundleCounter += 1;
    const bundleRecords = new Array<DiagnosticRecord>();
    for (let index = 0; index < this.records.length; index += 1) {
      if (kinds.length === 0 || this.contains(kinds, this.records[index].kind)) {
        bundleRecords.push(this.copyRecord(this.records[index]));
      }
    }
    const bundle: DiagnosticBundle = {
      id: `diagnostic-bundle-${this.bundleCounter}`,
      name: name,
      path: path,
      records: bundleRecords,
      createdAt: Date.now(),
    };
    this.bundles.push(this.copyBundle(bundle));
    const payload: DiagnosticsBundleCreatedPayload = {
      bundle: this.copyBundle(bundle),
    };
    this.events.publish<DiagnosticsBundleCreatedPayload>('diagnostics.bundle.created', payload);
    return this.copyBundle(bundle);
  }

  /**
   * 获取全部诊断包列表的副本。
   * @returns 诊断包列表副本。
   */
  listBundles(): Array<DiagnosticBundle> {
    const result = new Array<DiagnosticBundle>();
    for (let index = 0; index < this.bundles.length; index += 1) {
      result.push(this.copyBundle(this.bundles[index]));
    }
    return result;
  }

  /**
   * 计算当前诊断记录的健康摘要，包含总数、错误数、警告数和整体健康状态。
   * @returns 健康摘要数据。
   */
  getHealthSummary(): DiagnosticHealthSummary {
    let errors = 0;
    let warnings = 0;
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].status === 'error') {
        errors += 1;
      } else if (this.records[index].status === 'warning') {
        warnings += 1;
      }
    }
    return {
      totalRecords: this.records.length,
      errorCount: errors,
      warningCount: warnings,
      status: errors > 0 ? 'degraded' : 'healthy',
    };
  }
  private record(kind: DiagnosticKind, subjectId: string, label: string, message: string, status: DiagnosticStatus): DiagnosticRecord {
    this.recordCounter += 1;
    const redactedMessage = this.redactSensitiveText(message);
    const record: DiagnosticRecord = {
      id: `diagnostic-record-${this.recordCounter}`,
      kind: kind,
      subjectId: subjectId,
      label: label,
      status: status,
      message: redactedMessage,
      createdAt: Date.now(),
    };
    this.records.push(record);
    const payload: DiagnosticsRecordCreatedPayload = {
      record: this.copyRecord(record),
    };
    this.events.publish<DiagnosticsRecordCreatedPayload>('diagnostics.record.created', payload);
    return this.copyRecord(record);
  }
  private redactSensitiveText(message: string): string {
    let output = message.replace(/Bearer\s+[A-Za-z0-9._~+/=-]+/g, 'Bearer redacted');
    output = output.replace(/sk-[A-Za-z0-9._-]{8,}/g, 'sk-redacted');
    output = output.replace(/(api[_-]?key|secret|token|password)(["'\s:=]+)([^,"'\s}]+)/gi, '$1$2redacted');
    return output;
  }
  private contains(values: Array<string>, value: string): boolean {
    for (let index = 0; index < values.length; index += 1) {
      if (values[index] === value) {
        return true;
      }
    }
    return false;
  }

  /**
   * 复制Bundle 值，避免外部修改内部状态。
   */
  private copyBundle(bundle: DiagnosticBundle): DiagnosticBundle {
    const records = new Array<DiagnosticRecord>();
    for (let index = 0; index < bundle.records.length; index += 1) {
      records.push(this.copyRecord(bundle.records[index]));
    }
    return {
      id: bundle.id,
      name: bundle.name,
      path: bundle.path,
      records: records,
      createdAt: bundle.createdAt,
    };
  }

  /**
   * 复制Record 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
  private copyRecord(record: DiagnosticRecord): DiagnosticRecord {
    return {
      id: record.id,
      kind: record.kind,
      subjectId: record.subjectId,
      label: record.label,
      status: record.status,
      message: record.message,
      createdAt: record.createdAt,
    };
  }
}
