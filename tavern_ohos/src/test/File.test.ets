import { describe, it, expect } from '@ohos/hypium';
import {
  AttachmentRuntime,
  DataBankRuntime,
  EventBus,
  FileRuntime,
  InMemoryFileStore,
  type FileDeletedPayload,
  type FileRecord,
  type FileUploadedPayload,
  type FileUploadParams,
  type FileVerifyResult,
  type RuntimeEvent,
  type TavernFileStore,
} from '../../Index';

export default function fileUnitTest() {
  describe('file runtime', () => {
    it('uploads files, sanitizes names, reads content, and verifies paths', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = makeRuntime(files, bus);
      const uploaded = new Array<string>();
      bus.subscribe<FileUploadedPayload>('file.uploaded', (event: RuntimeEvent<FileUploadedPayload>) => {
        uploaded.push(`${event.payload.file.id}:${event.payload.file.fileName}`);
      });

      // 记录副本。
      const record: FileRecord = await runtime.uploadFile(makeFile('file-1', '../report.md'));
      const content = await runtime.readFileContent('file-1');
      await files.writeText('tavern-data/users/default/assets/files_evil/report.md', 'outside', false);
      const verified: Array<FileVerifyResult> = await runtime.verifyFiles([
        record.path,
        'tavern-data/users/default/assets/files/missing.txt',
        'tavern-data/users/default/assets/files_evil/report.md',
        `../../${record.path}`,
      ]);

      expect(record.fileName).assertEqual('..~2freport.md');
      expect(record.path).assertEqual('tavern-data/users/default/assets/files/..~2freport.md');
      expect(content).assertEqual('file-data');
      expect(verified[0].exists).assertTrue();
      expect(verified[1].exists).assertFalse();
      expect(verified[2].exists).assertFalse();
      expect(verified[3].exists).assertFalse();
      expect(uploaded[0]).assertEqual('file-1:..~2freport.md');
    });

    it('creates attachments and DataBank documents from uploaded files', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      const attachments = new AttachmentRuntime(bus);
      const dataBank = new DataBankRuntime(files, bus);
      // 运行时实例。
      const runtime = new FileRuntime(files, bus, attachments, dataBank);
      const file = await runtime.uploadFile(makeAttachedDataBankFile());
      const bound = attachments.listAttachmentsForTarget('message', 'chat-1:2');
      const document = await dataBank.getDocument('doc-1');

      expect(file.attachmentId).assertEqual('att-file-1');
      expect(file.dataBankDocumentId).assertEqual('doc-1');
      expect(bound.length).assertEqual(1);
      expect(bound[0].fileName).assertEqual('note.txt');
      expect(document === undefined).assertFalse();
      expect(document!.fileName).assertEqual('note.txt');
    });

    it('安全序列化附件中的 fileId 元数据', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      const attachments = new AttachmentRuntime(bus);
      // 运行时实例。
      const runtime = new FileRuntime(files, bus, attachments, new DataBankRuntime(files, bus));
      // 调用参数。
      const params = makeFile('file-"quoted', 'quote.txt');
      params.attachmentId = 'att-quoted';
      params.attachmentTargetType = 'message';
      params.attachmentTargetId = 'chat-1:3';

      await runtime.uploadFile(params);
      const metadata = JSON.parse(attachments.getAttachment('att-quoted').metadataJson) as Record<string, string>;

      expect(metadata['fileId']).assertEqual('file-"quoted');
    });

    it('deletes files and linked runtime records', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      const attachments = new AttachmentRuntime(bus);
      const dataBank = new DataBankRuntime(files, bus);
      // 运行时实例。
      const runtime = new FileRuntime(files, bus, attachments, dataBank);
      const deleted = new Array<string>();
      bus.subscribe<FileDeletedPayload>('file.deleted', (event: RuntimeEvent<FileDeletedPayload>) => {
        deleted.push(`${event.payload.fileId}:${event.payload.path}`);
      });
      const file = await runtime.uploadFile(makeAttachedDataBankFile());
      await runtime.deleteFile(file.id);
      const verified: Array<FileVerifyResult> = await runtime.verifyFiles([file.path]);
      const document = await dataBank.getDocument('doc-1');
      const attachmentsAfterDelete = attachments.listAttachments();

      expect(verified[0].exists).assertFalse();
      expect(document === undefined).assertTrue();
      expect(attachmentsAfterDelete.length).assertEqual(0);
      expect(deleted[0]).assertEqual('file-2:tavern-data/users/default/assets/files/note.txt');
    });
  });
}

/**
 * 封装单元测试中的 makeRuntime 步骤，供公开方法复用。
 * @param files 文件存储适配器。
 * @param bus 事件总线实例。
 */
function makeRuntime(files: TavernFileStore, bus: EventBus): FileRuntime {
  return new FileRuntime(files, bus, new AttachmentRuntime(bus), new DataBankRuntime(files, bus));
}

/**
 * 封装单元测试中的 makeFile 步骤，供公开方法复用。
 * @param id 唯一标识。
 * @param fileName file 名称。
 */
function makeFile(id: string, fileName: string): FileUploadParams {
  return {
    id: id,
    fileName: fileName,
    mimeType: 'text/markdown',
    content: 'file-data',
    attachmentId: '',
    attachmentTargetType: '',
    attachmentTargetId: '',
    includeInPrompt: false,
    includeInRag: false,
    dataBankDocumentId: '',
    dataBankScope: '',
    dataBankTags: [],
    metadataJson: '{"source":"test"}',
  };
}

/**
 * 封装单元测试中的 makeAttachedDataBankFile 步骤，供公开方法复用。
 */
function makeAttachedDataBankFile(): FileUploadParams {
  const params = makeFile('file-2', 'note.txt');
  params.mimeType = 'text/plain';
  params.attachmentId = 'att-file-1';
  params.attachmentTargetType = 'message';
  params.attachmentTargetId = 'chat-1:2';
  params.includeInPrompt = true;
  params.includeInRag = true;
  params.dataBankDocumentId = 'doc-1';
  params.dataBankScope = 'chat';
  params.dataBankTags = ['upload', 'note'];
  return params;
}
