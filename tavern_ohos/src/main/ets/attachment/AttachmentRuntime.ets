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
 * 提供附件相关的无界面运行时能力，负责附件记录与绑定关系的内存管理，以及事件的发布。
 */
export class AttachmentRuntime {
  /**
   * 事件总线，用于向系统广播附件状态变化。
   */
  private events: EventBus;
  /**
   * 附件记录的内存映射，键为附件标识。
   */
  private attachments: Map<string, AttachmentRecord> = new Map<string, AttachmentRecord>();
  /**
   * 附件绑定关系的内存映射，键为附件标识。
   */
  private bindings: Map<string, Array<AttachmentBindingRecord>> = new Map<string, Array<AttachmentBindingRecord>>();

  /**
   * 使用事件总线初始化运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建新的附件记录，写入内存并发布更新事件。
   * @param params 附件创建参数。
   * @returns 创建后的附件记录副本。
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
   * 根据标识读取附件记录，不存在时抛出错误。
   * @param attachmentId 附件标识。
   * @returns 附件记录副本。
   */
  getAttachment(attachmentId: string): AttachmentRecord {
    return this.cloneAttachment(this.requireAttachment(attachmentId));
  }

  /**
   * 读取所有非删除状态的附件记录。
   * @returns 附件记录副本列表。
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
   * 将附件绑定到指定作用域，并发布添加事件。
   * @param attachmentId 附件标识。
   * @param targetType 目标作用域类型。
   * @param targetId 目标作用域实体标识。
   * @returns 新建的绑定记录副本。
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
   * 读取指定附件的所有绑定记录。
   * @param attachmentId 附件标识。
   * @returns 绑定记录副本列表。
   */
  listBindings(attachmentId: string): Array<AttachmentBindingRecord> {
    const records = this.bindings.get(attachmentId);
    if (records === undefined) {
      return new Array<AttachmentBindingRecord>();
    }
    return this.cloneBindings(records);
  }

  /**
   * 查询指定目标作用域下绑定的所有附件记录。
   * @param targetType 目标作用域类型。
   * @param targetId 目标作用域实体标识。
   * @returns 附件记录副本列表。
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
   * 更新附件的图片描述文本，并发布更新事件。
   * @param attachmentId 附件标识。
   * @param captionText 新的描述文本。
   * @returns 更新后的附件记录副本。
   */
  markCaptionResult(attachmentId: string, captionText: string): AttachmentRecord {
    const attachment = this.requireAttachment(attachmentId);
    attachment.captionText = captionText;
    attachment.updatedAt = Date.now();
    this.publishUpdated(attachment);
    return this.cloneAttachment(attachment);
  }

  /**
   * 更新附件的翻译文本，同时在元数据中记录目标语言，并发布更新事件。
   * @param attachmentId 附件标识。
   * @param targetLanguage 翻译目标语言。
   * @param translationText 翻译后的文本内容。
   * @returns 更新后的附件记录副本。
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
   * 读取所有标记为纳入提示词构造的附件记录。
   * @returns 精简后的提示词附件记录列表。
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
   * 读取所有标记为纳入 RAG 检索的附件记录。
   * @returns 附件记录列表。
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
   * 导出指定附件及其绑定关系，用于数据备份或跨实例迁移。
   * @param attachmentId 附件标识。
   * @returns 附件导出数据包。
   */
  exportAttachment(attachmentId: string): AttachmentExportData {
    const data: AttachmentExportData = {
      attachment: this.cloneAttachment(this.requireAttachment(attachmentId)),
      bindings: this.cloneBindings(this.listBindings(attachmentId)),
    };
    return data;
  }

  /**
   * 从外部数据导入附件记录，并赋予新的标识。
   * @param data 待导入的附件数据包。
   * @param newAttachmentId 导入后的新附件标识。
   * @returns 导入后的附件记录副本。
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
   * 删除指定附件（逻辑删除），清理绑定关系并发布删除事件。
   * @param attachmentId 附件标识。
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
   * 读取必须存在的附件记录，缺失或已删除时抛出错误。
   * @param attachmentId 附件标识。
   * @returns 附件记录引用。
   */
  private requireAttachment(attachmentId: string): AttachmentRecord {
    const attachment = this.attachments.get(attachmentId);
    if (attachment === undefined || attachment.deleted) {
      throw new Error(`Attachment not found: ${attachmentId}`);
    }
    return attachment;
  }

  /**
   * 读取必须存在的绑定记录列表，缺失时抛出错误。
   * @param attachmentId 附件标识。
   * @returns 绑定记录列表引用。
   */
  private requireBindings(attachmentId: string): Array<AttachmentBindingRecord> {
    const records = this.bindings.get(attachmentId);
    if (records === undefined) {
      throw new Error(`Attachment bindings not found: ${attachmentId}`);
    }
    return records;
  }
  /**
   * 获取附件用于提示词构造的文本内容：优先取图注文本，否则取原始内容。
   */
  private promptContent(attachment: AttachmentRecord): string {
    if (attachment.captionText.length > 0) {
      return attachment.captionText;
    }
    return attachment.content;
  }

  /**
   * 向现有元数据 JSON 中追加键值对。
   * @param metadataJson 原始元数据 JSON 字符串。
   * @param key 要追加的键名。
   * @param value 要追加的字段值。
   * @returns 追加后的元数据 JSON 字符串。
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
   * 深度复制附件记录，防止外部修改影响内部状态。
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
   * 深度复制绑定记录列表，防止外部修改影响内部状态。
   * @returns 绑定记录副本列表。
   */
  private cloneBindings(bindings: Array<AttachmentBindingRecord>): Array<AttachmentBindingRecord> {
    const cloned = new Array<AttachmentBindingRecord>();
    for (let index = 0; index < bindings.length; index += 1) {
      cloned.push(this.cloneBinding(bindings[index]));
    }
    return cloned;
  }

  /**
   * 深度复制单条绑定记录，防止外部修改影响内部状态。
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
   * 发布附件更新事件，通知监听者状态已变化。
   */
  private publishUpdated(attachment: AttachmentRecord): void {
    const payload: AttachmentUpdatedPayload = {
      attachment: this.cloneAttachment(attachment),
    };
    this.events.publish<AttachmentUpdatedPayload>('attachment.updated', payload);
  }
}
