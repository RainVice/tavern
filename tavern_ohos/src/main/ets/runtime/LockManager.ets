/**
 * 描述运行时基础设施模块在运行时交换的数据结构。
 */
export interface LockLease {
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;

  /**
   * 执行 release 的内部处理步骤，供当前模块复用。
   */
  release(): void;
}

/**
 * 描述运行时基础设施操作完成后返回给调用方的结果。
 */
export interface TryLockResult {
  /**
   * acquired 值，由当前实例内部维护。
   */
  acquired: boolean;
  /**
   * lease 值，由当前实例内部维护。
   */
  lease: LockLease;
}

/**
 * 封装运行时基础设施相关状态和行为。
 */
class ActiveLockLease implements LockLease {
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;
  /**
   * held Keys 列表，由当前实例内部维护。
   */
  private heldKeys: Set<string>;
  /**
   * released 值，由当前实例内部维护。
   */
  private released: boolean = false;

  /**
   * 注入运行时基础设施运行时依赖并初始化实例状态。

   * @param key 键名。
   */
  constructor(heldKeys: Set<string>, key: string) {
    this.heldKeys = heldKeys;
    this.key = key;
  }

  /**
   * 执行 release 的内部处理步骤，供当前模块复用。
   */
  release(): void {
    if (this.released) {
      return;
    }
    this.released = true;
    this.heldKeys.delete(this.key);
  }
}

/**
 * 封装运行时基础设施相关状态和行为。
 */
class EmptyLockLease implements LockLease {
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;

  /**
   * 注入运行时基础设施运行时依赖并初始化实例状态。
   * @param key 键名。
   */
  constructor(key: string) {
    this.key = key;
  }

  /**
   * 执行 release 的内部处理步骤，供当前模块复用。
   */
  release(): void {
  }
}

/**
 * 封装运行时基础设施相关状态和行为。
 */
export class LockManager {
  /**
   * held Keys 列表，由当前实例内部维护。
   */
  private heldKeys: Set<string> = new Set<string>();

  /**
   * 执行 acquire 的内部处理步骤，供当前模块复用。
   * @param key 键名。
   */
  async acquire(key: string): Promise<LockLease> {
    const result = await this.tryAcquire(key);
    if (!result.acquired) {
      throw new Error(`Lock already held: ${key}`);
    }
    return result.lease;
  }

  /**
   * 执行 tryAcquire 的内部处理步骤，供当前模块复用。
   * @param key 键名。
   */
  async tryAcquire(key: string): Promise<TryLockResult> {
    if (this.heldKeys.has(key)) {
      return {
        acquired: false,
        lease: new EmptyLockLease(key),
      };
    }

    this.heldKeys.add(key);
    return {
      acquired: true,
      lease: new ActiveLockLease(this.heldKeys, key),
    };
  }

  /**
   * 执行 release 的内部处理步骤，供当前模块复用。
   * @param key 键名。
   */
  release(key: string): void {
    this.heldKeys.delete(key);
  }
}
