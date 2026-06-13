import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  PromptTemplateRuntime,
  type PromptTemplateDerivation,
  type PromptTemplateRenderedPayload,
  type RuntimeEvent,
} from '../../Index';

export default function promptTemplateUnitTest() {
  describe('prompt template runtime', () => {
    it('derives known chat template hashes into context and instruct templates', 0, () => {
      const runtime = new PromptTemplateRuntime(new EventBus());

      const result: PromptTemplateDerivation = runtime.deriveTemplatesFromChatTemplate(
        'ignored body',
        'e10ca381b1ccc5cf9db52e371f3b6651576caee0a630b452e2816b2d404d4b65',
      );

      expect(result.context).assertEqual('Llama 3 Instruct');
      expect(result.instruct).assertEqual('Llama 3 Instruct');
    });

    it('returns no derivation for empty or unknown templates', 0, () => {
      const runtime = new PromptTemplateRuntime(new EventBus());

      const empty = runtime.deriveTemplatesFromChatTemplate('   ', '');
      const unknown = runtime.deriveTemplatesFromChatTemplate('plain template', 'unknown-hash');

      expect(empty.context === null).assertTrue();
      expect(empty.instruct === null).assertTrue();
      expect(unknown.context === null).assertTrue();
      expect(unknown.instruct === null).assertTrue();
    });

    it('does not expose known hash derivation records', 0, () => {
      const runtime = new PromptTemplateRuntime(new EventBus());
      const hash = 'e10ca381b1ccc5cf9db52e371f3b6651576caee0a630b452e2816b2d404d4b65';

      const first = runtime.deriveTemplatesFromChatTemplate('ignored body', hash);
      first.context = 'mutated';
      first.instruct = 'mutated';
      const second = runtime.deriveTemplatesFromChatTemplate('ignored body', hash);

      expect(second.context).assertEqual('Llama 3 Instruct');
      expect(second.instruct).assertEqual('Llama 3 Instruct');
    });

    it('derives templates from ChatML and Harmony template tokens', 0, () => {
      const runtime = new PromptTemplateRuntime(new EventBus());
      const chatMl = '<|im_start|>user\n{{message}}<|im_end|>\n<|im_start|>assistant';
      const harmony = '<|start|>user<|message|>{{message}}<|end|><|start|>assistant<|channel|>final<|message|>';

      const chatMlResult = runtime.deriveTemplatesFromChatTemplate(chatMl, '');
      const harmonyResult = runtime.deriveTemplatesFromChatTemplate(harmony, '');

      expect(chatMlResult.context).assertEqual('ChatML');
      expect(chatMlResult.instruct).assertEqual('ChatML');
      expect(harmonyResult.context).assertEqual('OpenAI Harmony');
      expect(harmonyResult.instruct).assertEqual('OpenAI Harmony');
    });

    it('registers, renders, and lists simple headless templates', 0, () => {
      const bus = new EventBus();
      const runtime = new PromptTemplateRuntime(bus);
      const rendered = new Array<string>();
      bus.subscribe<PromptTemplateRenderedPayload>('promptTemplate.rendered', (event: RuntimeEvent<PromptTemplateRenderedPayload>) => {
        rendered.push(`${event.payload.templateId}:${event.payload.output}`);
      });

      runtime.registerTemplate({ id: 'greeting', content: 'Hello {{name}} from {{place}}.' });
      const data = new Map<string, string>();
      data.set('name', 'Alice');
      data.set('place', 'Deck');
      const output = runtime.renderTemplate('greeting', data);
      const ids = runtime.listTemplateIds();

      expect(output).assertEqual('Hello Alice from Deck.');
      expect(ids.length).assertEqual(1);
      expect(ids[0]).assertEqual('greeting');
      expect(rendered.length).assertEqual(1);
      expect(rendered[0]).assertEqual('greeting:Hello Alice from Deck.');
    });
  });
}
