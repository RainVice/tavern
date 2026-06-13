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

export class AttachmentRuntime {
  private events: EventBus;
  private attachments: Map<string, AttachmentRecord> = new Map<string, AttachmentRecord>();
  private bindings: Map<string, Array<AttachmentBindingRecord>> = new Map<string, Array<AttachmentBindingRecord>>();

  constructor(events: EventBus) {
    this.events = events;
  }

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

  getAttachment(attachmentId: string): AttachmentRecord {
    return this.cloneAttachment(this.requireAttachment(attachmentId));
  }

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

  listBindings(attachmentId: string): Array<AttachmentBindingRecord> {
    const records = this.bindings.get(attachmentId);
    if (records === undefined) {
      return new Array<AttachmentBindingRecord>();
    }
    return this.cloneBindings(records);
  }

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

  markCaptionResult(attachmentId: string, captionText: string): AttachmentRecord {
    const attachment = this.requireAttachment(attachmentId);
    attachment.captionText = captionText;
    attachment.updatedAt = Date.now();
    this.publishUpdated(attachment);
    return this.cloneAttachment(attachment);
  }

  markTranslationResult(attachmentId: string, targetLanguage: string, translationText: string): AttachmentRecord {
    const attachment = this.requireAttachment(attachmentId);
    attachment.translationText = translationText;
    attachment.metadataJson = this.appendMetadata(attachment.metadataJson, 'translationTarget', targetLanguage);
    attachment.updatedAt = Date.now();
    this.publishUpdated(attachment);
    return this.cloneAttachment(attachment);
  }

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

  exportAttachment(attachmentId: string): AttachmentExportData {
    const data: AttachmentExportData = {
      attachment: this.cloneAttachment(this.requireAttachment(attachmentId)),
      bindings: this.cloneBindings(this.listBindings(attachmentId)),
    };
    return data;
  }

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

  private requireAttachment(attachmentId: string): AttachmentRecord {
    const attachment = this.attachments.get(attachmentId);
    if (attachment === undefined || attachment.deleted) {
      throw new Error(`Attachment not found: ${attachmentId}`);
    }
    return attachment;
  }

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
    if (attachment.translationText.length > 0) {
      return attachment.translationText;
    }
    return attachment.content;
  }

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

  private cloneBindings(bindings: Array<AttachmentBindingRecord>): Array<AttachmentBindingRecord> {
    const cloned = new Array<AttachmentBindingRecord>();
    for (let index = 0; index < bindings.length; index += 1) {
      cloned.push(this.cloneBinding(bindings[index]));
    }
    return cloned;
  }

  private cloneBinding(binding: AttachmentBindingRecord): AttachmentBindingRecord {
    return {
      attachmentId: binding.attachmentId,
      targetType: binding.targetType,
      targetId: binding.targetId,
      createdAt: binding.createdAt,
    };
  }

  private publishUpdated(attachment: AttachmentRecord): void {
    const payload: AttachmentUpdatedPayload = {
      attachment: this.cloneAttachment(attachment),
    };
    this.events.publish<AttachmentUpdatedPayload>('attachment.updated', payload);
  }
}
