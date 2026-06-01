import { ModelProviderListPage } from '../model_provider_list/ModelProviderListPage';

export class SettingsViewModel {
  onAvatarClick() {
    // TODO: 跳转个人信息页
  }

  onModelProviderClick() {
    ModelProviderListPage.start()
  }
}
