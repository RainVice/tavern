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
   * 聊天统计记录映射表，以 chatId 为键维护每个聊天的 token/消息/字节计数。
   */
  private chats: Map<string, StatsChatRecord> = new Map<string, StatsChatRecord>();
  /**
   * 模型服务提供者统计记录映射表，以 providerId 为键维护请求/错误/token 计数。
   */
  private providers: Map<string, StatsProviderRecord> = new Map<string, StatsProviderRecord>();
  /**
   * 知识库（RAG）来源统计记录映射表，以 sourceId 为键维护查询/命中计数。
   */
  private ragSources: Map<string, StatsRagRecord> = new Map<string, StatsRagRecord>();
  /**
   * 插件错误统计记录映射表，以 pluginId 为键维护错误计数。
   */
  private plugins: Map<string, StatsPluginRecord> = new Map<string, StatsPluginRecord>();
  /**
   * 角色统计记录映射表，以 characterKey 为键维护消息/滑动/字数计数。
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
   * 记录一次 token 消耗，更新聊天和提供者的 token 统计数据。
   * @param chatId 目标聊天标识。
   * @param providerId 目标模型服务标识。
   * @param promptTokens 本次消耗的提示词 token 数。
   * @param completionTokens 本次消耗的补全 token 数。
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
   * 记录一条消息，更新聊天统计中的消息数量、token 和字节数。
   * @param chatId 目标聊天标识。
   * @param role 消息角色（`"user"` 或 `"assistant"`）。
   * @param tokenCount 该消息的 token 数。
   * @param byteCount 该消息的字节数。
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
   * 记录一次模型生成，更新提供者的生成统计并返回采样记录。
   * @param providerId 目标模型服务标识。
   * @param startedAt 生成开始时间戳（毫秒）。
   * @param finishedAt 生成结束时间戳（毫秒）。
   * @param promptTokens 提示词 token 数。
   * @param completionTokens 补全 token 数。
   * @returns 本次生成的采样统计记录。
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
   * 记录一次模型服务请求（成功或失败），更新提供者的请求/错误统计。
   * 若为失败请求，同时发布 `stats.provider.error` 事件。
   * @param providerId 目标模型服务标识。
   * @param isError 是否为失败的请求。
   * @returns 更新后的提供者统计记录。
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
   * 记录一次知识库（RAG）查询结果，更新命中率统计。
   * @param sourceId 目标来源标识。
   * @param hit 是否命中。
   * @returns 更新后的知识库来源统计记录。
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
   * 记录一次插件错误，更新插件的错误统计并发布 `stats.plugin.error` 事件。
   * @param pluginId 插件标识。
   * @param message 错误消息。
   * @returns 更新后的插件统计记录。
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
   * 处理角色消息统计，更新单词数、滑动次数等信息。
   * @param input 待处理的统计输入参数。
   * @returns 更新后的角色统计记录。
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
   * 获取指定角色的统计记录，不存在时抛出异常。
   * @param characterKey 角色标识键。
   * @returns 角色的统计记录。
   */
  getCharacterStats(characterKey: string): StatsCharacterRecord {
    const record = this.characters.get(characterKey);
    if (record === undefined) {
      throw new Error(`Character stats not found: ${characterKey}`);
    }
    return this.copyCharacter(record);
  }

  /**
   * 返回所有角色的统计记录列表（按角色键排序）。
   * @returns 角色统计记录列表，每个记录为副本。
   */
  listCharacterStats(): Array<StatsCharacterRecord> {
    return this.copyCharacters();
  }

  /**
   * 汇总所有角色的统计数据，返回用户维度的累计值。
   * @returns 用户维度的累计统计记录。
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
   * 获取当前所有维度的统计快照，包含聚合值和各子项列表。
   * @returns 完整的统计快照。
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
   * 发布 `stats.updated` 事件，通知宿主或其他 Runtime 统计状态已变化。
   */
  private publishUpdated(): void {
    const payload: StatsUpdatedPayload = {
      snapshot: this.getSnapshot(),
    };
    this.events.publish<StatsUpdatedPayload>('stats.updated', payload);
  }

  /**
   * 获取或创建聊天会话的统计记录。
   * @param chatId 目标聊天标识。
   * @param now 当前时间戳。
   * @returns 已有的或新建的聊天统计记录。
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
   * 获取或创建模型服务提供者的统计记录。
   * @param providerId 目标模型服务标识。
   * @param now 当前时间戳。
   * @returns 已有的或新建的提供者统计记录。
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
   * 获取或创建知识库来源的统计记录。
   * @param sourceId 目标来源标识。
   * @param now 当前时间戳。
   * @returns 已有的或新建的知识库来源统计记录。
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
   * 获取或创建插件的错误统计记录。
   * @param pluginId 插件标识。
   * @param now 当前时间戳。
   * @returns 已有的或新建的插件统计记录。
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
   * 获取或创建角色的统计记录。
   * @param characterKey 角色标识键。
   * @param now 当前时间戳。
   * @returns 已有的或新建的角色统计记录。
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

  /**
   * 计算错误率，保留小数点后 6 位。
   */
  private roundRate(numerator: number, denominator: number): number {
    if (denominator === 0) {
      return 0;
    }
    return Math.round((numerator / denominator) * 1000000) / 1000000;
  }

  /**
   * 返回所有聊天统计记录列表（按聊天 ID 排序），每个记录为副本。
   * @returns 聊天统计记录列表。
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
   * 返回所有提供者统计记录列表（按提供者 ID 排序），每个记录为副本。
   * @returns 提供者统计记录列表。
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
   * 返回所有知识库来源统计记录列表（按来源 ID 排序），每个记录为副本。
   * @returns 知识库来源统计记录列表。
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
   * 返回所有插件统计记录列表（按插件 ID 排序），每个记录为副本。
   * @returns 插件统计记录列表。
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
   * 返回所有角色统计记录列表（按角色键排序），每个记录为副本。
   * @returns 角色统计记录列表。
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
   * 深复制角色统计记录。
   * @param record 原始记录。
   * @returns 复制后的新记录。
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

  /**
   * 计算生成耗时（毫秒），起始或结束时间未定义时返回 0。
   */
  private calculateGenTime(startedAt: number | undefined, finishedAt: number | undefined): number {
    if (startedAt === undefined || finishedAt === undefined) {
      return 0;
    }
    return Math.max(0, finishedAt - startedAt);
  }

  /**
   * 统计文本中的字母数字词数（单词由字母、数字、下划线组成）。
   * @param text 文本内容。
   * @returns 单词数量。
   */
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

  /**
   * 深复制聊天统计记录。
   * @param record 原始记录。
   * @returns 复制后的新记录。
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
   * 深复制提供者统计记录。
   * @param record 原始记录。
   * @returns 复制后的新记录。
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
   * 深复制知识库来源统计记录。
   * @param record 原始记录。
   * @returns 复制后的新记录。
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
   * 深复制插件统计记录。
   * @param record 原始记录。
   * @returns 复制后的新记录。
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
