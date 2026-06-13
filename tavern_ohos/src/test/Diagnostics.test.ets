import { describe, it, expect } from '@ohos/hypium';
import {
  DiagnosticsRuntime,
  EventBus,
  type DiagnosticBundle,
  type DiagnosticRecord,
  type DiagnosticsBundleCreatedPayload,
  type DiagnosticsRecordCreatedPayload,
  type RuntimeEvent,
} from '../../Index';

export default function diagnosticsUnitTest() {
  describe('diagnostics runtime', () => {
    it('records prompt, event, plugin, command, script, tool, and stream traces', 0, () => {
      const bus = new EventBus();
      const runtime = new DiagnosticsRuntime(bus);
      const recorded = new Array<string>();
      bus.subscribe<DiagnosticsRecordCreatedPayload>('diagnostics.record.created', (event: RuntimeEvent<DiagnosticsRecordCreatedPayload>) => {
        recorded.push(event.payload.record.kind);
      });

      runtime.recordPromptTrace('prompt-a', 'built prompt', 'ok');
      runtime.recordEventTrace('event-a', 'chat.loaded', 'ok');
      runtime.recordPluginTrace('plugin-a', 'beforeSend', 'error');
      runtime.recordCommandTrace('command-a', '/send', 'ok');
      runtime.recordScriptTrace('script-a', 'qr script', 'ok');
      runtime.recordToolCallTrace('tool-a', 'weather', 'ok');
      runtime.recordStreamTrace('stream-a', 'delta received', 'ok');
      const all = runtime.listRecords();
      const plugin = runtime.listByKind('plugin');

      expect(all.length).assertEqual(7);
      expect(recorded.length).assertEqual(7);
      expect(plugin.length).assertEqual(1);
      expect(plugin[0].subjectId).assertEqual('plugin-a');
      expect(plugin[0].status).assertEqual('error');
    });

    it('creates diagnostic bundles and emits bundle events', 0, () => {
      const bus = new EventBus();
      const runtime = new DiagnosticsRuntime(bus);
      const bundleIds = new Array<string>();
      bus.subscribe<DiagnosticsBundleCreatedPayload>('diagnostics.bundle.created', (event: RuntimeEvent<DiagnosticsBundleCreatedPayload>) => {
        bundleIds.push(event.payload.bundle.id);
      });

      runtime.recordPromptTrace('prompt-a', 'one', 'ok');
      runtime.recordPromptTrace('prompt-b', 'two', 'ok');
      runtime.recordToolCallTrace('tool-a', 'called', 'error');
      const bundle: DiagnosticBundle = runtime.createBundle('debug-export', ['prompt'], 'diagnostics/debug.json');

      expect(bundle.id).assertEqual('diagnostic-bundle-1');
      expect(bundle.name).assertEqual('debug-export');
      expect(bundle.path).assertEqual('diagnostics/debug.json');
      expect(bundle.records.length).assertEqual(2);
      expect(bundleIds.length).assertEqual(1);
      expect(bundleIds[0]).assertEqual('diagnostic-bundle-1');
    });

    it('reports health summary from recorded diagnostics', 0, () => {
      const runtime = new DiagnosticsRuntime(new EventBus());
      runtime.recordPromptTrace('prompt-a', 'ok', 'ok');
      runtime.recordPluginTrace('plugin-a', 'failed hook', 'error');
      runtime.recordStreamTrace('stream-a', 'warning', 'warning');
      const summary = runtime.getHealthSummary();
      const recentErrors: Array<DiagnosticRecord> = runtime.listErrors();

      expect(summary.totalRecords).assertEqual(3);
      expect(summary.errorCount).assertEqual(1);
      expect(summary.warningCount).assertEqual(1);
      expect(summary.status).assertEqual('degraded');
      expect(recentErrors.length).assertEqual(1);
      expect(recentErrors[0].kind).assertEqual('plugin');
    });

    it('redacts sensitive values from diagnostic records and bundles', 0, () => {
      const bus = new EventBus();
      const runtime = new DiagnosticsRuntime(bus);
      const messages = new Array<string>();
      bus.subscribe<DiagnosticsRecordCreatedPayload>('diagnostics.record.created', (event: RuntimeEvent<DiagnosticsRecordCreatedPayload>) => {
        messages.push(event.payload.record.message);
      });

      const record = runtime.recordStreamTrace('provider', 'Authorization: Bearer abcdef123456 token=secret-token api_key=sk-1234567890', 'error');
      const bundle = runtime.createBundle('redacted', new Array<string>(), 'diagnostics/redacted.json');

      expect(record.message.indexOf('abcdef123456') < 0).assertTrue();
      expect(record.message.indexOf('secret-token') < 0).assertTrue();
      expect(record.message.indexOf('sk-1234567890') < 0).assertTrue();
      expect(messages[0]).assertEqual(record.message);
      expect(bundle.records[0].message).assertEqual(record.message);
    });
  });
}
