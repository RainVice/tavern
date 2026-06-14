/**
 * swipe 模块导出核心能力和类型。
 *
 * 提供消息候选回复（Swipe）运行时管理（SwipeRuntime）以及相关模型类型，
 * 包括创建参数、记录结构、流式状态和事件载荷。
 */
export { SwipeRuntime } from './SwipeRuntime';
export type {
  SwipeChangedPayload,
  SwipeCreateParams,
  SwipeDeletedPayload,
  SwipeRecord,
  SwipeStreamState,
} from './SwipeModels';
