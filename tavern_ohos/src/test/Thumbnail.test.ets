import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  InMemoryFileStore,
  ThumbnailRuntime,
  type ThumbnailCreateParams,
  type RuntimeEvent,
  type TavernFileStore,
  type ThumbnailGeneratedPayload,
  type ThumbnailInvalidatedPayload,
  type ThumbnailRecord,
} from '../../Index';

export default function thumbnailUnitTest() {
  describe('thumbnail runtime', () => {
    it('generates typed thumbnails and persists a cache index', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ThumbnailRuntime(files, bus);
      const generated = new Array<string>();
      bus.subscribe<ThumbnailGeneratedPayload>('thumbnail.generated', (event: RuntimeEvent<ThumbnailGeneratedPayload>) => {
        generated.push(`${event.payload.thumbnail.type}:${event.payload.thumbnail.fileName}`);
      });
      const thumbnail: ThumbnailRecord = await runtime.generateThumbnail({
        type: 'bg',
        fileName: 'forest.jpg',
        sourcePath: 'tavern-data/users/default/backgrounds/forest.jpg',
        content: 'thumb-data',
        width: 160,
        height: 90,
        animated: false,
      });
      const content = await runtime.readThumbnailContent('bg', 'forest.jpg');
      const index = await files.readText('tavern-data/users/default/assets/thumbnails/index.json');

      expect(thumbnail.path).assertEqual('tavern-data/users/default/assets/thumbnails/bg/forest.jpg');
      expect(thumbnail.resolution).assertEqual(14400);
      expect(content).assertEqual('thumb-data');
      expect(index.indexOf('forest.jpg') >= 0).assertTrue();
      expect(generated[0]).assertEqual('bg:forest.jpg');
    });

    it('lists avatar and persona thumbnails with upstream dimensions', 0, async () => {
      // 运行时实例。
      const runtime = new ThumbnailRuntime(new InMemoryFileStore(), new EventBus());

      await runtime.generateThumbnail(makeThumbnail('avatar', 'alice.png', 96, 144));
      await runtime.generateThumbnail(makeThumbnail('persona', 'hero.png', 96, 144));
      const avatarDimensions = runtime.getConfiguredDimensions('avatar');
      const backgroundDimensions = runtime.getConfiguredDimensions('bg');
      const avatars = await runtime.listByType('avatar');

      expect(avatarDimensions.width).assertEqual(96);
      expect(avatarDimensions.height).assertEqual(144);
      expect(backgroundDimensions.width).assertEqual(160);
      expect(backgroundDimensions.height).assertEqual(90);
      expect(avatars.length).assertEqual(1);
      expect(avatars[0].path).assertEqual('tavern-data/users/default/assets/thumbnails/avatar/alice.png');
    });

    it('invalidates cached thumbnails and emits events', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new ThumbnailRuntime(files, bus);
      const invalidated = new Array<string>();
      bus.subscribe<ThumbnailInvalidatedPayload>('thumbnail.invalidated', (event: RuntimeEvent<ThumbnailInvalidatedPayload>) => {
        invalidated.push(`${event.payload.type}:${event.payload.fileName}:${event.payload.path}`);
      });

      await runtime.generateThumbnail(makeThumbnail('persona', 'hero.png', 96, 144));
      await runtime.invalidateThumbnail('persona', 'hero.png');
      const personas = await runtime.listByType('persona');

      expect(personas.length).assertEqual(0);
      expect(invalidated[0]).assertEqual('persona:hero.png:tavern-data/users/default/assets/thumbnails/persona/hero.png');
    });

    it('sanitizes thumbnail file names and unknown type folders', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new ThumbnailRuntime(files, new EventBus());
      const thumbnail = await runtime.generateThumbnail({
        type: '../custom',
        fileName: '../escape.png',
        sourcePath: 'source',
        content: 'thumb',
        width: 10,
        height: 5,
        animated: false,
      });
      const loaded = await runtime.getThumbnail('../custom', '../escape.png');

      expect(thumbnail.fileName).assertEqual('..~2fescape.png');
      expect(thumbnail.path).assertEqual('tavern-data/users/default/assets/thumbnails/..~2fcustom/..~2fescape.png');
      expect(loaded === undefined).assertFalse();
      expect(loaded!.path).assertEqual(thumbnail.path);
    });
  });
}

/**
 * 封装单元测试中的 makeThumbnail 步骤，供公开方法复用。

 * @param fileName file 名称。
 */
function makeThumbnail(type: string, fileName: string, width: number, height: number): ThumbnailCreateParams {
  return {
    type: type,
    fileName: fileName,
    sourcePath: `source/${fileName}`,
    content: `${type}-thumb`,
    width: width,
    height: height,
    animated: false,
  };
}
