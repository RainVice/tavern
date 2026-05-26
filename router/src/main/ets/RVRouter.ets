import { PopResult, ZRouter } from '@hzw/zrouter';
import { LogUtil, ObjectUtil } from '@pura/harmony-utils';
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

  static push<R = void>(
    name: string,
    onPop?: (result: PopResult<R | Object | null | undefined>) => void
  ) {
    const router = ZRouter.getInstance()
    if (onPop) {
      router.setPopListener(onPop)
    }
    router.push(name)
  }

  static pushWithParam<P = void, R = void>(
    name: string,
    param?: P,
    onPop?: (result: PopResult<R | Object | null | undefined>) => void
  ) {
    const router = ZRouter.getInstance()
    if (param) {
      router.setParam(param)
    }
    if (onPop) {
      router.setPopListener(onPop)
    }
    router.push(name)
  }

  static pop<T = void>(t?: T) {
    if (!ObjectUtil.isNull(t)) {
      ZRouter.getInstance().popWithResult(t)
    } else {
      ZRouter.getInstance().pop()
    }
  }
}