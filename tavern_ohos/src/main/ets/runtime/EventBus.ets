/**
 * EventBus 投递给订阅者的事件对象。
 *
 * name 是事件名，例如 message.added；payload 是对应 Runtime 发布的业务数据副本。
 * 在事件发布-订阅流程中，由 EventBus.publish 创建并通过 subscribe 的回调分发给订阅者。
 */
export interface RuntimeEvent<T extends Object> {
  /**
   * 事件名，如 "message.added"、"stream.delta"、"swipe.changed" 等，用于订阅者区分事件类型。
   */
  name: string;
  /**
   * 事件载荷，由对应 Runtime 在发布时传入的業務数据副本。
   */
  payload: T;
  /**
   * 当前 EventBus 实例内递增的事件序号，用于追踪事件发布顺序和调试。
   */
  sequence: number;
  /**
   * 事件发布时间戳，单位为毫秒。
   */
  timestamp: number;
}

export type RuntimeEventHandler<T extends Object> = (event: RuntimeEvent<T>) => void;

/**
 * EventBus.subscribe 返回的订阅句柄。
 * 宿主 UI 或 Runtime 在订阅事件时获得此句柄，页面销毁或不再需要监听时应调用 unsubscribe 以释放资源。
 */
export interface EventSubscription {
  /**
   * 取消订阅；重复调用不会再次修改订阅列表。
   */
  unsubscribe(): void;
}

/**
 * 维护单个订阅回调的生命周期。
 */
class RuntimeEventSubscription implements EventSubscription {
  /**
   * 当前事件名下的订阅回调数组，引用自 EventBus.handlers 中对应事件名的数组。
   */
  private handlers: Array<RuntimeEventHandler<Object>>;
  /**
   * 事件处理函数，即 subscribe 时传入的 handler 的包装引用。
   */
  private handler: RuntimeEventHandler<Object>;
  /**
   * 标记订阅是否仍然有效，避免重复取消订阅。
   */
  private active: boolean = true;

  /**
   * 保存订阅回调数组和包装后的回调引用，供 unsubscribe 精确移除。
   * @param handlers 当前事件名下的所有订阅回调数组，引用自 EventBus 的内部存储。
   * @param handler 包装后的事件处理函数，与 EventBus 存储的引用一致。
   */
  constructor(handlers: Array<RuntimeEventHandler<Object>>, handler: RuntimeEventHandler<Object>) {
    this.handlers = handlers;
    this.handler = handler;
  }

  /**
   * 从订阅数组中移除当前回调，并把订阅句柄标记为失效。
   */
  unsubscribe(): void {
    if (!this.active) {
      return;
    }
    this.active = false;
    const index = this.handlers.indexOf(this.handler);
    if (index >= 0) {
      this.handlers.splice(index, 1);
    }
  }
}

/**
 * 运行时事件总线。
 *
 * Runtime 通过 publish 发布事件，宿主 UI 或其他 Runtime 通过 subscribe 订阅事件名。
 * payload 会在发布和分发时复制，订阅者修改 event.payload 不会回写到发布方对象。
 * 是所有模块（StreamingRuntime、SwipeRuntime、TagRuntime 等）之间解耦通信的核心基础设施。
 */
export class EventBus {
  /**
   * 按事件名保存订阅回调，一个事件名可以对应多个订阅者。
   */
  private handlers: Map<string, Array<RuntimeEventHandler<Object>>> = new Map<string, Array<RuntimeEventHandler<Object>>>();
  /**
   * 当前总线内递增的事件序号，每次 publish 时自增。
   */
  private sequence: number = 0;

  /**
   * 订阅指定事件名。
   * 在宿主 UI 或 Runtime 需要监听某个事件时调用（如 UI 订阅 stream.delta 以实时更新消息文本）。
   * @param eventName 事件名，例如 message.added。
   * @param handler 事件触发时调用的回调。
   * @returns 订阅句柄；页面销毁或不再需要监听时应调用 unsubscribe。
   */
  subscribe<T extends Object>(eventName: string, handler: RuntimeEventHandler<T>): EventSubscription {
    const wrapped: RuntimeEventHandler<Object> = (event: RuntimeEvent<Object>) => {
      handler(event as RuntimeEvent<T>);
    };
    const existing = this.handlers.get(eventName);
    const handlers = existing === undefined ? new Array<RuntimeEventHandler<Object>>() : existing;
    handlers.push(wrapped);
    this.handlers.set(eventName, handlers);
    return new RuntimeEventSubscription(handlers, wrapped);
  }

  /**
   * 发布事件并同步调用当前事件名下的订阅者。
   * 由各 Runtime（StreamingRuntime、SwipeRuntime 等）在状态变更时调用，用于通知宿主 UI 和其他 Runtime。
   * @param eventName 事件名，例如 message.added。
   * @param payload 可 JSON 序列化的事件载荷。
   * @returns 本次发布生成的事件对象。
   */
  publish<T extends Object>(eventName: string, payload: T): RuntimeEvent<T> {
    this.sequence += 1;
    const sequence = this.sequence;
    const timestamp = Date.now();
    const event: RuntimeEvent<T> = {
      name: eventName,
      payload: this.clonePayload(payload),
      sequence: sequence,
      timestamp: timestamp,
    };
    const handlers = this.handlers.get(eventName);
    if (handlers === undefined) {
      return event;
    }
    const snapshot = handlers.slice();
    for (let index = 0; index < snapshot.length; index += 1) {
      const handlerEvent: RuntimeEvent<T> = {
        name: eventName,
        payload: this.clonePayload(payload),
        sequence: sequence,
        timestamp: timestamp,
      };
      snapshot[index](handlerEvent as RuntimeEvent<Object>);
    }
    return event;
  }

  /**
   * 用 JSON 序列化复制 payload，防止订阅者修改发布方持有的对象引用。
   * @param payload 待复制的事件载荷。
   */
  private clonePayload<T extends Object>(payload: T): T {
    return JSON.parse(JSON.stringify(payload)) as T;
  }
}
