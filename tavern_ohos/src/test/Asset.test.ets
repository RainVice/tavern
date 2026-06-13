import { describe, it, expect } from '@ohos/hypium';
import {
  AssetRuntime,
  EventBus,
  InMemoryFileStore,
  type AssetCreateParams,
  type AssetDeletedPayload,
  type AssetRecord,
  type AssetRenamedPayload,
  type RuntimeEvent,
  type TavernFileStore,
} from '../../Index';

export default function assetUnitTest() {
  describe('asset runtime', () => {
    it('imports assets into typed folders and persists an index', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new AssetRuntime(files, new EventBus());
      const image = await runtime.importAsset(makeAsset('asset-1', 'image', 'alice.png', 'image/png', 'png-data'));
      await runtime.importAsset(makeAsset('asset-2', 'background', 'forest.jpg', 'image/jpeg', 'jpg-data'));
      const saved = await files.readText('tavern-data/users/default/assets/images/alice.png');
      const index = await files.readText('tavern-data/users/default/assets/index.json');
      const images = await runtime.listByType('image');

      expect(image.id).assertEqual('asset-1');
      expect(image.path).assertEqual('tavern-data/users/default/assets/images/alice.png');
      expect(saved).assertEqual('png-data');
      expect(index.indexOf('forest.jpg') >= 0).assertTrue();
      expect(images.length).assertEqual(1);
      expect(images[0].fileName).assertEqual('alice.png');
    });

    it('renames assets and emits deletion events', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new AssetRuntime(files, bus);
      const renamed = new Array<string>();
      const deleted = new Array<string>();
      bus.subscribe<AssetRenamedPayload>('asset.renamed', (event: RuntimeEvent<AssetRenamedPayload>) => {
        renamed.push(`${event.payload.assetId}:${event.payload.oldPath}:${event.payload.asset.path}`);
      });
      bus.subscribe<AssetDeletedPayload>('asset.deleted', (event: RuntimeEvent<AssetDeletedPayload>) => {
        deleted.push(`${event.payload.assetId}:${event.payload.type}`);
      });

      await runtime.importAsset(makeAsset('theme-1', 'theme', 'dark.json', 'application/json', '{"name":"dark"}'));
      const renamedAsset: AssetRecord = await runtime.renameAsset('theme-1', 'dark-copy.json');
      const content = await runtime.readAssetContent('theme-1');
      await runtime.deleteAsset('theme-1');
      const allThemes = await runtime.listByType('theme');

      expect(renamedAsset.fileName).assertEqual('dark-copy.json');
      expect(content).assertEqual('{"name":"dark"}');
      expect(allThemes.length).assertEqual(0);
      expect(renamed.length).assertEqual(1);
      expect(deleted[0]).assertEqual('theme-1:theme');
    });

    it('indexes thumbnail and audio assets by type', 0, async () => {
      // 运行时实例。
      const runtime = new AssetRuntime(new InMemoryFileStore(), new EventBus());
      await runtime.importAsset(makeAsset('thumb-1', 'thumbnail', 'alice-thumb.png', 'image/png', 'thumb'));
      await runtime.importAsset(makeAsset('audio-1', 'audio', 'voice.wav', 'audio/wav', 'audio'));
      const thumbnails = await runtime.listByType('thumbnail');
      const audio = await runtime.listByType('audio');
      const all = await runtime.listAssets();

      expect(thumbnails[0].path).assertEqual('tavern-data/users/default/assets/thumbnails/alice-thumb.png');
      expect(audio[0].path).assertEqual('tavern-data/users/default/assets/audio/voice.wav');
      expect(all.length).assertEqual(2);
    });

    it('sanitizes asset file names and unknown type folders', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new AssetRuntime(files, new EventBus());
      const asset = await runtime.importAsset(makeAsset('asset-safe', '../custom', '../escape.png', 'image/png', 'data'));
      const renamed = await runtime.renameAsset('asset-safe', '..\\renamed.png');

      expect(asset.fileName).assertEqual('..~2fescape.png');
      expect(asset.path).assertEqual('tavern-data/users/default/assets/..~2fcustom/..~2fescape.png');
      expect(renamed.fileName).assertEqual('..~5crenamed.png');
      expect(renamed.path).assertEqual('tavern-data/users/default/assets/..~2fcustom/..~5crenamed.png');
    });
  });
}

/**
 * 封装单元测试中的 makeAsset 步骤，供公开方法复用。
 * @param id 唯一标识。

 * @param fileName file 名称。

 * @param content 要写入或追加的文本内容。
 */
function makeAsset(id: string, type: string, fileName: string, mimeType: string, content: string): AssetCreateParams {
  return {
    id: id,
    type: type,
    fileName: fileName,
    mimeType: mimeType,
    content: content,
    metadataJson: '{"source":"test"}',
  };
}
