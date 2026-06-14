/**
 * EventBus 投递给订阅者的事件对象。
 *
 * name 是事件名，例如 message.added；payload 是对应 Runtime 发布的业务数据副本。
 * T 为 payload 的具体类型。
 */
export interface RuntimeEvent<T extends Object> {
  /**
   * 事件名，例如 message.added。
   */
  name: string;
  /**
   * 事件载荷，发布时通过 JSON 序列化深度复制，订阅方对其修改不会影响发布方。
   */
  payload: T;
  /**
   * 当前 EventBus 实例内严格递增的事件序号，从 1 开始。
   */
  sequence: number;
  /**
   * 事件发布时间戳，单位为毫秒。
   */
  timestamp: number;
}

/**
 * 事件处理回调类型。接收一个 RuntimeEvent 参数，无返回值。
 * @typeParam T payload 的具体类型。
 */
export type RuntimeEventHandler<T extends Object> = (event: RuntimeEvent<T>) => void;

/**
 * EventBus.subscribe 返回的订阅句柄。
 * 调用方应在页面销毁或不再需要监听时调用 unsubscribe 释放回调。
 */
export interface EventSubscription {
  /**
   * 取消当前订阅。重复调用安全，第二次起不做任何操作。
   */
  unsubscribe(): void;
}

/**
 * 维护单个订阅回调的生命周期。
 */
class RuntimeEventSubscription implements EventSubscription {
  /**
   * 当前事件名下的订阅回调数组。
   */
  private handlers: Array<RuntimeEventHandler<Object>>;
  /**
   * 事件处理函数。
   */
  private handler: RuntimeEventHandler<Object>;
  /**
   * 标记订阅是否仍然有效，避免重复取消订阅。
   */
  private active: boolean = true;

  /**
   * 保存订阅数组和包装后的回调，供 unsubscribe 精确移除。
   * @param handlers 当前事件名下的订阅回调数组。
   * @param handler 事件触发时执行的回调函数。
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
 */
export class EventBus {
  /**
   * 按事件名保存订阅回调。
   */
  private handlers: Map<string, Array<RuntimeEventHandler<Object>>> = new Map<string, Array<RuntimeEventHandler<Object>>>();
  /**
   * 当前总线内递增的事件序号。
   */
  private sequence: number = 0;

  /**
   * 订阅指定事件名。
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
   * 发布事件并同步调用所有已订阅的回调。
   * 每个订阅者收到的是 payload 的独立深度副本，互不干扰。
   * @param eventName 事件名，例如 message.added。
   * @param payload 可 JSON 序列化的事件载荷；不可序列化的字段（函数、undefined、循环引用）会在复制中丢失。
   * @returns 本次发布生成的事件对象，调用方可借此获取 sequence 序号和发布时间戳。
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
   * 通过 JSON 序列化深度复制 payload，避免订阅者修改影响发布方持有的原始对象。
   * 注意：仅对可 JSON 序列化的数据有效；函数、undefined、Date 等会在序列化中丢失或变形。
   * @param payload 待复制的事件载荷。
   * @returns 深度复制后的新对象。
   */
  private clonePayload<T extends Object>(payload: T): T {
    return JSON.parse(JSON.stringify(payload)) as T;
  }
}
