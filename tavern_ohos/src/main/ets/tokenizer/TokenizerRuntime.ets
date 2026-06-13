import { EventBus } from '../runtime/EventBus';
import type {
  TokenBudgetPayload,
  TokenBudgetResult,
  TokenCountResult,
  TokenizerCountedPayload,
  TokenizerOption,
  TokenizerProfile,
  TokenizerProfileCreateParams,
  TokenizerProfilePayload,
  TokenizerSelectionInput,
  TokenizerSelectionResult,
  TokenMessage,
  TokenMessageCountResult,
  TokenMessagePart,
  TokenTrimResult,
} from './TokenizerModels';

export class TokenizerRuntime {
  private events: EventBus;
  private profiles: Map<string, TokenizerProfile> = new Map<string, TokenizerProfile>();
  private modelBindings: Map<string, string> = new Map<string, string>();
  private countCache: Map<string, number> = new Map<string, number>();

  constructor(events: EventBus) {
    this.events = events;
    this.registerDefaultProfiles();
  }

  registerProfile(params: TokenizerProfileCreateParams): TokenizerProfile {
    const now = Date.now();
    const existing = this.profiles.get(params.id);
    const profile: TokenizerProfile = {
      id: params.id,
      name: params.name,
      strategy: params.strategy,
      bytesPerToken: params.bytesPerToken,
      maxContext: params.maxContext,
      messageOverhead: params.messageOverhead === undefined ? 0 : params.messageOverhead,
      createdAt: existing === undefined ? now : existing.createdAt,
      updatedAt: now,
    };
    this.profiles.set(profile.id, this.copyProfile(profile));
    this.clearCache();
    const payload: TokenizerProfilePayload = {
      profile: this.copyProfile(profile),
    };
    this.events.publish<TokenizerProfilePayload>('tokenizer.profile.registered', payload);
    return this.copyProfile(profile);
  }

  bindModel(modelId: string, profileId: string): void {
    this.requireProfile(profileId);
    this.modelBindings.set(modelId, profileId);
  }

  getProfile(profileIdOrModelId: string): TokenizerProfile {
    return this.copyProfile(this.requireProfile(this.resolveProfileId(profileIdOrModelId)));
  }

  listProfiles(): Array<TokenizerProfile> {
    const result = new Array<TokenizerProfile>();
    const values = Array.from(this.profiles.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyProfile(values[index]));
    }
    result.sort((left: TokenizerProfile, right: TokenizerProfile) => left.id.localeCompare(right.id));
    return result;
  }

  listTokenizerOptions(): Array<TokenizerOption> {
    return [
      this.createTokenizerOption(0, 'none', 'Best-effort byte estimate', 'openai-cl100k', false, false),
      this.createTokenizerOption(1, 'gpt2', 'GPT-2 compatible', 'gpt2', false, false),
      this.createTokenizerOption(2, 'openai', 'OpenAI compatible', 'openai-cl100k', false, false),
      this.createTokenizerOption(3, 'llama', 'Llama compatible', 'llama', true, false),
      this.createTokenizerOption(4, 'nerd', 'Nerdstash compatible', 'nerdstash', false, false),
      this.createTokenizerOption(5, 'nerd2', 'Nerdstash v2 compatible', 'nerdstash_v2', false, false),
      this.createTokenizerOption(6, 'api-current', 'Current API tokenizer', 'llama', false, true),
      this.createTokenizerOption(7, 'mistral', 'Mistral compatible', 'mistral', true, false),
      this.createTokenizerOption(8, 'yi', 'Yi compatible', 'yi', true, false),
      this.createTokenizerOption(9, 'api-textgenerationwebui', 'Text Generation WebUI API tokenizer', 'llama', false, true),
      this.createTokenizerOption(10, 'api-kobold', 'Kobold API tokenizer', 'llama', false, true),
      this.createTokenizerOption(11, 'claude', 'Claude compatible', 'claude', true, false),
      this.createTokenizerOption(12, 'llama3', 'Llama 3 compatible', 'llama3', true, false),
      this.createTokenizerOption(13, 'gemma', 'Gemma compatible', 'gemma', true, false),
      this.createTokenizerOption(14, 'jamba', 'Jamba compatible', 'jamba', true, false),
      this.createTokenizerOption(15, 'qwen2', 'Qwen 2 compatible', 'qwen2', true, false),
      this.createTokenizerOption(16, 'command-r', 'Command R compatible', 'command-r', true, false),
      this.createTokenizerOption(17, 'nemo', 'Mistral Nemo compatible', 'nemo', true, false),
      this.createTokenizerOption(18, 'deepseek', 'DeepSeek compatible', 'deepseek', true, false),
      this.createTokenizerOption(19, 'command-a', 'Command A compatible', 'command-a', true, false),
      this.createTokenizerOption(99, 'best-match', 'Best match', 'llama', false, false),
    ];
  }

  selectBestTokenizer(input: TokenizerSelectionInput): TokenizerSelectionResult {
    const api = this.normalize(input.api);
    const provider = this.normalize(input.provider === undefined ? '' : input.provider);
    const model = this.normalize(input.model === undefined ? '' : input.model);
    let profileId = this.resolveProfileIdFromText(`${provider} ${model}`);
    let reason = 'model';
    let remote = false;

    if (profileId.length === 0) {
      if ((api === 'kobold' || api === 'koboldhorde') && input.remoteTokenizerSupported === true && input.tokenizerWarningShown !== true) {
        profileId = 'llama';
        reason = 'remote-kobold';
        remote = true;
      } else if (api === 'textgenerationwebui' && input.remoteTokenizerSupported === true && input.tokenizerWarningShown !== true) {
        profileId = 'llama';
        reason = 'remote-textgenerationwebui';
        remote = true;
      } else if (api === 'novel' && model.indexOf('clio') >= 0) {
        profileId = 'nerdstash';
        reason = 'novel-clio';
      } else if (api === 'novel' && model.indexOf('kayra') >= 0) {
        profileId = 'nerdstash_v2';
        reason = 'novel-kayra';
      } else if (api === 'openai') {
        profileId = 'openai-cl100k';
        reason = 'openai-default';
      } else {
        profileId = 'llama';
        reason = 'fallback';
      }
    }

    const option = this.findTokenizerOption(profileId, remote);
    return {
      option: option,
      profileId: profileId,
      tokenizerKey: option.key,
      remote: remote,
      reason: reason,
    };
  }

  countTextForSelection(input: TokenizerSelectionInput, text: string, padding: number = 0): TokenCountResult {
    const selection = this.selectBestTokenizer(input);
    const result = this.countText(selection.profileId, text);
    return {
      profileId: result.profileId,
      text: result.text,
      tokens: result.tokens + padding,
      strategy: result.strategy,
      fromCache: result.fromCache,
    };
  }

  clearCache(): void {
    this.countCache.clear();
  }

  countText(profileIdOrModelId: string, text: string): TokenCountResult {
    const profile = this.getProfile(profileIdOrModelId);
    const key = `${profile.id}:${profile.strategy}:${text}`;
    const cached = this.countCache.get(key);
    const fromCache = cached !== undefined;
    const tokens = fromCache ? cached : this.countWithProfile(profile, text);
    if (!fromCache) {
      this.countCache.set(key, tokens);
    }
    const result: TokenCountResult = {
      profileId: profile.id,
      text: text,
      tokens: tokens,
      strategy: profile.strategy,
      fromCache: fromCache,
    };
    const payload: TokenizerCountedPayload = {
      result: this.copyCountResult(result),
    };
    this.events.publish<TokenizerCountedPayload>('tokenizer.counted', payload);
    return this.copyCountResult(result);
  }

  countMessages(profileIdOrModelId: string, messages: Array<TokenMessage>): TokenMessageCountResult {
    const profile = this.getProfile(profileIdOrModelId);
    const parts = new Array<TokenMessagePart>();
    let total = 0;
    for (let index = 0; index < messages.length; index += 1) {
      const contentTokens = this.countText(profile.id, messages[index].content).tokens;
      const tokens = contentTokens + profile.messageOverhead;
      parts.push({
        role: messages[index].role,
        content: messages[index].content,
        tokens: tokens,
      });
      total += tokens;
    }
    return {
      profileId: profile.id,
      tokens: total,
      parts: parts,
    };
  }

  buildBudget(profileIdOrModelId: string, messages: Array<TokenMessage>, completionReserve: number): TokenBudgetResult {
    const profile = this.getProfile(profileIdOrModelId);
    const reserve = Math.max(0, completionReserve);
    const promptTokens = this.countMessages(profile.id, messages).tokens;
    const available = Math.max(0, profile.maxContext - reserve);
    const result: TokenBudgetResult = {
      profileId: profile.id,
      maxContext: profile.maxContext,
      completionReserve: reserve,
      availablePromptTokens: available,
      promptTokens: promptTokens,
      fits: promptTokens <= available,
      messages: this.copyMessages(messages),
    };
    const payload: TokenBudgetPayload = {
      result: this.copyBudgetResult(result),
    };
    this.events.publish<TokenBudgetPayload>('tokenizer.budget.built', payload);
    return this.copyBudgetResult(result);
  }

  trimMessagesToBudget(profileIdOrModelId: string, messages: Array<TokenMessage>, completionReserve: number): TokenTrimResult {
    let remaining = this.copyMessages(messages);
    let result = this.buildBudget(profileIdOrModelId, remaining, completionReserve);
    let removed = 0;
    while (!result.fits && remaining.length > 1) {
      const removeIndex = this.findOldestRemovableMessage(remaining);
      if (removeIndex < 0) {
        break;
      }
      remaining.splice(removeIndex, 1);
      removed += 1;
      result = this.buildBudget(profileIdOrModelId, remaining, completionReserve);
    }
    return {
      result: result,
      messages: remaining,
      removedCount: removed,
    };
  }

  private countWithProfile(profile: TokenizerProfile, text: string): number {
    if (text.length === 0) {
      return 0;
    }
    if (profile.strategy === 'word') {
      return this.countWords(text);
    }
    return Math.ceil(this.estimateUtf8Bytes(text) / profile.bytesPerToken);
  }

  private countWords(text: string): number {
    const normalized = text.trim();
    if (normalized.length === 0) {
      return 0;
    }
    return normalized.split(/\s+/).length;
  }

  private estimateUtf8Bytes(text: string): number {
    let bytes = 0;
    for (let index = 0; index < text.length; index += 1) {
      const code = text.charCodeAt(index);
      if (code <= 0x7f) {
        bytes += 1;
      } else if (code <= 0x7ff) {
        bytes += 2;
      } else if (code >= 0xd800 && code <= 0xdbff && index + 1 < text.length) {
        bytes += 4;
        index += 1;
      } else {
        bytes += 3;
      }
    }
    return bytes;
  }

  private findOldestRemovableMessage(messages: Array<TokenMessage>): number {
    for (let index = 0; index < messages.length - 1; index += 1) {
      if (messages[index].role !== 'system') {
        return index;
      }
    }
    return messages.length > 1 ? 0 : -1;
  }

  private copyMessages(messages: Array<TokenMessage>): Array<TokenMessage> {
    const result = new Array<TokenMessage>();
    for (let index = 0; index < messages.length; index += 1) {
      result.push({
        role: messages[index].role,
        content: messages[index].content,
      });
    }
    return result;
  }

  private copyProfile(profile: TokenizerProfile): TokenizerProfile {
    return {
      id: profile.id,
      name: profile.name,
      strategy: profile.strategy,
      bytesPerToken: profile.bytesPerToken,
      maxContext: profile.maxContext,
      messageOverhead: profile.messageOverhead,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
    };
  }

  private copyCountResult(result: TokenCountResult): TokenCountResult {
    return {
      profileId: result.profileId,
      text: result.text,
      tokens: result.tokens,
      strategy: result.strategy,
      fromCache: result.fromCache,
    };
  }

  private copyBudgetResult(result: TokenBudgetResult): TokenBudgetResult {
    return {
      profileId: result.profileId,
      maxContext: result.maxContext,
      completionReserve: result.completionReserve,
      availablePromptTokens: result.availablePromptTokens,
      promptTokens: result.promptTokens,
      fits: result.fits,
      messages: this.copyMessages(result.messages),
    };
  }

  private registerDefaultProfiles(): void {
    this.registerBuiltinProfile({
      id: 'gpt2',
      name: 'GPT-2 tokenizer compatible',
      strategy: 'bytes',
      bytesPerToken: 3.35,
      maxContext: 2048,
      messageOverhead: 0,
    });
    this.registerBuiltinProfile({
      id: 'openai-cl100k',
      name: 'OpenAI cl100k compatible',
      strategy: 'bytes',
      bytesPerToken: 3.35,
      maxContext: 128000,
      messageOverhead: 3,
    });
    this.registerBuiltinProfile({
      id: 'claude',
      name: 'Claude tokenizer compatible',
      strategy: 'bytes',
      bytesPerToken: 3.2,
      maxContext: 200000,
      messageOverhead: 3,
    });
    this.registerBuiltinProfile({
      id: 'llama',
      name: 'Llama tokenizer compatible',
      strategy: 'bytes',
      bytesPerToken: 3.5,
      maxContext: 4096,
      messageOverhead: 3,
    });
    this.registerBuiltinProfile({
      id: 'llama3',
      name: 'Llama 3 tokenizer compatible',
      strategy: 'bytes',
      bytesPerToken: 3.5,
      maxContext: 128000,
      messageOverhead: 3,
    });
    this.registerBuiltinProfile({
      id: 'mistral',
      name: 'Mistral tokenizer compatible',
      strategy: 'bytes',
      bytesPerToken: 3.4,
      maxContext: 32000,
      messageOverhead: 3,
    });
    this.registerBuiltinProfile({
      id: 'nemo',
      name: 'Mistral Nemo tokenizer compatible',
      strategy: 'bytes',
      bytesPerToken: 3.4,
      maxContext: 128000,
      messageOverhead: 3,
    });
    this.registerBuiltinProfile({
      id: 'gemma',
      name: 'Gemma tokenizer compatible',
      strategy: 'bytes',
      bytesPerToken: 3.6,
      maxContext: 8192,
      messageOverhead: 3,
    });
    this.registerBuiltinProfile({
      id: 'qwen2',
      name: 'Qwen 2 tokenizer compatible',
      strategy: 'bytes',
      bytesPerToken: 3.4,
      maxContext: 32768,
      messageOverhead: 3,
    });
    this.registerBuiltinProfile({
      id: 'deepseek',
      name: 'DeepSeek tokenizer compatible',
      strategy: 'bytes',
      bytesPerToken: 3.4,
      maxContext: 64000,
      messageOverhead: 3,
    });
    this.registerBuiltinProfile({
      id: 'command-r',
      name: 'Command R tokenizer compatible',
      strategy: 'bytes',
      bytesPerToken: 3.4,
      maxContext: 128000,
      messageOverhead: 3,
    });
    this.registerBuiltinProfile({
      id: 'command-a',
      name: 'Command A tokenizer compatible',
      strategy: 'bytes',
      bytesPerToken: 3.4,
      maxContext: 256000,
      messageOverhead: 3,
    });
    this.registerBuiltinProfile({
      id: 'yi',
      name: 'Yi tokenizer compatible',
      strategy: 'bytes',
      bytesPerToken: 3.5,
      maxContext: 200000,
      messageOverhead: 3,
    });
    this.registerBuiltinProfile({
      id: 'jamba',
      name: 'Jamba tokenizer compatible',
      strategy: 'bytes',
      bytesPerToken: 3.4,
      maxContext: 256000,
      messageOverhead: 3,
    });
    this.registerBuiltinProfile({
      id: 'nerdstash',
      name: 'Nerdstash tokenizer compatible',
      strategy: 'bytes',
      bytesPerToken: 3.35,
      maxContext: 8192,
      messageOverhead: 3,
    });
    this.registerBuiltinProfile({
      id: 'nerdstash_v2',
      name: 'Nerdstash v2 tokenizer compatible',
      strategy: 'bytes',
      bytesPerToken: 3.35,
      maxContext: 8192,
      messageOverhead: 3,
    });

    this.bindBuiltinModel('claude-3-5-sonnet', 'claude');
    this.bindBuiltinModel('claude-3-opus', 'claude');
    this.bindBuiltinModel('claude-3-haiku', 'claude');
    this.bindBuiltinModel('llama', 'llama');
    this.bindBuiltinModel('llama-2', 'llama');
    this.bindBuiltinModel('llama-3', 'llama3');
    this.bindBuiltinModel('llama-3.1', 'llama3');
    this.bindBuiltinModel('llama-3.2', 'llama3');
    this.bindBuiltinModel('mistral-large', 'mistral');
    this.bindBuiltinModel('mistral-small', 'mistral');
    this.bindBuiltinModel('mistral-nemo', 'nemo');
    this.bindBuiltinModel('gemma-2', 'gemma');
    this.bindBuiltinModel('qwen2', 'qwen2');
    this.bindBuiltinModel('deepseek-chat', 'deepseek');
    this.bindBuiltinModel('command-r', 'command-r');
    this.bindBuiltinModel('command-r-plus', 'command-r');
    this.bindBuiltinModel('command-a', 'command-a');
    this.bindBuiltinModel('yi-large', 'yi');
    this.bindBuiltinModel('jamba', 'jamba');
    this.bindBuiltinModel('clio', 'nerdstash');
    this.bindBuiltinModel('kayra', 'nerdstash_v2');
  }

  private registerBuiltinProfile(params: TokenizerProfileCreateParams): void {
    const profile: TokenizerProfile = {
      id: params.id,
      name: params.name,
      strategy: params.strategy,
      bytesPerToken: params.bytesPerToken,
      maxContext: params.maxContext,
      messageOverhead: params.messageOverhead === undefined ? 0 : params.messageOverhead,
      createdAt: 0,
      updatedAt: 0,
    };
    this.profiles.set(profile.id, profile);
  }

  private bindBuiltinModel(modelId: string, profileId: string): void {
    this.modelBindings.set(modelId, profileId);
  }

  private createTokenizerOption(id: number, key: string, name: string, profileId: string, canEncode: boolean, remote: boolean): TokenizerOption {
    return {
      id: id,
      key: key,
      name: name,
      profileId: profileId,
      canEncode: canEncode,
      remote: remote,
    };
  }

  private findTokenizerOption(profileId: string, remote: boolean): TokenizerOption {
    const options = this.listTokenizerOptions();
    for (let index = 0; index < options.length; index += 1) {
      if (options[index].profileId === profileId && options[index].remote === remote) {
        return options[index];
      }
    }
    for (let index = 0; index < options.length; index += 1) {
      if (options[index].profileId === profileId) {
        return options[index];
      }
    }
    return options[0];
  }

  private resolveProfileIdFromText(text: string): string {
    const normalized = this.normalize(text);
    if (normalized.indexOf('deepseek') >= 0 || normalized.indexOf('sonar-reasoning') >= 0) {
      return 'deepseek';
    }
    if (normalized.indexOf('command-a') >= 0) {
      return 'command-a';
    }
    if (normalized.indexOf('command-r') >= 0 || normalized.indexOf('cohere') >= 0) {
      return 'command-r';
    }
    if (normalized.indexOf('qwen') >= 0 || normalized.indexOf('qwq') >= 0 || normalized.indexOf('tongyi') >= 0 || normalized.indexOf('kimi') >= 0) {
      return 'qwen2';
    }
    if (normalized.indexOf('claude') >= 0 || normalized.indexOf('anthropic') >= 0) {
      return 'claude';
    }
    if (normalized.indexOf('jamba') >= 0 || normalized.indexOf('ai21') >= 0) {
      return 'jamba';
    }
    if (normalized.indexOf('gemma') >= 0 || normalized.indexOf('gemini') >= 0 || normalized.indexOf('makersuite') >= 0 || normalized.indexOf('vertex') >= 0) {
      return 'gemma';
    }
    if (normalized.indexOf('nemo') >= 0 || normalized.indexOf('pixtral') >= 0) {
      return 'nemo';
    }
    if (normalized.indexOf('mistral') >= 0 || normalized.indexOf('mixtral') >= 0) {
      return 'mistral';
    }
    if (normalized.indexOf('yi') >= 0) {
      return 'yi';
    }
    if (normalized.indexOf('llama3') >= 0 || normalized.indexOf('llama-3') >= 0 || normalized.indexOf('llama-4') >= 0) {
      return 'llama3';
    }
    if (normalized.indexOf('llama') >= 0) {
      return 'llama';
    }
    if (normalized.indexOf('gpt2') >= 0 || normalized.indexOf('gpt-2') >= 0) {
      return 'gpt2';
    }
    if (normalized.indexOf('gpt') >= 0 || normalized.indexOf('openai') >= 0) {
      return 'openai-cl100k';
    }
    return '';
  }

  private normalize(value: string): string {
    return value.toLowerCase();
  }

  private resolveProfileId(profileIdOrModelId: string): string {
    const binding = this.modelBindings.get(profileIdOrModelId);
    return binding === undefined ? profileIdOrModelId : binding;
  }

  private requireProfile(profileId: string): TokenizerProfile {
    const profile = this.profiles.get(profileId);
    if (profile === undefined) {
      throw new Error(`Tokenizer profile not found: ${profileId}`);
    }
    return profile;
  }
}
