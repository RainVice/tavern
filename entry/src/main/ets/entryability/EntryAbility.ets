import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppUtil, LogUtil } from '@pura/harmony-utils';
import BuildProfile from 'entry/BuildProfile';
import { RVRouter } from 'router';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.init()
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (error) {
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('Index').catch(() => {
    });
  }

  private init() {
    RVRouter.init(this.context)
    AppUtil.init(this.context)
    LogUtil.setShowLog(BuildProfile.DEBUG)
  }
}