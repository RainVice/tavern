import { PopResult, ZRouter } from '@hzw/zrouter';
import { LogUtil, ObjectUtil } from '@pura/harmony-utils';
import BuildProfile from '../../../BuildProfile';

const emptyFun = () => {}

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

  static push(option: PushOption) {
    ZRouter.getInstance()
      .setParam(option.param)
      .setPopListener(option.onPop ?? emptyFun)
      .push(option.name)
  }

  static pop<T = void>(t?: T) {
    if (!ObjectUtil.isNull(t)) {
      ZRouter.getInstance().popWithResult(t)
    } else {
      ZRouter.getInstance().pop()
    }
  }
}

interface PushOption<P = undefined, R = undefined> {
  name: string,
  param?: P,
  onPop?: (result: PopResult<R | Object | null | undefined>) => void
}