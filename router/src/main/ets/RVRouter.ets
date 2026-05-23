import { ZRouter } from '@hzw/zrouter';
import { LogUtil } from '@pura/harmony-utils';
import BuildProfile from '../../../BuildProfile';

export class RVRouter {
  static init(context: Context) {
    ZRouter.initialize((config) => {
      // 设置context
      config.context = context
      config.isLoggingEnabled = BuildProfile.DEBUG
      config.onDynamicLoadComplete = () => {
        LogUtil.debug("已完成所有模块的加载")
      }
    })
  }

  static getNavStack(): NavPathStack {
    return ZRouter.getNavStack()
  }

  static push(name: string) {
    ZRouter.getInstance().push(name)
  }
}