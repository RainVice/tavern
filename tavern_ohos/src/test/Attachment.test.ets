import { describe, it, expect } from '@ohos/hypium';
import {
  AttachmentRuntime,
  EventBus,
  type AttachmentAddedPayload,
  type AttachmentBindingRecord,
  type AttachmentCreateParams,
  type AttachmentExportData,
  type AttachmentPromptRecord,
  type AttachmentRecord,
  type RuntimeEvent,
} from '../../Index';

export default function attachmentUnitTest() {
  describe('attachment runtime', () => {
    it('creates attachments for prompt, rag, caption, and translation flows', 0, () => {
      const runtime = new AttachmentRuntime(new EventBus());
      const text = runtime.createAttachment(makeAttachment('att-1', 'text', 'notes.md', 'text/markdown', 'Hello note'));
      const image = runtime.createAttachment(makeAttachment('att-2', 'generated_image', 'image.png', 'image/png', ''));
      runtime.markCaptionResult(image.id, 'A bridge screenshot.');
      runtime.markTranslationResult(text.id, 'zh-CN', '你好笔记');

      const promptRecords: Array<AttachmentPromptRecord> = runtime.listPromptAttachments();
      const ragRecords: Array<AttachmentRecord> = runtime.listRagDocuments();

      expect(promptRecords.length).assertEqual(2);
      expect(promptRecords[0].content).assertEqual('Hello note');
      expect(promptRecords[1].content).assertEqual('A bridge screenshot.');
      expect(ragRecords.length).assertEqual(1);
      expect(runtime.getAttachment('att-1').translationText).assertEqual('你好笔记');
    });

    it('binds attachments to messages, characters, chats, personas, databank, and plugins', 0, () => {
      const bus = new EventBus();
      const runtime = new AttachmentRuntime(bus);
      const added = new Array<string>();
      bus.subscribe<AttachmentAddedPayload>('attachment.added', (event: RuntimeEvent<AttachmentAddedPayload>) => {
        added.push(`${event.payload.targetType}:${event.payload.targetId}:${event.payload.attachmentId}`);
      });
      runtime.createAttachment(makeAttachment('att-3', 'audio', 'voice.wav', 'audio/wav', ''));

      runtime.bindAttachment('att-3', 'message', 'msg-1');
      runtime.bindAttachment('att-3', 'character', 'char-1');
      runtime.bindAttachment('att-3', 'chat', 'chat-1');
      runtime.bindAttachment('att-3', 'persona', 'persona-1');
      runtime.bindAttachment('att-3', 'databank', 'doc-1');
      runtime.bindAttachment('att-3', 'plugin', 'plugin-1');
      const bindings: Array<AttachmentBindingRecord> = runtime.listBindings('att-3');

      expect(bindings.length).assertEqual(6);
      expect(runtime.listAttachmentsForTarget('message', 'msg-1').length).assertEqual(1);
      expect(runtime.listAttachmentsForTarget('plugin', 'plugin-1')[0].mimeType).assertEqual('audio/wav');
      expect(added.length).assertEqual(6);
      expect(added[0]).assertEqual('message:msg-1:att-3');
    });

    it('exports attachments and deletes records with bindings', 0, () => {
      const runtime = new AttachmentRuntime(new EventBus());
      runtime.createAttachment(makeAttachment('att-4', 'json', 'data.json', 'application/json', '{"ok":true}'));
      runtime.bindAttachment('att-4', 'message', 'msg-2');

      const exported: AttachmentExportData = runtime.exportAttachment('att-4');
      const imported = new AttachmentRuntime(new EventBus());
      const restored = imported.importAttachment(exported, 'att-5');
      runtime.deleteAttachment('att-4');

      expect(exported.bindings.length).assertEqual(1);
      expect(restored.id).assertEqual('att-5');
      expect(imported.listBindings('att-5').length).assertEqual(1);
      expect(runtime.listAttachments().length).assertEqual(0);
      expect(runtime.listAttachmentsForTarget('message', 'msg-2').length).assertEqual(0);
    });

    it('rejects importing an attachment over an existing id', 0, () => {
      const runtime = new AttachmentRuntime(new EventBus());
      runtime.createAttachment(makeAttachment('att-existing', 'text', 'old.txt', 'text/plain', 'old'));
      const exported: AttachmentExportData = runtime.exportAttachment('att-existing');

      let thrown = false;
      try {
        runtime.importAttachment(exported, 'att-existing');
      } catch (error) {
        thrown = true;
      }

      expect(thrown).assertTrue();
      expect(runtime.getAttachment('att-existing').fileName).assertEqual('old.txt');
    });

    it('does not reuse attachment added payload across event names', 0, () => {
      const bus = new EventBus();
      const runtime = new AttachmentRuntime(bus);
      const names = new Array<string>();
      bus.subscribe<AttachmentAddedPayload>('attachment.added', (event: RuntimeEvent<AttachmentAddedPayload>) => {
        event.payload.attachment.fileName = 'first-event.txt';
      });
      bus.subscribe<AttachmentAddedPayload>('message.attachment.added', (event: RuntimeEvent<AttachmentAddedPayload>) => {
        names.push(event.payload.attachment.fileName);
      });
      runtime.createAttachment(makeAttachment('att-cross-event', 'text', 'clean.txt', 'text/plain', 'clean'));

      runtime.bindAttachment('att-cross-event', 'message', 'msg-cross-event');

      expect(names.length).assertEqual(1);
      expect(names[0]).assertEqual('clean.txt');
    });

    it('does not expose internal attachment or binding records', 0, () => {
      const bus = new EventBus();
      const runtime = new AttachmentRuntime(bus);
      bus.subscribe<AttachmentAddedPayload>('attachment.added', (event: RuntimeEvent<AttachmentAddedPayload>) => {
        event.payload.attachment.fileName = 'event-mutated.txt';
      });

      const attachment = runtime.createAttachment(makeAttachment('att-copy', 'text', 'copy.md', 'text/markdown', 'copy'));
      attachment.fileName = 'external.md';
      expect(runtime.getAttachment('att-copy').fileName).assertEqual('copy.md');

      const binding = runtime.bindAttachment('att-copy', 'message', 'msg-copy');
      binding.targetId = 'external-message';
      const bindings = runtime.listBindings('att-copy');
      bindings[0].targetId = 'list-message';
      expect(runtime.listBindings('att-copy')[0].targetId).assertEqual('msg-copy');
      expect(runtime.listAttachmentsForTarget('message', 'msg-copy')[0].fileName).assertEqual('copy.md');
    });

    it('安全序列化翻译目标元数据', 0, () => {
      const runtime = new AttachmentRuntime(new EventBus());
      runtime.createAttachment(makeAttachment('att-json', 'text', 'note.md', 'text/markdown', 'hello'));

      const updated = runtime.markTranslationResult('att-json', 'zh-"CN', '你好');
      const metadata = JSON.parse(updated.metadataJson) as Record<string, string>;

      expect(metadata['translationTarget']).assertEqual('zh-"CN');
      expect(updated.translationText).assertEqual('你好');
    });
  });
}

function makeAttachment(id: string, kind: string, fileName: string, mimeType: string, content: string): AttachmentCreateParams {
  return {
    id: id,
    kind: kind,
    fileName: fileName,
    mimeType: mimeType,
    storagePath: `attachments/${id}/${fileName}`,
    content: content,
    includeInPrompt: true,
    includeInRag: kind === 'text' || kind === 'json',
    captionText: '',
    translationText: '',
    metadataJson: '{}',
  };
}
