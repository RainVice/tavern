import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  TokenizerRuntime,
  type TokenBudgetPayload,
  type RuntimeEvent,
  type TokenBudgetResult,
  type TokenCountResult,
  type TokenMessage,
  type TokenizerCountedPayload,
  type TokenizerProfile,
} from '../../Index';

export default function tokenizerUnitTest() {
  describe('tokenizer runtime', () => {
    it('registers tokenizer profiles and caches deterministic token counts', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TokenizerRuntime(bus);
      const counts = new Array<TokenCountResult>();
      bus.subscribe<TokenizerCountedPayload>('tokenizer.counted', (event: RuntimeEvent<TokenizerCountedPayload>) => {
        counts.push(event.payload.result);
      });
      const profile: TokenizerProfile = runtime.registerProfile({
        id: 'openai-cl100k',
        name: 'OpenAI cl100k compatible',
        strategy: 'word',
        bytesPerToken: 3.35,
        maxContext: 8192,
      });
      const first = runtime.countText('openai-cl100k', 'Hello world\nagain');
      const second = runtime.countText('openai-cl100k', 'Hello world\nagain');

      expect(profile.id).assertEqual('openai-cl100k');
      expect(first.tokens).assertEqual(3);
      expect(first.fromCache).assertFalse();
      expect(second.tokens).assertEqual(3);
      expect(second.fromCache).assertTrue();
      expect(counts.length).assertEqual(2);
    });

    it('重注册 profile 后清理旧计数缓存并隔离返回对象', 0, () => {
      // 运行时实例。
      const runtime = new TokenizerRuntime(new EventBus());
      runtime.registerProfile({
        id: 'mutable',
        name: 'Mutable tokenizer',
        strategy: 'bytes',
        bytesPerToken: 3,
        maxContext: 100,
      });
      const first = runtime.countText('mutable', 'abcdef');
      const listed = runtime.listProfiles();
      for (let index = 0; index < listed.length; index += 1) {
        if (listed[index].id === 'mutable') {
          listed[index].bytesPerToken = 1;
        }
      }
      runtime.registerProfile({
        id: 'mutable',
        name: 'Mutable tokenizer',
        strategy: 'bytes',
        bytesPerToken: 1,
        maxContext: 100,
      });
      const second = runtime.countText('mutable', 'abcdef');
      const profile = runtime.getProfile('mutable');

      expect(first.tokens).assertEqual(2);
      expect(second.tokens).assertEqual(6);
      expect(second.fromCache).assertFalse();
      expect(profile.bytesPerToken).assertEqual(1);
    });

    it('provides built-in tokenizer profiles for common upstream resources', 0, () => {
      // 运行时实例。
      const runtime = new TokenizerRuntime(new EventBus());
      const claude = runtime.getProfile('claude-3-5-sonnet');
      const llama2 = runtime.getProfile('llama');
      const llama = runtime.getProfile('llama-3');
      const mistral = runtime.getProfile('mistral-large');
      const gemma = runtime.getProfile('gemma-2');
      const profileIds = runtime.listProfiles().map((profile: TokenizerProfile) => profile.id);

      expect(claude.id).assertEqual('claude');
      expect(llama2.id).assertEqual('llama');
      expect(llama.id).assertEqual('llama3');
      expect(mistral.id).assertEqual('mistral');
      expect(gemma.id).assertEqual('gemma');
      expect(profileIds.indexOf('claude') >= 0).assertTrue();
      expect(profileIds.indexOf('llama') >= 0).assertTrue();
      expect(profileIds.indexOf('llama3') >= 0).assertTrue();
      expect(profileIds.indexOf('mistral') >= 0).assertTrue();
      expect(profileIds.indexOf('gemma') >= 0).assertTrue();
      expect(profileIds.indexOf('nerdstash') >= 0).assertTrue();
    });

    it('exposes tokenizer options and best-match model selection', 0, () => {
      // 运行时实例。
      const runtime = new TokenizerRuntime(new EventBus());
      const options = runtime.listTokenizerOptions();
      const claude = runtime.selectBestTokenizer({
        api: 'openai',
        provider: 'claude',
        model: 'claude-3-5-sonnet',
      });
      const qwen = runtime.selectBestTokenizer({
        api: 'textgenerationwebui',
        model: 'qwen2.5-72b-instruct',
      });
      const fallback = runtime.selectBestTokenizer({
        api: 'kobold',
        model: 'unknown-model',
      });
      const counted = runtime.countTextForSelection({
        api: 'textgenerationwebui',
        model: 'deepseek-r1',
      }, 'hello world', 4);

      expect(options.length >= 12).assertTrue();
      expect(claude.profileId).assertEqual('claude');
      expect(qwen.profileId).assertEqual('qwen2');
      expect(fallback.profileId).assertEqual('llama');
      expect(counted.profileId).assertEqual('deepseek');
      expect(counted.tokens >= 5).assertTrue();
    });

    it('counts chat message arrays with per-message overhead and model binding', 0, () => {
      // 运行时实例。
      const runtime = new TokenizerRuntime(new EventBus());
      runtime.registerProfile({
        id: 'gpt-compatible',
        name: 'GPT compatible',
        strategy: 'word',
        bytesPerToken: 3.35,
        maxContext: 16,
        messageOverhead: 2,
      });
      runtime.bindModel('gpt-4.1-mini', 'gpt-compatible');
      const count = runtime.countMessages('gpt-4.1-mini', [
        { role: 'system', content: 'Follow rules' },
        { role: 'user', content: 'Say hello now' },
      ]);

      expect(count.profileId).assertEqual('gpt-compatible');
      expect(count.tokens).assertEqual(9);
      expect(count.parts.length).assertEqual(2);
      expect(count.parts[0].tokens).assertEqual(4);
      expect(count.parts[1].tokens).assertEqual(5);
    });

    it('builds budget reports and trims oldest messages to fit context', 0, () => {
      // 运行时实例。
      const runtime = new TokenizerRuntime(new EventBus());
      runtime.registerProfile({
        id: 'budget',
        name: 'Budget tokenizer',
        strategy: 'word',
        bytesPerToken: 3.35,
        maxContext: 10,
        messageOverhead: 1,
      });
      const budget: TokenBudgetResult = runtime.buildBudget('budget', [
        { role: 'system', content: 'system prompt' },
        { role: 'user', content: 'first user message' },
        { role: 'assistant', content: 'assistant answer' },
        { role: 'user', content: 'latest request' },
      ], 3);
      const trimmed = runtime.trimMessagesToBudget('budget', budget.messages, 3);

      expect(budget.maxContext).assertEqual(10);
      expect(budget.completionReserve).assertEqual(3);
      expect(budget.availablePromptTokens).assertEqual(7);
      expect(budget.fits).assertFalse();
      expect(trimmed.removedCount).assertEqual(2);
      expect(trimmed.messages.length).assertEqual(2);
      expect(trimmed.result.fits).assertTrue();
      expect(trimmed.messages[0].role).assertEqual('system');
    });

    it('does not let tokenizer event handlers mutate returned results', 0, () => {
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new TokenizerRuntime(bus);
      bus.subscribe<TokenizerCountedPayload>('tokenizer.counted', (event: RuntimeEvent<TokenizerCountedPayload>) => {
        event.payload.result.tokens = 999;
      });
      bus.subscribe<TokenBudgetPayload>('tokenizer.budget.built', (event: RuntimeEvent<TokenBudgetPayload>) => {
        event.payload.result.messages[0].content = 'event-mutated';
        event.payload.result.promptTokens = 999;
      });
      runtime.registerProfile({
        id: 'copy-budget',
        name: 'Copy budget',
        strategy: 'word',
        bytesPerToken: 3.35,
        maxContext: 20,
        messageOverhead: 0,
      });
      const messages: Array<TokenMessage> = [{ role: 'user', content: 'hello world' }];
      const count = runtime.countText('copy-budget', 'hello world');
      const budget = runtime.buildBudget('copy-budget', messages, 2);

      expect(count.tokens).assertEqual(2);
      expect(budget.promptTokens).assertEqual(2);
      expect(budget.messages[0].content).assertEqual('hello world');
    });
  });
}
