import { EventBus } from '../runtime/EventBus';
import type { MemoryEntry, MemoryExportData, MemoryExtractedPayload } from './MemoryModels';

/**
 * 提供聊天记忆相关的无 UI 运行时能力，负责记忆条目的创建、查询、导出和事件发布。
 */
export class MemoryRuntime {
  /** 事件总线实例。 */
  private events: EventBus;
  /** 内存中的条目存储映射。 */
  private entries: Map<string, MemoryEntry> = new Map();
  /** 自增计数器，用于生成条目标识。 */
  private counter = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线实例。
   */
  constructor(events: EventBus) { this.events = events; }

  /**
   * 创建新的记忆条目，写入内部存储并返回副本。
   * @param chatId 目标聊天会话标识。
   * @param summary 对话摘要文本。
   * @param keyPoints 提取的关键点列表。
   * @param originalMessages 原始消息列表。
   * @param tokenEstimate 令牌数估算值。
   * @returns 新创建的条目副本。
   */
  createEntry(chatId: string, summary: string, keyPoints: Array<string>, originalMessages: Array<string>, tokenEstimate: number): MemoryEntry {
    this.counter += 1; const entryId = `memory-${this.counter}`; const now = Date.now();
    const entry: MemoryEntry = { entryId, chatId, summary, keyPoints: keyPoints.slice(), originalMessages: originalMessages.slice(), tokenEstimate, createdAt: now, updatedAt: now };
    this.entries.set(entryId, this.copyEntry(entry));
    this.events.publish<MemoryExtractedPayload>('memory.extracted', { entry: this.copyEntry(entry) });
    return this.copyEntry(entry);
  }

  /**
   * 获取指定聊天的最近一条记忆条目。
   * @param chatId 目标聊天会话标识。
   * @returns 最近条目的副本，无匹配时返回 undefined。
   */
  getLatestEntry(chatId: string): MemoryEntry | undefined {
    let latest: MemoryEntry | undefined = undefined; const values = Array.from(this.entries.values());
    for (let i = 0; i < values.length; i++) { if (values[i].chatId === chatId) { if (latest === undefined || values[i].createdAt >= latest.createdAt) latest = values[i]; } }
    return latest === undefined ? undefined : this.copyEntry(latest);
  }

  /**
   * 读取指定聊天的条目列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param chatId 目标聊天会话标识；不传则返回所有条目。
   * @returns 记忆条目列表副本
   */
  listEntries(chatId?: string): Array<MemoryEntry> {
    const result = new Array<MemoryEntry>(); const values = Array.from(this.entries.values());
    for (let i = 0; i < values.length; i++) { if (chatId === undefined || values[i].chatId === chatId) result.push(this.copyEntry(values[i])); }
    return result;
  }

  /**
   * 删除指定标识的记忆条目。
   * @param entryId 要删除的条目标识。
   * @throws 条目不存在时抛出错误。
   */
  removeEntry(entryId: string): void {
    if (this.entries.get(entryId) === undefined) throw new Error(`记忆条目未找到: ${entryId}`);
    this.entries.delete(entryId);
  }

  /**
   * 根据最近记忆条目构建 prompt 注入文本，仅生成数据结构，不直接执行外部请求。
   * @param chatId 目标聊天会话标识。
   * @param maxEntries 最多包含的条目数。
   * @returns 拼接后的记忆提示文本。
   */
  buildPromptInjection(chatId: string, maxEntries: number): string {
    const chatEntries = new Array<MemoryEntry>(); const values = Array.from(this.entries.values());
    for (let i = 0; i < values.length; i++) { if (values[i].chatId === chatId) chatEntries.push(values[i]); }
    chatEntries.sort((a, b) => b.createdAt - a.createdAt);
    const selected = chatEntries.slice(0, Math.min(chatEntries.length, maxEntries));
    const parts = new Array<string>();
    for (let i = 0; i < selected.length; i++) { parts.push(`[记忆] ${selected[i].summary}`); }
    return parts.join('\n');
  }

  /**
   * 导出所有记忆条目，用于备份、迁移或与 SillyTavern 数据互通。
   * @returns 可持久化的导出数据。
   */
  exportData(): MemoryExportData { return { entries: this.listEntries() }; }

  /**
   * 从外部数据导入记忆条目，转换为当前运行时使用的数据结构。
   * @param data 待导入的记忆数据。
   */
  importData(data: MemoryExportData): void {
    for (let i = 0; i < data.entries.length; i++) {
      const entry = this.copyEntry(data.entries[i]);
      this.entries.set(entry.entryId, entry);
      this.counter = Math.max(this.counter, this.parseCounter(entry.entryId));
    }
  }

  /**
   * 深拷贝记忆条目，避免外部修改影响内部状态。
   * @param entry 待复制的条目。
   * @returns 条目的浅层副本（数组字段已切片）。
   */
  private copyEntry(entry: MemoryEntry): MemoryEntry {
    return {
      entryId: entry.entryId,
      chatId: entry.chatId,
      summary: entry.summary,
      keyPoints: entry.keyPoints.slice(),
      originalMessages: entry.originalMessages.slice(),
      tokenEstimate: entry.tokenEstimate,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    };
  }

  /**
   * 从条目标识中解析出自增序号，无效格式返回 0。
   * @param entryId 条目标识。
   * @returns 解析出的序号值。
   */
  private parseCounter(entryId: string): number {
    if (!entryId.startsWith('memory-')) {
      return 0;
    }
    const parsed = Number(entryId.substring(7));
    return parsed > 0 ? parsed : 0;
  }
}
