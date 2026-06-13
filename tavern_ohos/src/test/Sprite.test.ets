import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  InMemoryFileStore,
  SpriteRuntime,
  type RisuSpriteImport,
  type RuntimeEvent,
  type SpriteDeletedPayload,
  type SpriteExpressionChangedPayload,
  type SpriteRecord,
  type SpriteUploadedPayload,
  type SpriteUploadParams,
  type TavernFileStore,
} from '../../Index';

export default function spriteUnitTest() {
  describe('sprite runtime', () => {
    it('uploads and lists character sprites with expression labels', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new SpriteRuntime(files, bus);
      const uploaded = new Array<string>();
      bus.subscribe<SpriteUploadedPayload>('sprite.uploaded', (event: RuntimeEvent<SpriteUploadedPayload>) => {
        uploaded.push(`${event.payload.sprite.characterName}:${event.payload.sprite.spriteName}`);
      });
      const sprite: SpriteRecord = await runtime.uploadSprite(makeSprite('Alice', 'joy', 'joy-1', 'joy.png'));
      await runtime.uploadSprite(makeSprite('Alice', 'sadness', 'sadness', 'sadness.webp'));
      const sprites = await runtime.listSprites('Alice', '');
      const content = await files.readText('tavern-data/users/default/characters/Alice/sprites/joy-1.png');

      expect(sprite.path).assertEqual('tavern-data/users/default/characters/Alice/sprites/joy-1.png');
      expect(content).assertEqual('sprite-data');
      expect(sprites.length).assertEqual(2);
      expect(sprites[0].label).assertEqual('joy');
      expect(sprites[1].label).assertEqual('sadness');
      expect(uploaded[0]).assertEqual('Alice:joy-1');
    });

    it('imports RisuAI sprites and supports subfolder costumes', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new SpriteRuntime(files, new EventBus());
      const imports = new Array<RisuSpriteImport>();
      imports.push({ label: 'neutral', content: 'neutral-data' });
      imports.push({ label: 'anger', content: 'anger-data' });

      await runtime.importRisuSprites('Alice', imports);
      await runtime.uploadSprite(makeSpriteInSubfolder('Alice', 'formal', 'joy', 'joy', 'joy.png'));
      const rootSprites = await runtime.listSprites('Alice', '');
      const costumeSprites = await runtime.listSprites('Alice', 'formal');
      const importedContent = await files.readText('tavern-data/users/default/characters/Alice/sprites/neutral.png');

      expect(rootSprites.length).assertEqual(2);
      expect(costumeSprites.length).assertEqual(1);
      expect(costumeSprites[0].path).assertEqual('tavern-data/users/default/characters/Alice/formal/joy.png');
      expect(importedContent).assertEqual('neutral-data');
    });

    it('sets expression state and clears deleted selected sprites', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 事件总线实例。
      const bus = new EventBus();
      // 运行时实例。
      const runtime = new SpriteRuntime(files, bus);
      const changed = new Array<string>();
      const deleted = new Array<string>();
      bus.subscribe<SpriteExpressionChangedPayload>('sprite.expression.changed', (event: RuntimeEvent<SpriteExpressionChangedPayload>) => {
        changed.push(`${event.payload.characterName}:${event.payload.expression}:${event.payload.spriteName}`);
      });
      bus.subscribe<SpriteDeletedPayload>('sprite.deleted', (event: RuntimeEvent<SpriteDeletedPayload>) => {
        deleted.push(`${event.payload.characterName}:${event.payload.spriteName}`);
      });

      await runtime.uploadSprite(makeSprite('Alice', 'joy', 'joy', 'joy.png'));
      const selected = await runtime.setExpression('Alice', '', 'joy', 'joy');
      await runtime.deleteSprite('Alice', '', 'joy');
      const afterDelete = runtime.getExpression('Alice', '');
      const sprites = await runtime.listSprites('Alice', '');

      expect(selected.expression).assertEqual('joy');
      expect(afterDelete.spriteName).assertEqual('');
      expect(sprites.length).assertEqual(0);
      expect(changed[0]).assertEqual('Alice:joy:joy');
      expect(deleted[0]).assertEqual('Alice:joy');
    });

    it('净化角色、子目录、sprite 名称并在删除选择项时清空状态', 0, async () => {
      const files: TavernFileStore = new InMemoryFileStore();
      // 运行时实例。
      const runtime = new SpriteRuntime(files, new EventBus());
      const sprite = await runtime.uploadSprite(makeSpriteInSubfolder('../Alice', '../formal', 'joy', '../joy', 'joy.txt'));
      const selected = await runtime.setExpression('../Alice', '../formal', 'joy', '../joy');
      await runtime.deleteSprite('../Alice', '../formal', '../joy');
      const afterDelete = runtime.getExpression('../Alice', '../formal');
      const escapedExists = await files.exists('tavern-data/users/default/Alice/formal/joy.txt');

      expect(sprite.characterName).assertEqual('..~2fAlice');
      expect(sprite.subfolderName).assertEqual('..~2fformal');
      expect(sprite.spriteName).assertEqual('..~2fjoy');
      expect(sprite.fileName).assertEqual('..~2fjoy.png');
      expect(sprite.path).assertEqual('tavern-data/users/default/characters/..~2fAlice/..~2fformal/..~2fjoy.png');
      expect(selected.spriteName).assertEqual('..~2fjoy');
      expect(afterDelete.spriteName).assertEqual('');
      expect(escapedExists).assertFalse();
    });
  });
}

/**
 * 封装单元测试中的 makeSprite 步骤，供公开方法复用。
 * @param characterName character 名称。
 * @param label 展示标签。
 * @param spriteName sprite 名称。
 * @param fileName file 名称。
 */
function makeSprite(characterName: string, label: string, spriteName: string, fileName: string): SpriteUploadParams {
  return makeSpriteInSubfolder(characterName, '', label, spriteName, fileName);
}

/**
 * 封装单元测试中的 makeSpriteInSubfolder 步骤，供公开方法复用。
 * @param characterName character 名称。
 * @param subfolderName subfolder 名称。
 * @param label 展示标签。
 * @param spriteName sprite 名称。
 * @param fileName file 名称。
 */
function makeSpriteInSubfolder(characterName: string, subfolderName: string, label: string, spriteName: string, fileName: string): SpriteUploadParams {
  return {
    characterName: characterName,
    subfolderName: subfolderName,
    label: label,
    spriteName: spriteName,
    fileName: fileName,
    mimeType: 'image/png',
    content: 'sprite-data',
  };
}
