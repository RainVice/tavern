import { describe, it, expect } from '@ohos/hypium';
import {
  AttachmentRuntime,
  EventBus,
  ImageRuntime,
  InMemoryFileStore,
  ThumbnailRuntime,
  type ImageDeletedPayload,
  type ImageRecord,
  type ImageUploadParams,
  type ImageUploadedPayload,
  type RuntimeEvent,
  type TavernFileStore,
} from '../../Index';

export default function imageUnitTest() {
  describe('image runtime', () => {
    it('uploads images into character folders and creates thumbnails', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const thumbnails = new ThumbnailRuntime(files, bus);
      const runtime = new ImageRuntime(files, bus, thumbnails, new AttachmentRuntime(bus));
      const uploaded = new Array<string>();
      bus.subscribe<ImageUploadedPayload>('image.uploaded', (event: RuntimeEvent<ImageUploadedPayload>) => {
        uploaded.push(`${event.payload.image.folderName}:${event.payload.image.fileName}`);
      });

      const image: ImageRecord = await runtime.uploadImage(makeImage('img-1', 'portrait.png', 'Alice', 'avatar'));
      const saved = await files.readText('tavern-data/users/default/assets/images/Alice/portrait.png');
      const thumb = await thumbnails.getThumbnail('avatar', 'portrait.png');
      const index = await files.readText('tavern-data/users/default/assets/images/index.json');

      expect(image.path).assertEqual('tavern-data/users/default/assets/images/Alice/portrait.png');
      expect(image.thumbnailPath).assertEqual('tavern-data/users/default/assets/thumbnails/avatar/portrait.png');
      expect(saved).assertEqual('image-data');
      expect(thumb === undefined).assertFalse();
      expect(index.indexOf('portrait.png') >= 0).assertTrue();
      expect(uploaded[0]).assertEqual('Alice:portrait.png');
    });

    it('lists folders and images in stable order', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const runtime = new ImageRuntime(files, bus, new ThumbnailRuntime(files, bus), new AttachmentRuntime(bus));

      await runtime.uploadImage(makeImage('img-2', 'zeta.jpg', 'Bob', 'bg'));
      await runtime.uploadImage(makeImage('img-3', 'alpha.jpg', 'Bob', 'bg'));
      await runtime.uploadImage(makeImage('img-4', 'root.webp', '', ''));
      const folders = await runtime.listFolders();
      const bobImages = await runtime.listImages('Bob', 'asc');
      const rootImages = await runtime.listImages('', 'desc');

      expect(folders.length).assertEqual(1);
      expect(folders[0]).assertEqual('Bob');
      expect(bobImages[0].fileName).assertEqual('alpha.jpg');
      expect(bobImages[1].fileName).assertEqual('zeta.jpg');
      expect(rootImages[0].fileName).assertEqual('root.webp');
    });

    it('binds uploaded images as attachments and deletes cached media', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const thumbnails = new ThumbnailRuntime(files, bus);
      const attachments = new AttachmentRuntime(bus);
      const runtime = new ImageRuntime(files, bus, thumbnails, attachments);
      const deleted = new Array<string>();
      bus.subscribe<ImageDeletedPayload>('image.deleted', (event: RuntimeEvent<ImageDeletedPayload>) => {
        deleted.push(`${event.payload.imageId}:${event.payload.path}`);
      });

      const image = await runtime.uploadImage(makeBoundImage('img-5', 'scene.png'));
      const bound = attachments.listAttachmentsForTarget('message', 'chat-1:0');
      await runtime.deleteImage('img-5');
      const afterDelete = await runtime.listImages('', 'asc');
      const thumb = await thumbnails.getThumbnail('bg', 'scene.png');

      expect(image.attachmentId).assertEqual('att-img-5');
      expect(bound.length).assertEqual(1);
      expect(bound[0].storagePath).assertEqual('tavern-data/users/default/assets/images/scene.png');
      expect(afterDelete.length).assertEqual(0);
      expect(thumb === undefined).assertTrue();
      expect(deleted[0]).assertEqual('img-5:tavern-data/users/default/assets/images/scene.png');
    });

    it('净化图片文件名、文件夹并安全写入附件元数据', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      const bus = new EventBus();
      const thumbnails = new ThumbnailRuntime(files, bus);
      const attachments = new AttachmentRuntime(bus);
      const runtime = new ImageRuntime(files, bus, thumbnails, attachments);
      const params = makeBoundImage('img-"safe', '../portrait.png');
      params.folderName = '../Alice';

      const image = await runtime.uploadImage(params);
      const saved = await files.readText('tavern-data/users/default/assets/images/..~2fAlice/..~2fportrait.png');
      const escapedExists = await files.exists('tavern-data/users/default/assets/Alice/portrait.png');
      const metadata = JSON.parse(attachments.getAttachment('att-img-"safe').metadataJson) as Record<string, string>;

      expect(image.path).assertEqual('tavern-data/users/default/assets/images/..~2fAlice/..~2fportrait.png');
      expect(saved).assertEqual('image-data');
      expect(escapedExists).assertFalse();
      expect(metadata['imageId']).assertEqual('img-"safe');
    });
  });
}

function makeImage(id: string, fileName: string, folderName: string, thumbnailType: string): ImageUploadParams {
  return {
    id: id,
    fileName: fileName,
    format: fileName.substring(fileName.lastIndexOf('.') + 1),
    folderName: folderName,
    mimeType: 'image/png',
    content: 'image-data',
    thumbnailType: thumbnailType,
    thumbnailContent: 'thumbnail-data',
    thumbnailWidth: 96,
    thumbnailHeight: 144,
    attachmentId: '',
    attachmentTargetType: '',
    attachmentTargetId: '',
    includeInPrompt: false,
    includeInRag: false,
  };
}

function makeBoundImage(id: string, fileName: string): ImageUploadParams {
  const params = makeImage(id, fileName, '', 'bg');
  params.thumbnailWidth = 160;
  params.thumbnailHeight = 90;
  params.attachmentId = `att-${id}`;
  params.attachmentTargetType = 'message';
  params.attachmentTargetId = 'chat-1:0';
  params.includeInPrompt = true;
  return params;
}
