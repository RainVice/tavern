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

import type { ChatMessageRole } from '../contracts/PublicContracts';

/**
 * 提供统计相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class StatsRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * chats 列表，由当前实例内部维护。
   */
  private chats: Map<string, StatsChatRecord> = new Map<string, StatsChatRecord>();
  /**
   * providers 列表，由当前实例内部维护。
   */
  private providers: Map<string, StatsProviderRecord> = new Map<string, StatsProviderRecord>();
  /**
   * rag Sources 列表，由当前实例内部维护。
   */
  private ragSources: Map<string, StatsRagRecord> = new Map<string, StatsRagRecord>();
  /**
   * plugins 列表，由当前实例内部维护。
   */
  private plugins: Map<string, StatsPluginRecord> = new Map<string, StatsPluginRecord>();
  /**
   * characters 列表，由当前实例内部维护。
   */
  private characters: Map<string, StatsCharacterRecord> = new Map<string, StatsCharacterRecord>();

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建或写入tokenUsage，完成持久化后返回可供调用方使用的结果。
   * @param chatId 目标聊天标识。
   * @param providerId 目标模型服务标识。
   * @param promptTokens token 数量或 token 内容。
   * @param completionTokens token 数量或 token 内容。
   */
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

  /**
   * 创建或写入消息，完成持久化后返回可供调用方使用的结果。
   * @param chatId 目标聊天标识。
   * @param role 消息角色。
   * @param tokenCount 计数值。
   * @param byteCount 计数值。
   */
  recordMessage(chatId: string, role: ChatMessageRole, tokenCount: number, byteCount: number): void {
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

  /**
   * 创建或写入生成记录，完成持久化后返回可供调用方使用的结果。
   * @param providerId 目标模型服务标识。


   * @param promptTokens token 数量或 token 内容。
   * @param completionTokens token 数量或 token 内容。
   */
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

  /**
   * 创建或写入请求，完成持久化后返回可供调用方使用的结果。
   * @param providerId 目标模型服务标识。

   * @returns 条件命中时返回 true，否则返回 false。
   */
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

  /**
   * 创建或写入知识库Query，完成持久化后返回可供调用方使用的结果。
   * @param sourceId 目标来源标识。

   * @returns 条件命中时返回 true，否则返回 false。
   */
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

  /**
   * 创建或写入PluginError，完成持久化后返回可供调用方使用的结果。
   * @param pluginId 插件标识。
   * @param message 消息记录。
   */
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

  /**
   * 执行 processCharacterMessage 的内部处理步骤，供当前模块复用。
   * @param input 待处理的输入对象。
   */
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

  /**
   * 读取Character Stats 列表，不存在时通常抛出错误或返回空值。

   * @returns 更新或读取后的记录副本。
   */
  getCharacterStats(characterKey: string): StatsCharacterRecord {
    const record = this.characters.get(characterKey);
    if (record === undefined) {
      throw new Error(`Character stats not found: ${characterKey}`);
    }
    return this.copyCharacter(record);
  }

  /**
   * 读取CharacterStats列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listCharacterStats(): Array<StatsCharacterRecord> {
    return this.copyCharacters();
  }

  /**
   * 读取User Stats Totals 列表，不存在时通常抛出错误或返回空值。
   * @returns 更新或读取后的记录副本。
   */
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

  /**
   * 读取指定快照，不存在时抛出错误。
   * @returns 更新或读取后的记录副本。
   */
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

  /**
   * 发布统计事件，把状态变化通知给宿主或其他 Runtime。
   */
  private publishUpdated(): void {
    const payload: StatsUpdatedPayload = {
      snapshot: this.getSnapshot(),
    };
    this.events.publish<StatsUpdatedPayload>('stats.updated', payload);
  }

  /**
   * 读取指定聊天，不存在时抛出错误。
   * @param chatId 目标聊天标识。
   * @param now 当前时间戳。
   * @returns 更新或读取后的记录副本。
   */
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

  /**
   * 读取指定模型服务，不存在时抛出错误。
   * @param providerId 目标模型服务标识。
   * @param now 当前时间戳。
   * @returns 更新或读取后的记录副本。
   */
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

  /**
   * 读取指定OrCreate知识库Source，不存在时抛出错误。
   * @param sourceId 目标来源标识。
   * @param now 当前时间戳。
   * @returns 更新或读取后的记录副本。
   */
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

  /**
   * 读取指定OrCreatePlugin，不存在时抛出错误。
   * @param pluginId 插件标识。
   * @param now 当前时间戳。
   * @returns 更新或读取后的记录副本。
   */
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

  /**
   * 读取指定角色，不存在时抛出错误。

   * @param now 当前时间戳。
   * @returns 更新或读取后的记录副本。
   */
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

  /**
   * 复制Chats 列表，避免外部修改内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private copyChats(): Array<StatsChatRecord> {
    const result = new Array<StatsChatRecord>();
    const values = Array.from(this.chats.values());
    values.sort((left: StatsChatRecord, right: StatsChatRecord) => left.chatId.localeCompare(right.chatId));
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyChat(values[index]));
    }
    return result;
  }

  /**
   * 复制Providers 列表，避免外部修改内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private copyProviders(): Array<StatsProviderRecord> {
    const result = new Array<StatsProviderRecord>();
    const values = Array.from(this.providers.values());
    values.sort((left: StatsProviderRecord, right: StatsProviderRecord) => left.providerId.localeCompare(right.providerId));
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyProvider(values[index]));
    }
    return result;
  }

  /**
   * 复制Rag Sources 列表，避免外部修改内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private copyRagSources(): Array<StatsRagRecord> {
    const result = new Array<StatsRagRecord>();
    const values = Array.from(this.ragSources.values());
    values.sort((left: StatsRagRecord, right: StatsRagRecord) => left.sourceId.localeCompare(right.sourceId));
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyRag(values[index]));
    }
    return result;
  }

  /**
   * 复制Plugins 列表，避免外部修改内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private copyPlugins(): Array<StatsPluginRecord> {
    const result = new Array<StatsPluginRecord>();
    const values = Array.from(this.plugins.values());
    values.sort((left: StatsPluginRecord, right: StatsPluginRecord) => left.pluginId.localeCompare(right.pluginId));
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyPlugin(values[index]));
    }
    return result;
  }

  /**
   * 复制Characters 列表，避免外部修改内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private copyCharacters(): Array<StatsCharacterRecord> {
    const result = new Array<StatsCharacterRecord>();
    const values = Array.from(this.characters.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyCharacter(values[index]));
    }
    result.sort((left: StatsCharacterRecord, right: StatsCharacterRecord) => left.characterKey.localeCompare(right.characterKey));
    return result;
  }

  /**
   * 复制Character 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
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

  /**
   * 统计Words 列表，用于预算、分页或状态汇总。
   * @param text 文本内容。
   */
  private countWords(text: string): number {
    // 数量。
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

  /**
   * 复制Chat 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
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

  /**
   * 复制Provider 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
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

  /**
   * 复制Rag 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
  private copyRag(record: StatsRagRecord): StatsRagRecord {
    return {
      sourceId: record.sourceId,
      queryCount: record.queryCount,
      hitCount: record.hitCount,
      hitRate: record.hitRate,
      updatedAt: record.updatedAt,
    };
  }

  /**
   * 复制Plugin 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
  private copyPlugin(record: StatsPluginRecord): StatsPluginRecord {
    return {
      pluginId: record.pluginId,
      errorCount: record.errorCount,
      lastError: record.lastError,
      updatedAt: record.updatedAt,
    };
  }
}
