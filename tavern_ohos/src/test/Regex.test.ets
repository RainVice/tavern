import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  RegexRuntime,
  type RegexAppliedPayload,
  type RegexApplyInput,
  type RegexApplyResult,
  type RegexScriptRecord,
  type RuntimeEvent,
} from '../../Index';

export default function regexUnitTest() {
  describe('regex runtime', () => {
    it('applies placement-matched scripts and emits debug traces', 0, () => {
      const bus = new EventBus();
      const runtime = new RegexRuntime(bus);
      const applied = new Array<string>();
      bus.subscribe<RegexAppliedPayload>('regex.applied', (event: RuntimeEvent<RegexAppliedPayload>) => {
        applied.push(event.payload.trace.scriptId);
      });
      runtime.registerScript(makeScript('rx-1', 'global', 'ai_output', 'secret:(\\w+)', '[redacted:$1]', false));
      const input: RegexApplyInput = {
        text: 'hello secret:token',
        placement: 'ai_output',
        isMarkdown: false,
        isPrompt: false,
        isEdit: false,
        depth: 0,
        scopeId: '',
      };

      const result: RegexApplyResult = runtime.applyScripts(input);

      expect(result.text).assertEqual('hello [redacted:token]');
      expect(result.traces.length).assertEqual(1);
      expect(result.traces[0].before).assertEqual('hello secret:token');
      expect(result.traces[0].after).assertEqual('hello [redacted:token]');
      expect(applied.length).assertEqual(1);
      expect(applied[0]).assertEqual('rx-1');
    });

    it('respects prompt mode, edit mode, and depth filters', 0, () => {
      const bus = new EventBus();
      const runtime = new RegexRuntime(bus);
      const script = makeScript('rx-2', 'global', 'prompt', 'dragon', 'wyrm', false);
      script.promptOnly = true;
      script.runOnEdit = false;
      script.minDepth = 1;
      script.maxDepth = 2;
      runtime.registerScript(script);

      const skippedPrompt = runtime.applyScripts(makeInput('dragon', 'prompt', false, false, false, 1, ''));
      const skippedEdit = runtime.applyScripts(makeInput('dragon', 'prompt', false, true, true, 1, ''));
      const skippedDepth = runtime.applyScripts(makeInput('dragon', 'prompt', false, true, false, 3, ''));
      const applied = runtime.applyScripts(makeInput('dragon', 'prompt', false, true, false, 2, ''));

      expect(skippedPrompt.text).assertEqual('dragon');
      expect(skippedEdit.text).assertEqual('dragon');
      expect(skippedDepth.text).assertEqual('dragon');
      expect(applied.text).assertEqual('wyrm');
    });

    it('applies scoped ephemeral scripts and removes them on cleanup', 0, () => {
      const bus = new EventBus();
      const runtime = new RegexRuntime(bus);
      runtime.registerScript(makeScript('rx-3', 'char-1', 'reasoning', 'think', 'consider', true));

      const skipped = runtime.applyScripts(makeInput('think', 'reasoning', false, false, false, 0, 'char-2'));
      const applied = runtime.applyScripts(makeInput('think', 'reasoning', false, false, false, 0, 'char-1'));
      runtime.removeEphemeralScripts();
      const afterCleanup = runtime.applyScripts(makeInput('think', 'reasoning', false, false, false, 0, 'char-1'));

      expect(skipped.text).assertEqual('think');
      expect(applied.text).assertEqual('consider');
      expect(afterCleanup.text).assertEqual('think');
    });

    it('expands match placeholder to the original regex match', 0, () => {
      const runtime = new RegexRuntime(new EventBus());
      runtime.registerScript(makeScript('rx-match', '', 'ai_output', 'secret:\\w+', '<{{match}}>', false));

      const result = runtime.applyScripts(makeInput('hide secret:token now', 'ai_output', false, false, false, 0, ''));

      expect(result.text).assertEqual('hide <secret:token> now');
    });

    it('does not expose internal script records through registration or listing', 0, () => {
      const runtime = new RegexRuntime(new EventBus());
      const script = makeScript('rx-copy', '', 'ai_output', 'cat', 'dog', false);
      const registered = runtime.registerScript(script);
      script.replaceString = 'fox';
      script.placements.push('prompt');
      registered.replaceString = 'bird';

      const listed = runtime.listScripts();
      listed[0].replaceString = 'horse';
      listed[0].placements.push('reasoning');
      const result = runtime.applyScripts(makeInput('cat', 'ai_output', false, false, false, 0, ''));

      expect(result.text).assertEqual('dog');
      expect(runtime.listScripts()[0].placements.length).assertEqual(1);
    });
  });
}

function makeScript(
  id: string,
  scopeId: string,
  placement: string,
  findRegex: string,
  replaceString: string,
  ephemeral: boolean,
): RegexScriptRecord {
  return {
    id: id,
    scriptName: id,
    sourceType: scopeId.length > 0 ? 'scoped' : 'global',
    scopeId: scopeId,
    findRegex: findRegex,
    flags: 'g',
    replaceString: replaceString,
    placements: [placement],
    disabled: false,
    markdownOnly: false,
    promptOnly: false,
    runOnEdit: true,
    minDepth: -1,
    maxDepth: -1,
    ephemeral: ephemeral,
    trimStrings: new Array<string>(),
  };
}

function makeInput(
  text: string,
  placement: string,
  isMarkdown: boolean,
  isPrompt: boolean,
  isEdit: boolean,
  depth: number,
  scopeId: string,
): RegexApplyInput {
  return {
    text: text,
    placement: placement,
    isMarkdown: isMarkdown,
    isPrompt: isPrompt,
    isEdit: isEdit,
    depth: depth,
    scopeId: scopeId,
  };
}
