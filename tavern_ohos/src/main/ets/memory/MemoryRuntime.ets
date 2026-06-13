import { EventBus } from '../runtime/EventBus';
import type { MemoryEntry, MemoryExportData, MemoryExtractedPayload } from './MemoryModels';

export class MemoryRuntime {
  private events: EventBus; private entries: Map<string,MemoryEntry>=new Map(); private counter=0;
  constructor(events: EventBus) { this.events=events; }
  // 创建记忆条目
  createEntry(chatId: string, summary: string, keyPoints: Array<string>, originalMessages: Array<string>, tokenEstimate: number): MemoryEntry {
    this.counter+=1; const entryId=`memory-${this.counter}`; const now=Date.now();
    const entry: MemoryEntry = { entryId, chatId, summary, keyPoints: keyPoints.slice(), originalMessages: originalMessages.slice(), tokenEstimate, createdAt: now, updatedAt: now };
    this.entries.set(entryId, this.copyEntry(entry));
    this.events.publish<MemoryExtractedPayload>('memory.extracted', { entry: this.copyEntry(entry) });
    return this.copyEntry(entry);
  }
  // 获取最新记忆
  getLatestEntry(chatId: string): MemoryEntry|undefined {
    let latest: MemoryEntry|undefined=undefined; const values=Array.from(this.entries.values());
    for (let i=0;i<values.length;i++) { if (values[i].chatId===chatId) { if (latest===undefined||values[i].createdAt>latest.createdAt) latest=values[i]; } }
    return latest === undefined ? undefined : this.copyEntry(latest);
  }
  // 列出所有记忆
  listEntries(chatId?: string): Array<MemoryEntry> {
    const result=new Array<MemoryEntry>(); const values=Array.from(this.entries.values());
    for (let i=0;i<values.length;i++) { if (chatId===undefined||values[i].chatId===chatId) result.push(this.copyEntry(values[i])); }
    return result;
  }
  // 删除记忆
  removeEntry(entryId: string): void {
    if (this.entries.get(entryId)===undefined) throw new Error(`记忆条目未找到: ${entryId}`);
    this.entries.delete(entryId);
  }
  // 构建 Prompt 注入
  buildPromptInjection(chatId: string, maxEntries: number): string {
    const chatEntries=new Array<MemoryEntry>(); const values=Array.from(this.entries.values());
    for (let i=0;i<values.length;i++) { if (values[i].chatId===chatId) chatEntries.push(values[i]); }
    chatEntries.sort((a,b)=>b.createdAt-a.createdAt);
    const selected=chatEntries.slice(0, Math.min(chatEntries.length, maxEntries));
    const parts=new Array<string>();
    for (let i=0;i<selected.length;i++) { parts.push(`[记忆] ${selected[i].summary}`); }
    return parts.join('\n');
  }
  exportData(): MemoryExportData { return { entries: this.listEntries() }; }
  importData(data: MemoryExportData): void {
    for (let i=0;i<data.entries.length;i++) {
      const entry = this.copyEntry(data.entries[i]);
      this.entries.set(entry.entryId, entry);
      this.counter = Math.max(this.counter, this.parseCounter(entry.entryId));
    }
  }

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

  private parseCounter(entryId: string): number {
    if (!entryId.startsWith('memory-')) {
      return 0;
    }
    const parsed = Number(entryId.substring(7));
    return parsed > 0 ? parsed : 0;
  }
}
