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

/**
 * 提供统计相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 在对话流程中被 ProviderRuntime 和 ChatRuntime 调用以记录 token 消耗、消息计数、生成性能等指标，
 * 由 UI 层调用 getSnapshot / getCharacterStats / getUserStatsTotals 展示统计分析结果。
 */
export class StatsRuntime {
  private events: EventBus;
  private chats: Map<string, StatsChatRecord> = new Map<string, StatsChatRecord>();
  private providers: Map<string, StatsProviderRecord> = new Map<string, StatsProviderRecord>();
  private ragSources: Map<string, StatsRagRecord> = new Map<string, StatsRagRecord>();
  private plugins: Map<string, StatsPluginRecord> = new Map<string, StatsPluginRecord>();
  private characters: Map<string, StatsCharacterRecord> = new Map<string, StatsCharacterRecord>();

  /**
   * 初始化当前运行时实例，绑定事件总线以在统计变更时发布事件。
   * @param events 事件总线实例，用于发布 "stats.updated"、"stats.provider.error"、"stats.plugin.error" 事件。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 记录一次 token 消耗，更新对应聊天和 provider 的统计数据。
   * 由 ProviderRuntime 在收到 LLM API 返回的 token 用量时调用。
   * @param chatId 目标聊天 ID，用于在 chats 映射中定位聊天统计记录。
   * @param providerId 目标 provider ID，用于在 providers 映射中定位 provider 统计记录。
   * @param promptTokens 本次消耗的 prompt token 数，分别累加到 chat.tokenCount 和 provider.promptTokens。
   * @param completionTokens 本次消耗的 completion token 数，分别累加到 chat.tokenCount 和 provider.completionTokens。
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
   * 记录一条消息的统计信息，更新聊天消息数和 token/字节计数。
   * 由 ChatRuntime 在聊天消息发送/接收时调用。
   * @param chatId 目标聊天 ID，用于在 chats 映射中定位聊天统计记录。
   * @param role 消息角色（"user" 或 "assistant"），决定更新 userMessages 或 assistantMessages。
   * @param tokenCount 消息消耗的 token 数，累加到 chat.tokenCount。
   * @param byteCount 消息的字节数，累加到 chat.byteCount。
   */
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

  /**
   * 记录一次 AI 生成的统计，包含耗时和 token 消耗，返回生成样本。
   * 由 ProviderRuntime 在每次 AI 回复生成完成后调用。
   * @param providerId 目标 provider ID，用于在 providers 映射中定位 provider 统计记录。
   * @param startedAt 生成开始时间戳，用于计算生成耗时。
   * @param finishedAt 生成结束时间戳，与 startedAt 的差值即为生成耗时。
   * @param promptTokens prompt token 数，累加到 provider.promptTokens。
   * @param completionTokens completion token 数，累加到 provider.completionTokens。
   * @returns 本次生成的样本记录，包含 provider ID、时间范围和 token 用量。
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
   * 记录一次 provider 请求，更新请求次数和错误率，如果发生错误则发布错误事件。
   * 由 ProviderRuntime 在每次向 API 发送请求时调用，用于监控 provider 的可用性和稳定性。
   * @param providerId 目标 provider ID，用于在 providers 映射中定位统计记录。
   * @param isError 本次请求是否出错，为 true 时累加 errorCount 并发布 "stats.provider.error" 事件。
   * @returns 更新后的 provider 统计记录。
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
   * 记录一次知识库查询，更新查询次数和命中率。
   * 由 RAG 相关模块在每次知识库检索时调用，用于评估知识库检索的效果。
   * @param sourceId 知识库来源 ID，用于在 ragSources 映射中定位统计记录。
   * @param hit 是否命中，为 true 时累加 hitCount。
   * @returns 更新后的知识库统计记录。
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
   * 记录一次插件错误，更新错误计数并发布错误事件。
   * 由 PluginRuntime 在插件执行出错时调用，用于监控插件的稳定性。
   * @param pluginId 插件 ID，用于在 plugins 映射中定位统计记录。
   * @param message 错误消息，更新为最近一次错误信息供审计使用。
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
   * 处理角色消息统计：更新消息计数、字数和生成耗时，支持追加/滑动等操作类型。
   * 由 ChatRuntime 在处理角色相关的消息操作时调用。
   * @param input 角色消息处理输入，包含角色键值、消息内容、操作类型和时间戳等，
   * 来自聊天界面的用户操作（发送消息、滑动重试、继续生成等）。
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
   * 获取指定角色的详细统计数据。
   * 由 UI 层在展示角色统计面板时调用。
   * @param characterKey 角色键值，用于在 characters 映射中查找对应的统计记录。
   * @returns 角色统计记录副本，不存在时抛出异常。
   */
  getCharacterStats(characterKey: string): StatsCharacterRecord {
    const record = this.characters.get(characterKey);
    if (record === undefined) {
      throw new Error(`Character stats not found: ${characterKey}`);
    }
    return this.copyCharacter(record);
  }

  /**
   * 返回所有角色的统计记录列表。
   * 由 UI 层在展示角色汇总统计时调用。
   * @returns 角色统计记录列表副本。
   */
  listCharacterStats(): Array<StatsCharacterRecord> {
    return this.copyCharacters();
  }

  /**
   * 汇总所有角色的统计数据，返回基于用户维度的聚合总计。
   * 由 UI 层在展示用户统计仪表盘时调用。
   * @returns 聚合后的用户统计总计，包含所有角色的累计消息数、字数、生成耗时等。
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
   * 生成当前所有统计数据的完整快照，包含各维度的汇总信息。
   * 由 publishUpdated 内部调用或由 UI 层直接调用，提供所有维度的聚合数据。
   * @returns 完整的统计快照，包含聊天、provider、知识库、插件和角色的全部统计。
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
   * 查找或创建指定聊天的统计记录。
   * @param chatId 聊天 ID。
   * @param now 用于新建记录的时间戳。
   * @returns 已有的或新创建的聊天统计记录。
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
   * 查找或创建指定 provider 的统计记录。
   * @param providerId provider ID。
   * @param now 用于新建记录的时间戳。
   * @returns 已有的或新创建的 provider 统计记录。
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
   * 查找或创建指定知识库来源的统计记录。
   * @param sourceId 来源 ID。
   * @param now 用于新建记录的时间戳。
   * @returns 已有的或新创建的知识库统计记录。
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
   * 查找或创建指定插件的统计记录。
   * @param pluginId 插件 ID。
   * @param now 用于新建记录的时间戳。
   * @returns 已有的或新创建的插件统计记录。
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
   * 查找或创建指定角色的统计记录。
   * @param characterKey 角色键值。
   * @param now 用于新建记录的时间戳。
   * @returns 已有的或新创建的角色统计记录。
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
   * 深拷贝聊天统计记录列表，按 ID 排序。
   * @returns 聊天统计记录列表副本。
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
   * 深拷贝 provider 统计记录列表，按 ID 排序。
   * @returns provider 统计记录列表副本。
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
   * 深拷贝知识库来源统计记录列表，按 ID 排序。
   * @returns 知识库统计记录列表副本。
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
   * 深拷贝插件统计记录列表，按 ID 排序。
   * @returns 插件统计记录列表副本。
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
   * 深拷贝角色统计记录列表，按角色键值排序。
   * @returns 角色统计记录列表副本。
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
   * 深拷贝角色统计记录。
   * @param record 待拷贝的角色统计记录。
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
   * 统计文本中的单词数量（英文字母/数字/下划线构成的连续序列）。
   * @param text 要统计的文本。
   */
  private countWords(text: string): number {
    // 单词计数器。
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
   * 深拷贝聊天统计记录。
   * @param record 待拷贝的聊天统计记录。
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
   * 深拷贝 provider 统计记录。
   * @param record 待拷贝的 provider 统计记录。
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
   * 深拷贝知识库来源统计记录。
   * @param record 待拷贝的知识库统计记录。
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
   * 深拷贝插件统计记录。
   * @param record 待拷贝的插件统计记录。
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
