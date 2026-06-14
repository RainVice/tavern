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
 * 提供附件相关的无 UI 运行时能力，负责附件的全生命周期管理（创建、查询、绑定、标注、导入导出、软删除），
 * 通过事件总线向外部模块发布附件变更通知，
 * 用于在消息附件管理、角色附件关联、多模态内容处理等流程中驱动附件数据的读写和状态同步。
 */
export class AttachmentRuntime {
  /**
   * 事件总线实例，用于在附件创建、更新、删除等操作完成后发布事件，供 UI 或其他 Runtime 模块监听响应。
   */
  private events: EventBus;
  /**
   * 附件记录映射表，以附件 id 为键，用于在附件管理各流程中快速存取附件元信息。
   */
  private attachments: Map<string, AttachmentRecord> = new Map<string, AttachmentRecord>();
  /**
   * 附件绑定关系映射表，以附件 id 为键，值为该附件的绑定列表，
   * 用于在绑定查询和目标附件查询流程中快速获取附件与目标对象的关系。
   */
  private bindings: Map<string, Array<AttachmentBindingRecord>> = new Map<string, Array<AttachmentBindingRecord>>();

  /**
   * 初始化当前运行时实例，在模块加载时调用，建立与事件总线的连接。
   * @param events 事件总线实例，用于在附件各生命周期阶段发布事件通知外部模块。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 创建新的附件记录，存入内存映射表并发布更新事件，
   * 用于在用户添加附件（如图片、文件）时初始化附件数据并通知监听方。
   * @param params 附件创建参数，包含标识、类型、文件名、内容等，由调用方传入以确定附件的属性和行为。
   * @returns 新创建的附件记录副本。
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
   * 根据附件 id 获取附件记录副本，
   * 用于在外部模块或 UI 查询附件详情时获取完整的附件元信息。
   * @param attachmentId 目标附件标识，用于在附件映射表中检索。
   * @returns 附件记录深拷贝。
   */
  getAttachment(attachmentId: string): AttachmentRecord {
    return this.cloneAttachment(this.requireAttachment(attachmentId));
  }

  /**
   * 获取所有未删除的附件记录深拷贝列表，
   * 用于在附件管理 UI 或数据导出流程中列出全部可用附件。
   * @returns 附件记录列表。
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
   * 将附件绑定到指定的目标对象（如角色、消息），并发布添加事件，
   * 用于在用户向角色或个人资料添加附件时建立附件与目标对象的关联关系。
   * @param attachmentId 目标附件标识，用于在附件映射表中定位要绑定的附件。
   * @param targetType 目标对象类型（如 character、message），用于确定绑定的目标模块。
   * @param targetId 目标对象标识，用于在目标对象上关联附件。
   * @returns 创建的绑定关系记录副本。
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
   * 获取指定附件的绑定关系列表（深拷贝），
   * 用于在查询附件关联到哪些目标对象时获取完整的绑定信息。
   * @param attachmentId 目标附件标识，用于在绑定映射表中检索。
   * @returns 绑定关系记录列表。
   */
  listBindings(attachmentId: string): Array<AttachmentBindingRecord> {
    const records = this.bindings.get(attachmentId);
    if (records === undefined) {
      return new Array<AttachmentBindingRecord>();
    }
    return this.cloneBindings(records);
  }

  /**
   * 根据目标类型和目标标识查找所有绑定的附件记录，
   * 用于在角色详情页或消息上下文构建流程中获取与指定目标关联的所有附件。
   * @param targetType 目标对象类型，用于在绑定查询中筛选特定模块（如 character、message）的附件。
   * @param targetId 目标对象标识，用于在绑定查询中定位特定目标的附件。
   * @returns 匹配的附件记录列表（深拷贝）。
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
   * 更新附件的图片描述（caption）结果，刷新更新时间并发布更新事件，
   * 用于在图片描述（caption）服务返回结果后存储描述文本供 Prompt 构建使用。
   * @param attachmentId 目标附件标识，用于在附件映射表中定位要更新的附件。
   * @param captionText 图片描述文本，由 caption 服务返回后传入。
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
   * 更新附件的翻译结果，同时将目标语言信息写入元数据，
   * 用于在翻译服务返回结果后存储翻译文本供多语言对话场景使用。
   * @param attachmentId 目标附件标识，用于在附件映射表中定位要更新的附件。
   * @param targetLanguage 翻译目标语言，写入元数据供后续查询。
   * @param translationText 翻译后的文本，由翻译服务返回后传入。
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
   * 获取标记为包含在 Prompt 中的附件摘要列表，
   * 用于在 Prompt 组装流程中收集需要作为上下文提供给模型的附件内容。
   * @returns 符合 Prompt 构建需求的附件摘要记录列表。
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
   * 获取标记为纳入 RAG 的附件记录列表，
   * 用于在知识检索流程中收集需要建立索引的附件文档。
   * @returns 符合 RAG 条件的附件记录。
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
   * 导出指定附件及其绑定关系，用于备份或数据迁移，
   * 在用户执行导出操作或外部系统请求数据互通时调用。
   * @param attachmentId 目标附件标识，用于定位要导出的附件。
   * @returns 包含附件记录和绑定关系的导出数据。
   */
  exportAttachment(attachmentId: string): AttachmentExportData {
    const data: AttachmentExportData = {
      attachment: this.cloneAttachment(this.requireAttachment(attachmentId)),
      bindings: this.cloneBindings(this.listBindings(attachmentId)),
    };
    return data;
  }

  /**
   * 从外部数据导入附件记录和绑定关系，可用于数据恢复，
   * 在应用启动还原备份或从外部数据源同步附件时调用。
   * @param data 包含附件和绑定关系的导出数据，由外部备份文件解析后传入。
   * @param newAttachmentId 导入后使用的新附件标识（允许重命名），避免与现有记录冲突。
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
   * 将附件标记为已删除，清除绑定关系并发布删除事件，
   * 用于在用户删除附件时执行软删除操作，保留记录但使其不可见。
   * @param attachmentId 目标附件标识，用于定位要删除的附件。
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
   * 获取附件记录，不存在或已删除时抛出异常。
   * @param attachmentId 目标附件标识。
   * @returns 附件记录（内部引用）。
   */
  private requireAttachment(attachmentId: string): AttachmentRecord {
    const attachment = this.attachments.get(attachmentId);
    if (attachment === undefined || attachment.deleted) {
      throw new Error(`Attachment not found: ${attachmentId}`);
    }
    return attachment;
  }

  /**
   * 获取指定附件的绑定关系列表，不存在时抛出异常。
   * @param attachmentId 目标附件标识。
   * @returns 绑定关系列表（内部引用）。
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
   * 向现有元数据 JSON 中追加一个键值对，保留已有字段。
   * @param metadataJson 原始 metadata JSON 字符串。
   * @param key 要追加的键名。
   * @param value 要追加的键值。
   * @returns 更新后的 metadata JSON 字符串。
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
   * 深拷贝 AttachmentRecord，防止外部代码修改内部状态。
   * @param attachment 要复制的附件记录。
   * @returns 深拷贝后的附件记录。
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
   * 深拷贝绑定关系列表，防止外部代码修改内部状态。
   * @param bindings 要复制的绑定关系列表。
   * @returns 深拷贝后的绑定关系列表。
   */
  private cloneBindings(bindings: Array<AttachmentBindingRecord>): Array<AttachmentBindingRecord> {
    const cloned = new Array<AttachmentBindingRecord>();
    for (let index = 0; index < bindings.length; index += 1) {
      cloned.push(this.cloneBinding(bindings[index]));
    }
    return cloned;
  }

  /**
   * 深拷贝单个绑定关系记录。
   * @param binding 要复制的绑定关系。
   * @returns 深拷贝后的绑定关系。
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
   * 发布附件更新事件，通知宿主或其他 Runtime 状态变化。
   * @param attachment 被更新的附件记录。
   */
  private publishUpdated(attachment: AttachmentRecord): void {
    const payload: AttachmentUpdatedPayload = {
      attachment: this.cloneAttachment(attachment),
    };
    this.events.publish<AttachmentUpdatedPayload>('attachment.updated', payload);
  }
}
