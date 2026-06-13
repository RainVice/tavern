import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  InstructRuntime,
  INSTRUCT_NAMES_BEHAVIOR_ALWAYS,
  INSTRUCT_NAMES_BEHAVIOR_FORCE,
  INSTRUCT_FORCE_OUTPUT_LAST,
  type InstructPreset,
  type InstructState,
} from '../../Index';

export default function instructUnitTest() {
  describe('instruct runtime', () => {
    it('migrates legacy fields, selects presets, and emits state changes', 0, () => {
      const runtime = new InstructRuntime(new EventBus());
      runtime.loadPresets([
        {
          name: 'Legacy Alpaca',
          enabled: false,
          preset: '',
          input_sequence: '### Instruction:',
          output_sequence: '### Response:',
          separator_sequence: '<END>',
          names: true,
          names_force_groups: false,
          wrap: true,
          macro: true,
        },
      ]);

      const selected: InstructPreset = runtime.selectPreset('legacy', false);
      const state: InstructState = runtime.getState();

      expect(selected.name).assertEqual('Legacy Alpaca');
      expect(selected.output_suffix).assertEqual('<END>');
      expect(selected.names_behavior).assertEqual(INSTRUCT_NAMES_BEHAVIOR_ALWAYS);
      expect(state.enabled).assertTrue();
      expect(state.preset).assertEqual('Legacy Alpaca');
    });

    it('auto-selects model mappings, regex presets, and context-bound presets', 0, () => {
      const runtime = new InstructRuntime(new EventBus());
      runtime.loadPresets([
        { name: 'ChatML', enabled: false, preset: '', activation_regex: '/chatml/i', input_sequence: '<|im_start|>user', output_sequence: '<|im_start|>assistant' },
        { name: 'Context Twin', enabled: false, preset: '', input_sequence: '[INST]', output_sequence: '[/INST]' },
      ]);
      runtime.setModelTemplateMapping('provider-model', 'Mapped Instruct', 'Mapped Context');

      const mapped = runtime.autoSelectPreset('provider-model', 'Other Context');
      const regex = runtime.autoSelectPreset('my-chatml-model', 'Other Context');
      runtime.updateState({ enabled: true, bind_to_context: true, preset: '' });
      const bound = runtime.autoSelectPreset('unknown-model', 'Context Twin');

      expect(mapped).assertTrue();
      expect(runtime.getState().preset).assertEqual('Mapped Instruct');
      expect(runtime.getContextPreset()).assertEqual('Mapped Context');
      expect(regex).assertTrue();
      expect(runtime.getState().preset).assertEqual('ChatML');
      expect(bound).assertTrue();
      expect(runtime.getState().preset).assertEqual('Context Twin');
    });

    it('ignores invalid activation regex while auto-selecting presets', 0, () => {
      const runtime = new InstructRuntime(new EventBus());
      runtime.loadPresets([
        { name: 'Broken', enabled: false, preset: '', activation_regex: '/[broken/', input_sequence: 'bad', output_sequence: 'bad' },
        { name: 'Working', enabled: false, preset: '', activation_regex: '/working/i', input_sequence: 'ok', output_sequence: 'ok' },
      ]);

      const selected = runtime.autoSelectPreset('my-working-model', '');

      expect(selected).assertTrue();
      expect(runtime.getState().preset).assertEqual('Working');
    });

    it('builds stop strings from instruct sequences and context stop strings', 0, () => {
      const runtime = new InstructRuntime(new EventBus());
      runtime.updateState({
        enabled: true,
        wrap: true,
        macro: true,
        stop_sequence: 'STOP\n\n',
        input_sequence: 'User {{name}}:',
        output_sequence: 'Assistant {{name}}:',
        sequences_as_stop_strings: true,
      });
      runtime.updateContext({ chat_start: '<START>', example_separator: '<EXAMPLE>', use_stop_strings: true });

      const stops = runtime.getStoppingSequences('Alice', 'Bob', true);

      expect(stops.length).assertEqual(5);
      expect(stops[0]).assertEqual('\nSTOP');
      expect(stops[1]).assertEqual('\nUser Alice:');
      expect(stops[2]).assertEqual('\nAssistant Bob:');
      expect(stops[3]).assertEqual('\n<START>');
      expect(stops[4]).assertEqual('\n<EXAMPLE>');
    });

    it('formats chat messages, story strings, and final prompt lines', 0, () => {
      const runtime = new InstructRuntime(new EventBus());
      runtime.updateState({
        enabled: true,
        wrap: true,
        macro: true,
        names_behavior: INSTRUCT_NAMES_BEHAVIOR_FORCE,
        input_sequence: '### {{name1}}:',
        output_sequence: '### {{name2}}:',
        last_output_sequence: '### Final {{name}}:',
        story_string_prefix: '<SYS {{name}}>',
        story_string_suffix: '</SYS>',
      });

      const userText = runtime.formatChatMessage('Alice', 'Hello', true, false, '', 'Alice', 'Bob', 0);
      const groupText = runtime.formatChatMessage('Carol', 'Hi', false, false, 'carol.png', 'Alice', 'Bob', 0);
      const story = runtime.formatStoryString('The scene opens.', false);
      const prompt = runtime.formatPromptLine('Bob', false, ' continue', 'Alice', 'Bob', false, false, INSTRUCT_FORCE_OUTPUT_LAST);

      expect(userText).assertEqual('### Alice:\nHello\n');
      expect(groupText).assertEqual('### Bob:\nCarol: Hi\n');
      expect(story).assertEqual('<SYS System>\nThe scene opens.</SYS>');
      expect(prompt).assertEqual('\n### Final Bob:\nBob: continue');
    });
  });
}
