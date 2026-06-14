import { EventBus } from '../runtime/EventBus';
import type { MemoryEntry, MemoryExportData, MemoryExtractedPayload } from './MemoryModels';

/**
 * 提供聊天记忆相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class MemoryRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus; private entries: Map<string,MemoryEntry>=new Map(); private counter=0;
  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) { this.events=events; }
  /**
   * 创建新的条目记录，写入存储并返回副本。
   * @param chatId 目标聊天标识。




   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  createEntry(chatId: string, summary: string, keyPoints: Array<string>, originalMessages: Array<string>, tokenEstimate: number): MemoryEntry {
    this.counter+=1; const entryId=`memory-${this.counter}`; const now=Date.now();
    const entry: MemoryEntry = { entryId, chatId, summary, keyPoints: keyPoints.slice(), originalMessages: originalMessages.slice(), tokenEstimate, createdAt: now, updatedAt: now };
    this.entries.set(entryId, this.copyEntry(entry));
    this.events.publish<MemoryExtractedPayload>('memory.extracted', { entry: this.copyEntry(entry) });
    return this.copyEntry(entry);
  }
  /**
   * 读取指定条目，不存在时抛出错误。
   * @param chatId 目标聊天标识。
   * @returns 更新或读取后的记录副本。
   */
  getLatestEntry(chatId: string): MemoryEntry|undefined {
    let latest: MemoryEntry|undefined=undefined; const values=Array.from(this.entries.values());
    for (let i=0;i<values.length;i++) { if (values[i].chatId===chatId) { if (latest===undefined||values[i].createdAt>=latest.createdAt) latest=values[i]; } }
    return latest === undefined ? undefined : this.copyEntry(latest);
  }
  /**
   * 读取条目列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param chatId 目标聊天标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listEntries(chatId?: string): Array<MemoryEntry> {
    const result=new Array<MemoryEntry>(); const values=Array.from(this.entries.values());
    for (let i=0;i<values.length;i++) { if (chatId===undefined||values[i].chatId===chatId) result.push(this.copyEntry(values[i])); }
    return result;
  }
  /**
   * 删除记忆。
   * @param entryId 条目标识。
   */
  removeEntry(entryId: string): void {
    if (this.entries.get(entryId)===undefined) throw new Error(`记忆条目未找到: ${entryId}`);
    this.entries.delete(entryId);
  }
  /**
   * 根据入参构建Prompt Injection 值，仅生成数据结构，不直接执行外部请求。
   * @param chatId 目标聊天标识。

   * @returns 构建好的请求、Prompt 或中间数据。
   */
  buildPromptInjection(chatId: string, maxEntries: number): string {
    const chatEntries=new Array<MemoryEntry>(); const values=Array.from(this.entries.values());
    for (let i=0;i<values.length;i++) { if (values[i].chatId===chatId) chatEntries.push(values[i]); }
    chatEntries.sort((a,b)=>b.createdAt-a.createdAt);
    const selected=chatEntries.slice(0, Math.min(chatEntries.length, maxEntries));
    const parts=new Array<string>();
    for (let i=0;i<selected.length;i++) { parts.push(`[记忆] ${selected[i].summary}`); }
    return parts.join('\n');
  }
  /**
   * 导出数据，用于备份、迁移或与 SillyTavern 数据互通。
   * @returns 可持久化或可传输的导出内容。
   */
  exportData(): MemoryExportData { return { entries: this.listEntries() }; }
  /**
   * 从外部数据导入Data 值，转换为当前运行时的数据结构。
   * @param data 导入或恢复使用的序列化数据。
   */
  importData(data: MemoryExportData): void {
    for (let i=0;i<data.entries.length;i++) {
      const entry = this.copyEntry(data.entries[i]);
      this.entries.set(entry.entryId, entry);
      this.counter = Math.max(this.counter, this.parseCounter(entry.entryId));
    }
  }

  /**
   * 复制Entry 值，避免外部修改内部状态。
   * @param entry 条目记录。
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
   * 解析Counter，非法输入会返回失败标记或空结果。
   * @param entryId 条目标识。
   */
  private parseCounter(entryId: string): number {
    if (!entryId.startsWith('memory-')) {
      return 0;
    }
    const parsed = Number(entryId.substring(7));
    return parsed > 0 ? parsed : 0;
  }
}
