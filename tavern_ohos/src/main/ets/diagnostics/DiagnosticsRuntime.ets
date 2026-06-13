import { EventBus } from '../runtime/EventBus';
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
   * 记录副本列表，由当前实例内部维护。
   */
  private records: Array<DiagnosticRecord> = new Array<DiagnosticRecord>();
  /**
   * bundles 列表，由当前实例内部维护。
   */
  private bundles: Array<DiagnosticBundle> = new Array<DiagnosticBundle>();
  /**
   * record Counter 值，由当前实例内部维护。
   */
  private recordCounter: number = 0;
  /**
   * bundle Counter 值，由当前实例内部维护。
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
   * 创建或写入提示词Trace，完成持久化后返回可供调用方使用的结果。
   * @param subjectId 目标主体标识。
   * @param message 消息记录。
   * @param status 状态值。
   */
  recordPromptTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('prompt', subjectId, 'PromptInspector', message, status);
  }

  /**
   * 创建或写入事件Trace，完成持久化后返回可供调用方使用的结果。
   * @param subjectId 目标主体标识。
   * @param message 消息记录。
   * @param status 状态值。
   */
  recordEventTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('event', subjectId, 'EventInspector', message, status);
  }

  /**
   * 创建或写入PluginTrace，完成持久化后返回可供调用方使用的结果。
   * @param subjectId 目标主体标识。
   * @param message 消息记录。
   * @param status 状态值。
   */
  recordPluginTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('plugin', subjectId, 'PluginInspector', message, status);
  }

  /**
   * 创建或写入CommandTrace，完成持久化后返回可供调用方使用的结果。
   * @param subjectId 目标主体标识。
   * @param message 消息记录。
   * @param status 状态值。
   */
  recordCommandTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('command', subjectId, 'CommandDebugger', message, status);
  }

  /**
   * 创建或写入ScriptTrace，完成持久化后返回可供调用方使用的结果。
   * @param subjectId 目标主体标识。
   * @param message 消息记录。
   * @param status 状态值。
   */
  recordScriptTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('script', subjectId, 'ScriptTrace', message, status);
  }

  /**
   * 创建或写入ToolCallTrace，完成持久化后返回可供调用方使用的结果。
   * @param subjectId 目标主体标识。
   * @param message 消息记录。
   * @param status 状态值。
   */
  recordToolCallTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('tool', subjectId, 'ToolCallTrace', message, status);
  }

  /**
   * 创建或写入流式任务Trace，完成持久化后返回可供调用方使用的结果。
   * @param subjectId 目标主体标识。
   * @param message 消息记录。
   * @param status 状态值。
   */
  recordStreamTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('stream', subjectId, 'StreamTrace', message, status);
  }

  /**
   * 读取Records列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listRecords(): Array<DiagnosticRecord> {
    const result = new Array<DiagnosticRecord>();
    for (let index = 0; index < this.records.length; index += 1) {
      result.push(this.copyRecord(this.records[index]));
    }
    return result;
  }

  /**
   * 读取ByKind列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param kind 记录类型。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listByKind(kind: string): Array<DiagnosticRecord> {
    const result = new Array<DiagnosticRecord>();
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].kind === kind) {
        result.push(this.copyRecord(this.records[index]));
      }
    }
    return result;
  }

  /**
   * 读取Errors列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 创建新的诊断包记录，写入存储并返回副本。
   * @param name 显示名称或注册名称。

   * @param path 目标文件或目录路径。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 读取Bundles列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listBundles(): Array<DiagnosticBundle> {
    const result = new Array<DiagnosticBundle>();
    for (let index = 0; index < this.bundles.length; index += 1) {
      result.push(this.copyBundle(this.bundles[index]));
    }
    return result;
  }

  /**
   * 读取指定HealthSummary，不存在时抛出错误。
   * @returns 更新或读取后的记录副本。
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
  private record(kind: string, subjectId: string, label: string, message: string, status: string): DiagnosticRecord {
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
