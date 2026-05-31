import { describe, it, expect } from '@ohos/hypium';
import {
  CharacterCard,
  CharacterCardAssetEntity,
  CharacterCardEntity,
} from '../main/ets/store/model/CharacterCard';
import {
  ModelDefinitionEntity,
  ModelProvider,
  ModelProviderEntity,
} from '../main/ets/store/model/ModelProvider';

export default function storeModelMappingTest() {
  describe('storeModelMapping', () => {
    it('mapsCharacterCardThroughEntityStaticMethods', 0, () => {
      const entity = new CharacterCardEntity(1, '莉莉', 1000, '简介', '性格', '场景', '你好', '示例');
      const asset = new CharacterCardAssetEntity(2, 1, 'avatar-data');
      const card: CharacterCard = CharacterCardEntity.toModel(entity, asset);

      expect(card.id).assertEqual(1);
      expect(card.avatarUrl).assertEqual('avatar-data');
      expect(card.firstMessage).assertEqual('你好');

      const restored: CharacterCardEntity = CharacterCardEntity.fromModel(card, 2000);
      expect(restored.id).assertEqual(1);
      expect(restored.updateTime).assertEqual(2000);
      expect(restored.exampleMessages).assertEqual('示例');
    });

    it('mapsModelProviderThroughEntityStaticMethods', 0, () => {
      const entity = new ModelProviderEntity(1, 'OpenAI', 1000, 'https://api.example.com', 'key');
      const definitions: ModelDefinitionEntity[] = [
        new ModelDefinitionEntity(1, 1, 'gpt-4.1'),
        new ModelDefinitionEntity(2, 2, 'ignored'),
      ];
      const provider: ModelProvider = ModelProviderEntity.toModel(entity, definitions);

      expect(provider.id).assertEqual(1);
      expect(provider.modelDefinitions.length).assertEqual(1);
      expect(provider.modelDefinitions[0].modelId).assertEqual('gpt-4.1');

      const restored: ModelProviderEntity = ModelProviderEntity.fromModel(provider, 2000);
      expect(restored.id).assertEqual(1);
      expect(restored.updateTime).assertEqual(2000);
      expect(restored.baseUrl).assertEqual('https://api.example.com');
    });
  });
}
