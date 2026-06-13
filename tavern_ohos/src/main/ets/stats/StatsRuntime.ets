import { EventBus } from '../runtime/EventBus';
import type {
  StatsCharacterRecord,
  StatsChatRecord,
  StatsGenerationSample,
  StatsMessageProcessInput,
  StatsPluginErrorPayload,
  StatsPluginRecord,
  StatsProviderErrorPayload,
  StatsProviderRecord,
  StatsRagRecord,
  StatsSnapshot,
  StatsTotals,
  StatsUpdatedPayload,
} from './StatsModels';

export class StatsRuntime {
  private events: EventBus;
  private chats: Map<string, StatsChatRecord> = new Map<string, StatsChatRecord>();
  private providers: Map<string, StatsProviderRecord> = new Map<string, StatsProviderRecord>();
  private ragSources: Map<string, StatsRagRecord> = new Map<string, StatsRagRecord>();
  private plugins: Map<string, StatsPluginRecord> = new Map<string, StatsPluginRecord>();
  private characters: Map<string, StatsCharacterRecord> = new Map<string, StatsCharacterRecord>();

  constructor(events: EventBus) {
    this.events = events;
  }

  recordTokenUsage(chatId: string, providerId: string, promptTokens: number, completionTokens: number): void {
    const now = Date.now();
    const chat = this.getOrCreateChat(chatId, now);
    chat.tokenCount += promptTokens + completionTokens;
    chat.updatedAt = now;
    const provider = this.getOrCreateProvider(providerId, now);
    provider.promptTokens += promptTokens;
    provider.completionTokens += completionTokens;
    provider.updatedAt = now;
    this.publishUpdated();
  }

  recordMessage(chatId: string, role: string, tokenCount: number, byteCount: number): void {
    const now = Date.now();
    const chat = this.getOrCreateChat(chatId, now);
    chat.messageCount += 1;
    chat.tokenCount += tokenCount;
    chat.byteCount += byteCount;
    chat.updatedAt = now;
    if (role === 'user') {
      chat.userMessages += 1;
    } else {
      chat.assistantMessages += 1;
    }
    this.publishUpdated();
  }

  recordGeneration(
    providerId: string,
    startedAt: number,
    finishedAt: number,
    promptTokens: number,
    completionTokens: number,
  ): StatsGenerationSample {
    const now = Date.now();
    const duration = Math.max(0, finishedAt - startedAt);
    const provider = this.getOrCreateProvider(providerId, now);
    provider.generationCount += 1;
    provider.generationTimeMs += duration;
    provider.promptTokens += promptTokens;
    provider.completionTokens += completionTokens;
    provider.updatedAt = now;
    const sample: StatsGenerationSample = {
      providerId: providerId,
      startedAt: startedAt,
      finishedAt: finishedAt,
      durationMs: duration,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    };
    this.publishUpdated();
    return sample;
  }

  recordProviderRequest(providerId: string, isError: boolean): StatsProviderRecord {
    const now = Date.now();
    const provider = this.getOrCreateProvider(providerId, now);
    provider.requestCount += 1;
    if (isError) {
      provider.errorCount += 1;
    }
    provider.errorRate = this.roundRate(provider.errorCount, provider.requestCount);
    provider.updatedAt = now;
    if (isError) {
      const payload: StatsProviderErrorPayload = {
        providerId: provider.providerId,
        errorCount: provider.errorCount,
        errorRate: provider.errorRate,
      };
      this.events.publish<StatsProviderErrorPayload>('stats.provider.error', payload);
    }
    this.publishUpdated();
    return this.copyProvider(provider);
  }

  recordRagQuery(sourceId: string, hit: boolean): StatsRagRecord {
    const now = Date.now();
    const record = this.getOrCreateRagSource(sourceId, now);
    record.queryCount += 1;
    if (hit) {
      record.hitCount += 1;
    }
    record.hitRate = this.roundRate(record.hitCount, record.queryCount);
    record.updatedAt = now;
    this.publishUpdated();
    return this.copyRag(record);
  }

  recordPluginError(pluginId: string, message: string): StatsPluginRecord {
    const now = Date.now();
    const record = this.getOrCreatePlugin(pluginId, now);
    record.errorCount += 1;
    record.lastError = message;
    record.updatedAt = now;
    const payload: StatsPluginErrorPayload = {
      pluginId: pluginId,
      errorCount: record.errorCount,
      message: message,
    };
    this.events.publish<StatsPluginErrorPayload>('stats.plugin.error', payload);
    this.publishUpdated();
    return this.copyPlugin(record);
  }

  processCharacterMessage(input: StatsMessageProcessInput): StatsCharacterRecord {
    const now = input.now === undefined ? Date.now() : input.now;
    const record = this.getOrCreateCharacter(input.characterKey, now);
    record.totalGenTime += this.calculateGenTime(input.genStartedAt, input.genFinishedAt);
    const isAppendLike = input.processType === 'append' || input.processType === 'continue' || input.processType === 'appendFinal';
    const oldMessage = input.oldMessage === undefined ? '' : input.oldMessage;
    const wordDelta = isAppendLike ? this.countWords(input.message) - this.countWords(oldMessage) : this.countWords(input.message);

    if (input.isUser) {
      if (!isAppendLike) {
        record.userMsgCount += 1;
      }
      record.userWordCount += wordDelta;
    } else {
      if (!isAppendLike) {
        record.nonUserMsgCount += 1;
      }
      record.nonUserWordCount += wordDelta;
    }

    if (input.processType === 'swipe') {
      record.totalSwipeCount += 1;
    }

    record.dateLastChat = now;
    record.dateFirstChat = Math.min(record.dateFirstChat, now);
    this.publishUpdated();
    return this.copyCharacter(record);
  }

  getCharacterStats(characterKey: string): StatsCharacterRecord {
    const record = this.characters.get(characterKey);
    if (record === undefined) {
      throw new Error(`Character stats not found: ${characterKey}`);
    }
    return this.copyCharacter(record);
  }

  listCharacterStats(): Array<StatsCharacterRecord> {
    return this.copyCharacters();
  }

  getUserStatsTotals(): StatsTotals {
    const characters = this.copyCharacters();
    const totals: StatsTotals = {
      totalGenTime: 0,
      userMsgCount: 0,
      nonUserMsgCount: 0,
      userWordCount: 0,
      nonUserWordCount: 0,
      totalSwipeCount: 0,
      dateLastChat: 0,
      dateFirstChat: 253402300799999,
    };

    for (let index = 0; index < characters.length; index += 1) {
      totals.totalGenTime += characters[index].totalGenTime;
      totals.userMsgCount += characters[index].userMsgCount;
      totals.nonUserMsgCount += characters[index].nonUserMsgCount;
      totals.userWordCount += characters[index].userWordCount;
      totals.nonUserWordCount += characters[index].nonUserWordCount;
      totals.totalSwipeCount += characters[index].totalSwipeCount;
      if (characters[index].dateLastChat !== 0) {
        totals.dateLastChat = Math.max(totals.dateLastChat, characters[index].dateLastChat);
      }
      if (characters[index].dateFirstChat !== 0) {
        totals.dateFirstChat = Math.min(totals.dateFirstChat, characters[index].dateFirstChat);
      }
    }

    if (totals.dateFirstChat === 253402300799999) {
      totals.dateFirstChat = 0;
    }
    return totals;
  }

  getSnapshot(): StatsSnapshot {
    const chats = this.copyChats();
    const providers = this.copyProviders();
    const ragSources = this.copyRagSources();
    const plugins = this.copyPlugins();
    const characters = this.copyCharacters();
    let promptTokens = 0;
    let completionTokens = 0;
    let totalMessages = 0;
    let userMessages = 0;
    let assistantMessages = 0;
    let totalChatBytes = 0;
    let totalGenerations = 0;
    let generationTimeMs = 0;
    let providerErrors = 0;
    let ragQueries = 0;
    let ragHits = 0;
    let pluginErrors = 0;

    for (let index = 0; index < providers.length; index += 1) {
      promptTokens += providers[index].promptTokens;
      completionTokens += providers[index].completionTokens;
      totalGenerations += providers[index].generationCount;
      generationTimeMs += providers[index].generationTimeMs;
      providerErrors += providers[index].errorCount;
    }
    for (let index = 0; index < chats.length; index += 1) {
      totalMessages += chats[index].messageCount;
      userMessages += chats[index].userMessages;
      assistantMessages += chats[index].assistantMessages;
      totalChatBytes += chats[index].byteCount;
    }
    for (let index = 0; index < ragSources.length; index += 1) {
      ragQueries += ragSources[index].queryCount;
      ragHits += ragSources[index].hitCount;
    }
    for (let index = 0; index < plugins.length; index += 1) {
      pluginErrors += plugins[index].errorCount;
    }
    return {
      totalPromptTokens: promptTokens,
      totalCompletionTokens: completionTokens,
      totalTokens: promptTokens + completionTokens,
      totalMessages: totalMessages,
      userMessages: userMessages,
      assistantMessages: assistantMessages,
      totalChatBytes: totalChatBytes,
      totalGenerations: totalGenerations,
      totalGenerationTimeMs: generationTimeMs,
      providerErrors: providerErrors,
      ragQueries: ragQueries,
      ragHits: ragHits,
      pluginErrors: pluginErrors,
      chatStats: chats,
      providerStats: providers,
      ragStats: ragSources,
      pluginStats: plugins,
      characterStats: characters,
    };
  }

  private publishUpdated(): void {
    const payload: StatsUpdatedPayload = {
      snapshot: this.getSnapshot(),
    };
    this.events.publish<StatsUpdatedPayload>('stats.updated', payload);
  }

  private getOrCreateChat(chatId: string, now: number): StatsChatRecord {
    const existing = this.chats.get(chatId);
    if (existing !== undefined) {
      return existing;
    }
    const record: StatsChatRecord = {
      chatId: chatId,
      messageCount: 0,
      userMessages: 0,
      assistantMessages: 0,
      tokenCount: 0,
      byteCount: 0,
      updatedAt: now,
    };
    this.chats.set(chatId, record);
    return record;
  }

  private getOrCreateProvider(providerId: string, now: number): StatsProviderRecord {
    const existing = this.providers.get(providerId);
    if (existing !== undefined) {
      return existing;
    }
    const record: StatsProviderRecord = {
      providerId: providerId,
      requestCount: 0,
      errorCount: 0,
      errorRate: 0,
      generationCount: 0,
      generationTimeMs: 0,
      promptTokens: 0,
      completionTokens: 0,
      updatedAt: now,
    };
    this.providers.set(providerId, record);
    return record;
  }

  private getOrCreateRagSource(sourceId: string, now: number): StatsRagRecord {
    const existing = this.ragSources.get(sourceId);
    if (existing !== undefined) {
      return existing;
    }
    const record: StatsRagRecord = {
      sourceId: sourceId,
      queryCount: 0,
      hitCount: 0,
      hitRate: 0,
      updatedAt: now,
    };
    this.ragSources.set(sourceId, record);
    return record;
  }

  private getOrCreatePlugin(pluginId: string, now: number): StatsPluginRecord {
    const existing = this.plugins.get(pluginId);
    if (existing !== undefined) {
      return existing;
    }
    const record: StatsPluginRecord = {
      pluginId: pluginId,
      errorCount: 0,
      lastError: '',
      updatedAt: now,
    };
    this.plugins.set(pluginId, record);
    return record;
  }

  private getOrCreateCharacter(characterKey: string, now: number): StatsCharacterRecord {
    const existing = this.characters.get(characterKey);
    if (existing !== undefined) {
      return existing;
    }
    const record: StatsCharacterRecord = {
      characterKey: characterKey,
      totalGenTime: 0,
      userMsgCount: 0,
      nonUserMsgCount: 0,
      userWordCount: 0,
      nonUserWordCount: 0,
      totalSwipeCount: 0,
      dateLastChat: 0,
      dateFirstChat: now,
    };
    this.characters.set(characterKey, record);
    return record;
  }

  private roundRate(numerator: number, denominator: number): number {
    if (denominator === 0) {
      return 0;
    }
    return Math.round((numerator / denominator) * 1000000) / 1000000;
  }

  private copyChats(): Array<StatsChatRecord> {
    const result = new Array<StatsChatRecord>();
    const values = Array.from(this.chats.values());
    values.sort((left: StatsChatRecord, right: StatsChatRecord) => left.chatId.localeCompare(right.chatId));
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyChat(values[index]));
    }
    return result;
  }

  private copyProviders(): Array<StatsProviderRecord> {
    const result = new Array<StatsProviderRecord>();
    const values = Array.from(this.providers.values());
    values.sort((left: StatsProviderRecord, right: StatsProviderRecord) => left.providerId.localeCompare(right.providerId));
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyProvider(values[index]));
    }
    return result;
  }

  private copyRagSources(): Array<StatsRagRecord> {
    const result = new Array<StatsRagRecord>();
    const values = Array.from(this.ragSources.values());
    values.sort((left: StatsRagRecord, right: StatsRagRecord) => left.sourceId.localeCompare(right.sourceId));
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyRag(values[index]));
    }
    return result;
  }

  private copyPlugins(): Array<StatsPluginRecord> {
    const result = new Array<StatsPluginRecord>();
    const values = Array.from(this.plugins.values());
    values.sort((left: StatsPluginRecord, right: StatsPluginRecord) => left.pluginId.localeCompare(right.pluginId));
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyPlugin(values[index]));
    }
    return result;
  }

  private copyCharacters(): Array<StatsCharacterRecord> {
    const result = new Array<StatsCharacterRecord>();
    const values = Array.from(this.characters.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyCharacter(values[index]));
    }
    result.sort((left: StatsCharacterRecord, right: StatsCharacterRecord) => left.characterKey.localeCompare(right.characterKey));
    return result;
  }

  private copyCharacter(record: StatsCharacterRecord): StatsCharacterRecord {
    return {
      characterKey: record.characterKey,
      totalGenTime: record.totalGenTime,
      userMsgCount: record.userMsgCount,
      nonUserMsgCount: record.nonUserMsgCount,
      userWordCount: record.userWordCount,
      nonUserWordCount: record.nonUserWordCount,
      totalSwipeCount: record.totalSwipeCount,
      dateLastChat: record.dateLastChat,
      dateFirstChat: record.dateFirstChat,
    };
  }

  private calculateGenTime(startedAt: number | undefined, finishedAt: number | undefined): number {
    if (startedAt === undefined || finishedAt === undefined) {
      return 0;
    }
    return Math.max(0, finishedAt - startedAt);
  }

  private countWords(text: string): number {
    let count = 0;
    let inWord = false;
    for (let index = 0; index < text.length; index += 1) {
      const code = text.charCodeAt(index);
      const isWord = (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || (code >= 48 && code <= 57) || code === 95;
      if (isWord && !inWord) {
        count += 1;
        inWord = true;
      } else if (!isWord) {
        inWord = false;
      }
    }
    return count;
  }

  private copyChat(record: StatsChatRecord): StatsChatRecord {
    return {
      chatId: record.chatId,
      messageCount: record.messageCount,
      userMessages: record.userMessages,
      assistantMessages: record.assistantMessages,
      tokenCount: record.tokenCount,
      byteCount: record.byteCount,
      updatedAt: record.updatedAt,
    };
  }

  private copyProvider(record: StatsProviderRecord): StatsProviderRecord {
    return {
      providerId: record.providerId,
      requestCount: record.requestCount,
      errorCount: record.errorCount,
      errorRate: record.errorRate,
      generationCount: record.generationCount,
      generationTimeMs: record.generationTimeMs,
      promptTokens: record.promptTokens,
      completionTokens: record.completionTokens,
      updatedAt: record.updatedAt,
    };
  }

  private copyRag(record: StatsRagRecord): StatsRagRecord {
    return {
      sourceId: record.sourceId,
      queryCount: record.queryCount,
      hitCount: record.hitCount,
      hitRate: record.hitRate,
      updatedAt: record.updatedAt,
    };
  }

  private copyPlugin(record: StatsPluginRecord): StatsPluginRecord {
    return {
      pluginId: record.pluginId,
      errorCount: record.errorCount,
      lastError: record.lastError,
      updatedAt: record.updatedAt,
    };
  }
}
