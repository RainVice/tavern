import { describe, expect, it } from '@ohos/hypium';
import { ModelProviderEditState } from '../main/ets/pages/model_provider_edit/ModelProviderEditState';
import { ModelProviderEditViewModel } from '../main/ets/pages/model_provider_edit/ModelProviderEditViewModel';

export default function modelProviderEditTest() {
  describe('modelProviderEdit', () => {
    it('buildsConnectionProfileParamsWithOnlyOneModel', 0, () => {
      const state = new ModelProviderEditState();
      state.id = 'provider-test';
      state.name = '本地模型';
      state.serverUrl = 'https://api.example.com/v1';
      state.secretRef = 'sk-test';
      state.model = ' first-model ';
      state.availableModels = ['first-model', 'second-model'];

      const params = ModelProviderEditViewModel.buildCreateParams(state, 'provider-test');

      expect(params.model).assertEqual('first-model');
      expect(params.additionalHeaders.length).assertEqual(0);
    });
  });
}
