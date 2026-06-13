import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
} from '../../Index';
import {
  SystemPromptRuntime,
  type SystemPromptRecord,
  type SystemPromptState,
} from '../main/ets/systemprompt/Index';

export default function systemPromptUnitTest() {
  describe('system prompt runtime', () => {
    it('loads prompts, selects by exact or fuzzy name, and toggles state', 0, () => {
      const runtime = new SystemPromptRuntime(new EventBus());
      runtime.loadSystemPrompts([
        { name: 'Helpful Assistant', content: 'Be helpful.', postHistory: '' },
        { name: 'Strict JSON', content: 'Return JSON only.', postHistory: 'No markdown.' },
      ]);

      runtime.setEnabled(true);
      const selected: SystemPromptRecord = runtime.selectSystemPrompt('json', false);
      const state: SystemPromptState = runtime.getState();

      expect(selected.name).assertEqual('Strict JSON');
      expect(state.enabled).assertTrue();
      expect(state.name).assertEqual('Strict JSON');
      expect(state.content).assertEqual('Return JSON only.');
      expect(state.postHistory).assertEqual('No markdown.');
      expect(runtime.toggleSystemPrompt('false')).assertEqual('false');
      expect(runtime.selectSystemPrompt('', true).name).assertEqual('Strict JSON');
    });

    it('migrates instruct system prompts into named presets', 0, () => {
      const runtime = new SystemPromptRuntime(new EventBus());
      runtime.loadSystemPrompts([
        { name: 'Existing', content: 'Existing content', postHistory: '' },
      ]);

      const existing: SystemPromptRecord = runtime.migrateFromInstruct('Preset A', true, 'Existing content');
      const created: SystemPromptRecord = runtime.migrateFromInstruct('Preset B', false, 'New content');

      expect(existing.name).assertEqual('Existing');
      expect(created.name).assertEqual('[Migrated] Preset B');
      expect(runtime.listSystemPrompts().length).assertEqual(2);
      expect(runtime.getState().enabled).assertFalse();
      expect(runtime.getState().content).assertEqual('New content');
    });
  });
}
