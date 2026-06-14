import { EventBus } from '../runtime/EventBus';
import type { MemoryEntry, MemoryExportData, MemoryExtractedPayload } from './MemoryModels';

/**
 * 提供聊天记忆相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 在 AI 对话过程中维护长程记忆条目，支持创建、查询、删除、构建提示词注入文本，
 * 以及导入导出用于数据迁移。通过 EventBus 发布 memory.extracted 事件通知其他模块记忆更新。
 */
export class MemoryRuntime {
  /**
   * 事件总线，用于发布记忆提取事件。
   */
  private events: EventBus; private entries: Map<string,MemoryEntry>=new Map(); private counter=0;
  /**
   * 初始化当前运行时实例。
   * @param events 用于发布记忆提取事件的事件总线，createEntry 完成后发送 memory.extracted 事件供其他模块响应。
   */
  constructor(events: EventBus) { this.events=events; }
  /**
   * 创建新的聊天记忆条目，生成唯一标识，写入内存映射，并发布记忆提取事件。
   * 在 AI 回复生成完成后由外部调用，用于总结对话历史形成长期记忆。
   * @param chatId 该记忆所属的聊天标识，用于后续按聊天过滤查询（getLatestEntry / listEntries）。
   * @param summary 记忆摘要文本，在 buildPromptInjection 中被格式化后注入 AI 提示词，作为上下文的一部分。
   * @param keyPoints 记忆的关键要点列表，用于快速理解记忆的核心内容。
   * @param originalMessages 生成记忆所依据的原始消息列表，用于追溯记忆的来源或后续重新生成摘要。
   * @param tokenEstimate 该记忆预估的 token 数量，用于在注入提示词前计算上下文窗口是否足够。
   * @returns 新创建的记忆条目副本，调用方可用于 UI 展示或后续的提示词注入构建。
   */
  createEntry(chatId: string, summary: string, keyPoints: Array<string>, originalMessages: Array<string>, tokenEstimate: number): MemoryEntry {
    this.counter+=1; const entryId=`memory-${this.counter}`; const now=Date.now();
    const entry: MemoryEntry = { entryId, chatId, summary, keyPoints: keyPoints.slice(), originalMessages: originalMessages.slice(), tokenEstimate, createdAt: now, updatedAt: now };
    this.entries.set(entryId, this.copyEntry(entry));
    this.events.publish<MemoryExtractedPayload>('memory.extracted', { entry: this.copyEntry(entry) });
    return this.copyEntry(entry);
  }
  /**
   * 获取指定聊天中最新（创建时间最晚）的记忆条目，不存在时返回 undefined。
   * 在构建提示词注入文本时由 buildPromptInjection 或外部直接调用，
   * 用于获取单个最新的记忆上下文。
   * @param chatId 要查询的聊天标识，用于筛选属于该聊天的记忆条目。
   * @returns 最新的记忆条目副本，调用方可安全读取修改，不会影响内部状态。
   */
  getLatestEntry(chatId: string): MemoryEntry|undefined {
    let latest: MemoryEntry|undefined=undefined; const values=Array.from(this.entries.values());
    for (let i=0;i<values.length;i++) { if (values[i].chatId===chatId) { if (latest===undefined||values[i].createdAt>=latest.createdAt) latest=values[i]; } }
    return latest === undefined ? undefined : this.copyEntry(latest);
  }
  /**
   * 获取指定聊天的所有记忆条目列表，每个条目均为副本。不指定聊天时返回所有条目。
   * 用于管理界面展示记忆列表，或由 buildPromptInjection 获取全部记忆以构建上下文注入文本。
   * @param chatId 可选的聊天标识，传入后仅返回该聊天的条目；不传则返回全部条目的完整列表。
   * @returns 记忆条目副本数组，调用方修改不影响内部状态。
   */
  listEntries(chatId?: string): Array<MemoryEntry> {
    const result=new Array<MemoryEntry>(); const values=Array.from(this.entries.values());
    for (let i=0;i<values.length;i++) { if (chatId===undefined||values[i].chatId===chatId) result.push(this.copyEntry(values[i])); }
    return result;
  }
  /**
   * 删除指定标识的记忆条目，条目不存在时抛出异常。
   * 由 UI 层或数据清理流程调用，用于移除不再需要的记忆记录。
   * @param entryId 要删除的记忆条目标识，格式为 "memory-{数字}"。
   */
  removeEntry(entryId: string): void {
    if (this.entries.get(entryId)===undefined) throw new Error(`记忆条目未找到: ${entryId}`);
    this.entries.delete(entryId);
  }
  /**
   * 构建用于注入到 AI 提示词中的记忆文本，按时间倒序选取最近若干条记忆的摘要拼接为纯文本。
   * 在生成 AI 回复前由系统提示词构建流程调用，
   * 将历史聊天记忆以 "[记忆] 摘要" 格式拼接到提示词中，为 AI 提供长期上下文。
   * @param chatId 要构建记忆的聊天标识，用于筛选属于该聊天的记忆条目。
   * @param maxEntries 最多包含的记忆条目数量，用于控制注入文本的长度，避免超出模型上下文窗口。
   * @returns 格式化后的记忆文本，每条以 "[记忆] 摘要" 格式呈现，用换行分隔。
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
   * 导出所有记忆条目，用于备份、迁移或与 SillyTavern 数据互通。
   * 返回的数据中包含 entries 数组，每条记录包含完整信息，可通过 importData 恢复内存状态。
   * @returns 包含所有记忆条目的导出数据对象，供调用方序列化后保存到文件系统或网络传输。
   */
  exportData(): MemoryExportData { return { entries: this.listEntries() }; }
  /**
   * 从外部导入记忆数据，将每条记忆转换为内部格式后写入内存，并同步自增计数器。
   * 在数据恢复或从其他 Tavern 实例迁移时调用，
   * 确保导入后的计数器不重复，可继续创建新条目。
   * @param data 要导入的记忆导出数据，通常由 exportData 生成或从文件系统读取。
   */
  importData(data: MemoryExportData): void {
    for (let i=0;i<data.entries.length;i++) {
      const entry = this.copyEntry(data.entries[i]);
      this.entries.set(entry.entryId, entry);
      this.counter = Math.max(this.counter, this.parseCounter(entry.entryId));
    }
  }

  /**
   * 深拷贝记忆条目，创建新对象和数组防止外部修改内部状态。
   * @param entry 要复制的记忆条目。
   * @returns 独立于原条目的副本。
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
   * 从条目 ID 中解析出自增计数器数值，用于在导入时保持计数器不重复。
   * @param entryId 格式为 "memory-{数字}" 的条目标识。
   * @returns 解析出的计数器值，无法解析时返回 0。
   */
  private parseCounter(entryId: string): number {
    if (!entryId.startsWith('memory-')) {
      return 0;
    }
    const parsed = Number(entryId.substring(7));
    return parsed > 0 ? parsed : 0;
  }
}
