import { EventBus } from '../runtime/EventBus';
import type {
  AttachmentAddedPayload,
  AttachmentBindingRecord,
  AttachmentCreateParams,
  AttachmentDeletedPayload,
  AttachmentExportData,
  AttachmentPromptRecord,
  AttachmentRecord,
  AttachmentUpdatedPayload,
} from './AttachmentModels';

/**
 * 提供附件相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class AttachmentRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * attachments 列表，由当前实例内部维护。
   */
  private attachments: Map<string, AttachmentRecord> = new Map<string, AttachmentRecord>();
  /**
   * bindings 列表，由当前实例内部维护。
   */
  private bindings: Map<string, Array<AttachmentBindingRecord>> = new Map<string, Array<AttachmentBindingRecord>>();

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建新的附件记录，写入存储并返回副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
  createAttachment(params: AttachmentCreateParams): AttachmentRecord {
    const now = Date.now();
    const attachment: AttachmentRecord = {
      schemaVersion: 1,
      id: params.id,
      kind: params.kind,
      fileName: params.fileName,
      mimeType: params.mimeType,
      storagePath: params.storagePath,
      content: params.content,
      includeInPrompt: params.includeInPrompt,
      includeInRag: params.includeInRag,
      captionText: params.captionText,
      translationText: params.translationText,
      metadataJson: params.metadataJson,
      deleted: false,
      createdAt: now,
      updatedAt: now,
    };
    this.attachments.set(attachment.id, this.cloneAttachment(attachment));
    this.bindings.set(attachment.id, new Array<AttachmentBindingRecord>());
    this.publishUpdated(attachment);
    return this.cloneAttachment(attachment);
  }

  /**
   * 读取指定附件，不存在时抛出错误。
   * @param attachmentId 目标附件标识。
   * @returns 更新或读取后的记录副本。
   */
  getAttachment(attachmentId: string): AttachmentRecord {
    return this.cloneAttachment(this.requireAttachment(attachmentId));
  }

  /**
   * 读取Attachments列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listAttachments(): Array<AttachmentRecord> {
    const result = new Array<AttachmentRecord>();
    const attachments = Array.from(this.attachments.values());
    for (let index = 0; index < attachments.length; index += 1) {
      if (!attachments[index].deleted) {
        result.push(this.cloneAttachment(attachments[index]));
      }
    }
    return result;
  }

  /**
   * 把附件对象绑定到指定作用域，后续读取会按该绑定解析。
   * @param attachmentId 目标附件标识。

   * @param targetId 目标目标对象标识。
   */
  bindAttachment(attachmentId: string, targetType: string, targetId: string): AttachmentBindingRecord {
    const attachment = this.requireAttachment(attachmentId);
    const records = this.requireBindings(attachmentId);
    const binding: AttachmentBindingRecord = {
      attachmentId: attachmentId,
      targetType: targetType,
      targetId: targetId,
      createdAt: Date.now(),
    };
    records.push(binding);
    const payload: AttachmentAddedPayload = {
      attachmentId: attachmentId,
      targetType: targetType,
      targetId: targetId,
      attachment: this.cloneAttachment(attachment),
    };
    this.events.publish<AttachmentAddedPayload>('attachment.added', payload);
    this.events.publish<AttachmentAddedPayload>('message.attachment.added', {
      attachmentId: attachmentId,
      targetType: targetType,
      targetId: targetId,
      attachment: this.cloneAttachment(attachment),
    });
    return this.cloneBinding(binding);
  }

  /**
   * 读取Bindings列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param attachmentId 目标附件标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listBindings(attachmentId: string): Array<AttachmentBindingRecord> {
    const records = this.bindings.get(attachmentId);
    if (records === undefined) {
      return new Array<AttachmentBindingRecord>();
    }
    return this.cloneBindings(records);
  }

  /**
   * 读取AttachmentsForTarget列表，返回副本，调用方修改返回值不会直接改变内部状态。

   * @param targetId 目标目标对象标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listAttachmentsForTarget(targetType: string, targetId: string): Array<AttachmentRecord> {
    const result = new Array<AttachmentRecord>();
    const attachmentIds = Array.from(this.bindings.keys());
    for (let index = 0; index < attachmentIds.length; index += 1) {
      const records = this.requireBindings(attachmentIds[index]);
      for (let bindingIndex = 0; bindingIndex < records.length; bindingIndex += 1) {
        if (records[bindingIndex].targetType === targetType && records[bindingIndex].targetId === targetId) {
          result.push(this.cloneAttachment(this.requireAttachment(records[bindingIndex].attachmentId)));
        }
      }
    }
    return result;
  }

  /**
   * 更新图片描述Result状态，必要时写回存储并发布对应事件。
   * @param attachmentId 目标附件标识。
   */
  markCaptionResult(attachmentId: string, captionText: string): AttachmentRecord {
    const attachment = this.requireAttachment(attachmentId);
    attachment.captionText = captionText;
    attachment.updatedAt = Date.now();
    this.publishUpdated(attachment);
    return this.cloneAttachment(attachment);
  }

  /**
   * 更新翻译Result状态，必要时写回存储并发布对应事件。
   * @param attachmentId 目标附件标识。
   */
  markTranslationResult(attachmentId: string, targetLanguage: string, translationText: string): AttachmentRecord {
    const attachment = this.requireAttachment(attachmentId);
    attachment.translationText = translationText;
    attachment.metadataJson = this.appendMetadata(attachment.metadataJson, 'translationTarget', targetLanguage);
    attachment.updatedAt = Date.now();
    this.publishUpdated(attachment);
    return this.cloneAttachment(attachment);
  }

  /**
   * 读取PromptAttachments列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listPromptAttachments(): Array<AttachmentPromptRecord> {
    const result = new Array<AttachmentPromptRecord>();
    const attachments = this.listAttachments();
    for (let index = 0; index < attachments.length; index += 1) {
      const attachment = attachments[index];
      if (attachment.includeInPrompt) {
        const promptRecord: AttachmentPromptRecord = {
          attachmentId: attachment.id,
          kind: attachment.kind,
          fileName: attachment.fileName,
          mimeType: attachment.mimeType,
          content: this.promptContent(attachment),
        };
        result.push(promptRecord);
      }
    }
    return result;
  }

  /**
   * 读取RagDocuments列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listRagDocuments(): Array<AttachmentRecord> {
    const result = new Array<AttachmentRecord>();
    const attachments = this.listAttachments();
    for (let index = 0; index < attachments.length; index += 1) {
      if (attachments[index].includeInRag) {
        result.push(attachments[index]);
      }
    }
    return result;
  }

  /**
   * 导出附件，用于备份、迁移或与 SillyTavern 数据互通。
   * @param attachmentId 目标附件标识。
   * @returns 可持久化或可传输的导出内容。
   */
  exportAttachment(attachmentId: string): AttachmentExportData {
    const data: AttachmentExportData = {
      attachment: this.cloneAttachment(this.requireAttachment(attachmentId)),
      bindings: this.cloneBindings(this.listBindings(attachmentId)),
    };
    return data;
  }

  /**
   * 从外部数据导入Attachment 值，转换为当前运行时的数据结构。
   * @param data 导入或恢复使用的序列化数据。
   * @param newAttachmentId 目标新记录附件标识。
   * @returns 更新或读取后的记录副本。
   */
  importAttachment(data: AttachmentExportData, newAttachmentId: string): AttachmentRecord {
    if (this.attachments.has(newAttachmentId)) {
      throw new Error(`Attachment already exists: ${newAttachmentId}`);
    }
    const attachment = this.cloneAttachment(data.attachment);
    attachment.id = newAttachmentId;
    attachment.updatedAt = Date.now();
    this.attachments.set(newAttachmentId, attachment);
    const importedBindings = this.cloneBindings(data.bindings);
    for (let index = 0; index < importedBindings.length; index += 1) {
      importedBindings[index].attachmentId = newAttachmentId;
    }
    this.bindings.set(newAttachmentId, importedBindings);
    this.publishUpdated(attachment);
    return this.cloneAttachment(attachment);
  }

  /**
   * 删除指定附件，并清理相关索引或资源引用。
   * @param attachmentId 目标附件标识。
   */
  deleteAttachment(attachmentId: string): void {
    const attachment = this.requireAttachment(attachmentId);
    attachment.deleted = true;
    attachment.updatedAt = Date.now();
    this.bindings.set(attachmentId, new Array<AttachmentBindingRecord>());
    const payload: AttachmentDeletedPayload = {
      attachmentId: attachmentId,
    };
    this.events.publish<AttachmentDeletedPayload>('attachment.deleted', payload);
    this.events.publish<AttachmentDeletedPayload>('message.attachment.deleted', payload);
  }

  /**
   * 读取必须存在的Attachment 值，缺失时抛出错误。
   * @param attachmentId 目标附件标识。
   */
  private requireAttachment(attachmentId: string): AttachmentRecord {
    const attachment = this.attachments.get(attachmentId);
    if (attachment === undefined || attachment.deleted) {
      throw new Error(`Attachment not found: ${attachmentId}`);
    }
    return attachment;
  }

  /**
   * 读取必须存在的Bindings 列表，缺失时抛出错误。
   * @param attachmentId 目标附件标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private requireBindings(attachmentId: string): Array<AttachmentBindingRecord> {
    const records = this.bindings.get(attachmentId);
    if (records === undefined) {
      throw new Error(`Attachment bindings not found: ${attachmentId}`);
    }
    return records;
  }
  private promptContent(attachment: AttachmentRecord): string {
    if (attachment.captionText.length > 0) {
      return attachment.captionText;
    }
    return attachment.content;
  }

  /**
   * 追加Metadata 值，保留既有内容并写入新增片段。
   * @param metadataJson metadata JSON 字符串。
   * @param key 键名。
   * @param value 要保存或比较的字段值。
   */
  private appendMetadata(metadataJson: string, key: string, value: string): string {
    const metadata: Record<string, string> = {};
    if (metadataJson.length > 0 && metadataJson !== '{}') {
      try {
        const parsed = JSON.parse(metadataJson) as Record<string, string>;
        const keys = Object.keys(parsed);
        for (let index = 0; index < keys.length; index += 1) {
          metadata[keys[index]] = String(parsed[keys[index]]);
        }
      } catch (error) {
      }
    }
    metadata[key] = value;
    return JSON.stringify(metadata);
  }

  /**
   * 复制Attachment 值，避免外部修改内部状态。
   */
  private cloneAttachment(attachment: AttachmentRecord): AttachmentRecord {
    const cloned: AttachmentRecord = {
      schemaVersion: attachment.schemaVersion,
      id: attachment.id,
      kind: attachment.kind,
      fileName: attachment.fileName,
      mimeType: attachment.mimeType,
      storagePath: attachment.storagePath,
      content: attachment.content,
      includeInPrompt: attachment.includeInPrompt,
      includeInRag: attachment.includeInRag,
      captionText: attachment.captionText,
      translationText: attachment.translationText,
      metadataJson: attachment.metadataJson,
      deleted: attachment.deleted,
      createdAt: attachment.createdAt,
      updatedAt: attachment.updatedAt,
    };
    return cloned;
  }

  /**
   * 复制Bindings 列表，避免外部修改内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private cloneBindings(bindings: Array<AttachmentBindingRecord>): Array<AttachmentBindingRecord> {
    const cloned = new Array<AttachmentBindingRecord>();
    for (let index = 0; index < bindings.length; index += 1) {
      cloned.push(this.cloneBinding(bindings[index]));
    }
    return cloned;
  }

  /**
   * 复制Binding 值，避免外部修改内部状态。
   */
  private cloneBinding(binding: AttachmentBindingRecord): AttachmentBindingRecord {
    return {
      attachmentId: binding.attachmentId,
      targetType: binding.targetType,
      targetId: binding.targetId,
      createdAt: binding.createdAt,
    };
  }

  /**
   * 发布附件事件，把状态变化通知给宿主或其他 Runtime。

   */
  private publishUpdated(attachment: AttachmentRecord): void {
    const payload: AttachmentUpdatedPayload = {
      attachment: this.cloneAttachment(attachment),
    };
    this.events.publish<AttachmentUpdatedPayload>('attachment.updated', payload);
  }
}
