import { EventBus } from '../runtime/EventBus';
import type {
  DiagnosticBundle,
  DiagnosticHealthSummary,
  DiagnosticRecord,
  DiagnosticsBundleCreatedPayload,
  DiagnosticsRecordCreatedPayload,
} from './DiagnosticsModels';

export class DiagnosticsRuntime {
  private events: EventBus;
  private records: Array<DiagnosticRecord> = new Array<DiagnosticRecord>();
  private bundles: Array<DiagnosticBundle> = new Array<DiagnosticBundle>();
  private recordCounter: number = 0;
  private bundleCounter: number = 0;

  constructor(events: EventBus) {
    this.events = events;
  }

  recordPromptTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('prompt', subjectId, 'PromptInspector', message, status);
  }

  recordEventTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('event', subjectId, 'EventInspector', message, status);
  }

  recordPluginTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('plugin', subjectId, 'PluginInspector', message, status);
  }

  recordCommandTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('command', subjectId, 'CommandDebugger', message, status);
  }

  recordScriptTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('script', subjectId, 'ScriptTrace', message, status);
  }

  recordToolCallTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('tool', subjectId, 'ToolCallTrace', message, status);
  }

  recordStreamTrace(subjectId: string, message: string, status: string): DiagnosticRecord {
    return this.record('stream', subjectId, 'StreamTrace', message, status);
  }

  listRecords(): Array<DiagnosticRecord> {
    const result = new Array<DiagnosticRecord>();
    for (let index = 0; index < this.records.length; index += 1) {
      result.push(this.copyRecord(this.records[index]));
    }
    return result;
  }

  listByKind(kind: string): Array<DiagnosticRecord> {
    const result = new Array<DiagnosticRecord>();
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].kind === kind) {
        result.push(this.copyRecord(this.records[index]));
      }
    }
    return result;
  }

  listErrors(): Array<DiagnosticRecord> {
    const result = new Array<DiagnosticRecord>();
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].status === 'error') {
        result.push(this.copyRecord(this.records[index]));
      }
    }
    return result;
  }

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

  listBundles(): Array<DiagnosticBundle> {
    const result = new Array<DiagnosticBundle>();
    for (let index = 0; index < this.bundles.length; index += 1) {
      result.push(this.copyBundle(this.bundles[index]));
    }
    return result;
  }

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
