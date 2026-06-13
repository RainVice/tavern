import { describe, it, expect } from '@ohos/hypium';
import {
  AssetRuntime,
  BackgroundRuntime,
  EventBus,
  InMemoryFileStore,
  ThemeRuntime,
  ThumbnailRuntime,
  type BackgroundDeletedPayload,
  type BackgroundImportedPayload,
  type BackgroundImportParams,
  type BackgroundListResult,
  type BackgroundRecord,
  type BackgroundRenamedPayload,
  type RuntimeEvent,
  type TavernFileStore,
} from '../../Index';

export default function backgroundUnitTest() {
  describe('background runtime', () => {
    it('imports backgrounds through assets and lists thumbnail metadata', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = makeRuntime(files, bus);
      const imported = new Array<string>();
      bus.subscribe<BackgroundImportedPayload>('background.imported', (event: RuntimeEvent<BackgroundImportedPayload>) => {
        imported.push(`${event.payload.background.fileName}:${event.payload.background.isAnimated}`);
      });

      // 记录副本。
      const record: BackgroundRecord = await runtime.importBackground(makeBackground('bg-1', 'forest.jpg', false));
      const saved = await files.readText('tavern-data/users/default/assets/backgrounds/forest.jpg');
      const list: BackgroundListResult = await runtime.listBackgrounds();
      const index = await files.readText('tavern-data/users/default/assets/backgrounds/index.json');

      expect(record.path).assertEqual('tavern-data/users/default/assets/backgrounds/forest.jpg');
      expect(record.thumbnailPath).assertEqual('tavern-data/users/default/assets/thumbnails/bg/forest.jpg');
      expect(saved).assertEqual('background-data');
      expect(list.config.width).assertEqual(160);
      expect(list.config.height).assertEqual(90);
      expect(list.images[0].filename).assertEqual('forest.jpg');
      expect(list.images[0].isAnimated).assertFalse();
      expect(index.indexOf('forest.jpg') >= 0).assertTrue();
      expect(imported[0]).assertEqual('forest.jpg:false');
    });

    it('tracks folders and activates selected background in theme state', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      const theme = new ThemeRuntime(files, bus);
      // 运行时实例。
      const runtime = new BackgroundRuntime(files, bus, new AssetRuntime(files, bus), new ThumbnailRuntime(files, bus), theme);

      await runtime.importBackground(makeBackground('bg-2', 'city.png', true));
      await runtime.activateBackground('city.png');
      const folders = await runtime.listFolders();

      expect(folders.length).assertEqual(2);
      expect(folders[0].id).assertEqual('night');
      expect(folders[1].id).assertEqual('urban');
      expect(theme.getActiveBackground()).assertEqual('city.png');
    });

    it('renames and deletes backgrounds while invalidating thumbnail cache', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      const thumbnails = new ThumbnailRuntime(files, bus);
      // 运行时实例。
      const runtime = new BackgroundRuntime(files, bus, new AssetRuntime(files, bus), thumbnails, new ThemeRuntime(files, bus));
      const renamed = new Array<string>();
      const deleted = new Array<string>();
      bus.subscribe<BackgroundRenamedPayload>('background.renamed', (event: RuntimeEvent<BackgroundRenamedPayload>) => {
        renamed.push(`${event.payload.oldFileName}:${event.payload.background.fileName}`);
      });
      bus.subscribe<BackgroundDeletedPayload>('background.deleted', (event: RuntimeEvent<BackgroundDeletedPayload>) => {
        deleted.push(`${event.payload.backgroundId}:${event.payload.fileName}`);
      });

      await runtime.importBackground(makeBackground('bg-3', 'old.jpg', false));
      const renamedBackground = await runtime.renameBackground('bg-3', 'new.jpg');
      await runtime.deleteBackground('bg-3');
      const list = await runtime.listBackgrounds();
      const oldThumb = await thumbnails.getThumbnail('bg', 'old.jpg');

      expect(renamedBackground.fileName).assertEqual('new.jpg');
      expect(list.images.length).assertEqual(0);
      expect(oldThumb === undefined).assertTrue();
      expect(renamed[0]).assertEqual('old.jpg:new.jpg');
      expect(deleted[0]).assertEqual('bg-3:new.jpg');
    });
  });
}

/**
 * 封装单元测试中的 makeRuntime 步骤，供公开方法复用。
 * @param files 文件存储适配器。
 * @param bus 事件总线实例。
 */
function makeRuntime(files: TavernFileStore, bus: EventBus): BackgroundRuntime {
  return new BackgroundRuntime(files, bus, new AssetRuntime(files, bus), new ThumbnailRuntime(files, bus), new ThemeRuntime(files, bus));
}

/**
 * 封装单元测试中的 makeBackground 步骤，供公开方法复用。
 * @param id 唯一标识。
 * @param fileName file 名称。

 * @returns 条件命中时返回 true，否则返回 false。
 */
function makeBackground(id: string, fileName: string, animated: boolean): BackgroundImportParams {
  return {
    id: id,
    fileName: fileName,
    content: 'background-data',
    mimeType: 'image/jpeg',
    metadataJson: '{"source":"test"}',
    isAnimated: animated,
    folderIds: ['night', 'urban'],
    thumbnailContent: 'background-thumbnail',
  };
}
