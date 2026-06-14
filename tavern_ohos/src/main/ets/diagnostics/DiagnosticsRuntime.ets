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
 * 供各业务模块（prompt 检测、事件处理、插件执行、命令执行、脚本执行、工具调用、流式任务等）在关键节点记录诊断追踪信息。
 */
export class DiagnosticsRuntime {
  /** 事件总线，用于发布诊断记录和包创建事件，通知订阅方（如 UI 诊断面板）实时接收诊断信息。 */
  private events: EventBus;
  /** 所有诊断记录的顺序列表，按创建顺序追加，是诊断查询和打包的数据源。 */
  private records: Array<DiagnosticRecord> = new Array<DiagnosticRecord>();
  /** 所有诊断包的顺序列表，按创建顺序追加，记录已打包的诊断集合。 */
  private bundles: Array<DiagnosticBundle> = new Array<DiagnosticBundle>();
  /** 自增计数器，用于生成诊断记录唯一标识（格式 "diagnostic-record-{数字}"）。 */
  private recordCounter: number = 0;
  /** 自增计数器，用于生成诊断包唯一标识（格式 "diagnostic-bundle-{数字}"）。 */
  private bundleCounter: number = 0;

  /**
   * 初始化当前运行时实例。通常在应用启动或诊断模块初始化时调用。
   * @param events 用于发布诊断事件的事件总线实例，供调用方在构造时传入。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 记录一条 prompt 类型的诊断记录，用于 Prompt 注入检测和提示词处理链路的执行追踪。
   * 由 prompt 检测模块或安全过滤流程在分析用户输入和服务端响应时调用。
   * @param subjectId 诊断关联的主体标识，通常是角色 ID 或对话 ID，用于关联同一主体的多条诊断记录。
   * @param message 诊断消息内容，记录检测结果或处理状态。
   * @param status 诊断状态（如 error / warning / info），标识本次检测的严重程度。
   * @returns 创建后的诊断记录深拷贝。
   */
  recordPromptTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('prompt', subjectId, 'PromptInspector', message, status);
  }

  /**
   * 记录一条 event 类型的诊断记录，用于事件处理链路的执行追踪。
   * 由事件总线或事件处理器在派发和处理事件时调用，记录事件处理过程中的关键节点。
   * @param subjectId 诊断关联的主体标识，通常是事件相关的请求 ID。
   * @param message 诊断消息内容，记录事件处理状态。
   * @param status 诊断状态。
   * @returns 创建后的诊断记录深拷贝。
   */
  recordEventTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('event', subjectId, 'EventInspector', message, status);
  }

  /**
   * 记录一条 plugin 类型的诊断记录，用于插件执行链路的追踪。
   * 由插件管理器在加载、初始化和调用插件时调用，记录插件执行过程中的状态变化。
   * @param subjectId 诊断关联的主体标识，通常是插件 ID 或执行会话 ID。
   * @param message 诊断消息内容，记录插件执行步骤或异常信息。
   * @param status 诊断状态。
   * @returns 创建后的诊断记录深拷贝。
   */
  recordPluginTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('plugin', subjectId, 'PluginInspector', message, status);
  }

  /**
   * 记录一条 command 类型的诊断记录，用于命令执行链路的追踪。
   * 由命令处理器在解析和执行用户命令时调用，记录命令执行的关键路径和结果。
   * @param subjectId 诊断关联的主体标识，通常是命令请求 ID。
   * @param message 诊断消息内容，记录命令执行状态。
   * @param status 诊断状态。
   * @returns 创建后的诊断记录深拷贝。
   */
  recordCommandTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('command', subjectId, 'CommandDebugger', message, status);
  }

  /**
   * 记录一条 script 类型的诊断记录，用于脚本执行链路的追踪。
   * 由脚本引擎在执行用户自定义脚本时调用，记录脚本运行过程中的状态信息。
   * @param subjectId 诊断关联的主体标识，通常是脚本 ID 或执行会话 ID。
   * @param message 诊断消息内容，记录脚本执行步骤或输出。
   * @param status 诊断状态。
   * @returns 创建后的诊断记录深拷贝。
   */
  recordScriptTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('script', subjectId, 'ScriptTrace', message, status);
  }

  /**
   * 记录一条 tool 类型的诊断记录，用于工具调用链路的追踪。
   * 由工具调用管理器在调用外部工具 API 时调用，记录工具调用的请求和响应信息。
   * @param subjectId 诊断关联的主体标识，通常是工具调用 ID 或会话 ID。
   * @param message 诊断消息内容，记录工具调用的参数和结果。
   * @param status 诊断状态。
   * @returns 创建后的诊断记录深拷贝。
   */
  recordToolCallTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('tool', subjectId, 'ToolCallTrace', message, status);
  }

  /**
   * 记录一条 stream 类型的诊断记录，用于流式任务链路的追踪。
   * 由流式处理器在接收和处理流式数据时调用，记录流状态的切换和数据吞吐情况。
   * @param subjectId 诊断关联的主体标识，通常是流式会话 ID。
   * @param message 诊断消息内容，记录流处理状态。
   * @param status 诊断状态。
   * @returns 创建后的诊断记录深拷贝。
   */
  recordStreamTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('stream', subjectId, 'StreamTrace', message, status);
  }

  /**
   * 获取所有诊断记录的深拷贝列表。供诊断面板 UI 或外部模块读取完整诊断历史时调用。
   * @returns 全部诊断记录的副本。
   */
  listRecords(): Array<DiagnosticRecord> {
    const result = new Array<DiagnosticRecord>();
    for (let index = 0; index < this.records.length; index += 1) {
      result.push(this.copyRecord(this.records[index]));
    }
    return result;
  }

  /**
   * 按类别筛选诊断记录。供 UI 按诊断类别（prompt / event / plugin 等）过滤展示时调用。
   * @param kind 要匹配的诊断类别，应与创建记录时传入的 kind 一致。
   * @returns 匹配该类别的诊断记录列表深拷贝。
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
   * 获取所有状态为 error 的诊断记录列表。供错误排查流程或 UI 错误列表展示时调用。
   * @returns 错误诊断记录的深拷贝列表。
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
   * 创建一个诊断包，按指定类别筛选记录并打包。供批量导出或分析诊断数据时调用。
   * @param name 包的显示名称，用于 UI 标识和文件命名。
   * @param kinds 要包含的诊断类别列表，为空数组则包含所有类别的记录。
   * @param path 包的保存路径，记录归档位置。
   * @returns 新建诊断包的深拷贝。
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
   * 获取所有诊断包的深拷贝列表。供 UI 诊断包管理界面或批量导出流程调用。
   * @returns 全部诊断包的副本。
   */
  listBundles(): Array<DiagnosticBundle> {
    const result = new Array<DiagnosticBundle>();
    for (let index = 0; index < this.bundles.length; index += 1) {
      result.push(this.copyBundle(this.bundles[index]));
    }
    return result;
  }

  /**
   * 生成诊断健康摘要，包含总记录数、错误数、警告数和整体健康状态。
   * 供系统健康监控面板或运维告警流程调用，用于评估系统整体运行状况。
   * @returns 包含统计信息的健康摘要。
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

  /**
   * 通用诊断记录创建方法：生成标识、脱敏消息、注册记录并发布事件。
   * 被各 record*Trace 方法间接调用，是诊断记录的统一创建入口。
   * @param kind 诊断类别（prompt / event / plugin / command / script / tool / stream）。
   * @param subjectId 关联的主体标识，用于关联同一主体的多条记录。
   * @param label 诊断标签，标明记录来源的检测器名称。
   * @param message 消息内容（会经过敏感信息脱敏处理，移除 Bearer token、API key、secret 等）。
   * @param status 诊断状态（error / warning / info / debug）。
   * @returns 创建后的诊断记录深拷贝。
   */
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

  /**
   * 对消息文本中的敏感信息（Bearer token、API key、secret 等）进行脱敏，防止敏感数据泄露到诊断日志中。
   * 在 record 方法创建每条诊断记录时自动调用。
   * @param message 原始消息文本。
   * @returns 脱敏后的消息文本，敏感信息被替换为 "redacted"。
   */
  private redactSensitiveText(message: string): string {
    let output = message.replace(/Bearer\s+[A-Za-z0-9._~+/=-]+/g, 'Bearer redacted');
    output = output.replace(/sk-[A-Za-z0-9._-]{8,}/g, 'sk-redacted');
    output = output.replace(/(api[_-]?key|secret|token|password)(["'\s:=]+)([^,"'\s}]+)/gi, '$1$2redacted');
    return output;
  }

  /**
   * 判断字符串数组中是否包含指定值。供 createBundle 在筛选诊断类别时内部调用。
   * @param values 要搜索的字符串数组。
   * @param value 要查找的值。
   * @returns 找到时返回 true，否则 false。
   */
  private contains(values: Array<string>, value: string): boolean {
    for (let index = 0; index < values.length; index += 1) {
      if (values[index] === value) {
        return true;
      }
    }
    return false;
  }

  /**
   * 深拷贝诊断包，包含内部记录的深拷贝。所有对外返回 DiagnosticBundle 的方法均通过此方法生成副本。
   * @param bundle 要拷贝的诊断包。
   * @returns 诊断包的深拷贝。
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
   * 深拷贝诊断记录，防止外部修改内部状态。所有对外返回 DiagnosticRecord 的方法均通过此方法生成副本。
   * @param record 要拷贝的诊断记录。
   * @returns 诊断记录的深拷贝。
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
