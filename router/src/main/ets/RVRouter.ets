import { ZRouter } from '@hzw/zrouter';
import { ObjectOrNull, OnPopResultCallback } from '@hzw/zrouter/src/main/ets/model/Model';
import { LogUtil, ObjectUtil } from '@pura/harmony-utils';
import BuildProfile from '../../../BuildProfile';

const emptyFun = () => {
}

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

  static getParam<T>(): T | undefined {
    return ZRouter.getInstance().getParam() as T
  }

  static push<R = undefined>(option: PushOption<R>) {
    ZRouter.getInstance()
      .setParam(option.param)
      .setPopListener(option.onPop ?? emptyFun)
      .push(option.name)
  }

  static pop(t?: Object) {
    if (!ObjectUtil.isNull(t)) {
      ZRouter.getInstance().popWithResult(t)
    } else {
      ZRouter.getInstance().pop()
    }
  }
}

interface PushOption<R> {
  name: string,
  param?: ObjectOrNull,
  onPop?: OnPopResultCallback<R | ObjectOrNull>
}