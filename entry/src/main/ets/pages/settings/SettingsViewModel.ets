import { RVRouter, RouterName } from 'router';

export class SettingsViewModel {
  onAvatarClick() {
    // TODO: 跳转个人信息页
  }

  onModelProviderClick() {
    RVRouter.push(RouterName.ModelProviderList)
  }
}
