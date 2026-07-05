import { RouterName, RVRouter } from 'router';

export class SettingsViewModel {
  onModelProviderClick() {
    RVRouter.push({ name: RouterName.ProviderList })
  }
}
