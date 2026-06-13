export interface RuntimeEvent<T extends Object> {
  name: string;
  payload: T;
  sequence: number;
  timestamp: number;
}

export type RuntimeEventHandler<T extends Object> = (event: RuntimeEvent<T>) => void;

export interface EventSubscription {
  unsubscribe(): void;
}

class RuntimeEventSubscription implements EventSubscription {
  private handlers: Array<RuntimeEventHandler<Object>>;
  private handler: RuntimeEventHandler<Object>;
  private active: boolean = true;

  constructor(handlers: Array<RuntimeEventHandler<Object>>, handler: RuntimeEventHandler<Object>) {
    this.handlers = handlers;
    this.handler = handler;
  }

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

export class EventBus {
  private handlers: Map<string, Array<RuntimeEventHandler<Object>>> = new Map<string, Array<RuntimeEventHandler<Object>>>();
  private sequence: number = 0;

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

  private clonePayload<T extends Object>(payload: T): T {
    return JSON.parse(JSON.stringify(payload)) as T;
  }
}
