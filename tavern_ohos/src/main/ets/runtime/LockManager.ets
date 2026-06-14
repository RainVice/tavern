/**
 * 锁租约对象。由 LockManager.acquire 或 tryAcquire 返回，调用方可通过 release 主动释放锁。
 */
export interface LockLease {
  /**
   * 锁定的键名。
   */
  key: string;

  /**
   * 释放当前持有的锁。释放后 LockManager 将允许其他调用方获取同一键名的锁。
   */
  release(): void;
}

/**
 * LockManager.tryAcquire 的返回值，包含获取结果和对应的租约。
 */
export interface TryLockResult {
  /**
   * 是否成功获取锁。true 表示获取成功且 lease 可用；false 表示锁已被其他调用方持有。
   */
  acquired: boolean;
  /**
   * 锁租约。配合 acquired 使用：为 true 时调用 lease.release() 释放锁；为 false 时 lease 为空操作。
   */
  lease: LockLease;
}

/**
 * LockManager 成功获取锁时创建的活跃租约实现。记录持有的键名，release 时从 LockManager 的持有集合中删除该键。
 */
class ActiveLockLease implements LockLease {
  /**
   * 锁定的键名。
   */
  key: string;
  /**
   * LockManager 内当前持有的所有键名集合。
   */
  private heldKeys: Set<string>;
  /**
   * 是否已释放锁的标记；release 首次调用后置为 true，后续调用被忽略。
   */
  private released: boolean = false;

  /**
   * @param heldKeys LockManager 的持有键集合引用。
   * @param key 锁定的键名。
   */
  constructor(heldKeys: Set<string>, key: string) {
    this.heldKeys = heldKeys;
    this.key = key;
  }

  /**
   * 释放当前持有的锁。从 LockManager 的持有集合中移除记录的键名，使其他调用方可获取该键的锁。
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
 * LockManager 锁已被持有时的空租约实现。acquired 为 false 时返回，release 为空操作。
 */
class EmptyLockLease implements LockLease {
  /**
   * 锁定的键名。
   */
  key: string;

  /**
   * @param key 锁定的键名。
   */
  constructor(key: string) {
    this.key = key;
  }

  /**
   * 空操作。该租约未实际持有锁，调用无副作用。
   */
  release(): void {
  }
}

/**
 * 轻量级互斥锁管理器。保证同一键名的锁同时只被一个调用方持有，适用于资源互斥访问场景。
 *
 * 典型用法：await lockManager.acquire('my-resource') 获取锁，在 finally 中调用 lease.release() 释放。
 * tryAcquire 提供非阻塞版本，获取失败时不抛出异常。
 */
export class LockManager {
  /**
   * 当前所有被持锁的键名集合。
   */
  private heldKeys: Set<string> = new Set<string>();

  /**
   * 阻塞式获取锁。若键已被持有则抛出 Error，直到锁释放后再尝试。
   * @param key 锁定的键名。
   * @returns 锁租约，调用方应在使用完毕后调用 release() 释放。
   */
  async acquire(key: string): Promise<LockLease> {
    const result = await this.tryAcquire(key);
    if (!result.acquired) {
      throw new Error(`Lock already held: ${key}`);
    }
    return result.lease;
  }

  /**
   * 非阻塞式尝试获取锁。立即返回结果而不等待。
   * @param key 锁定的键名。
   * @returns 获取结果。acquired 为 true 时 lease 为活跃租约；为 false 时 lease 为空操作。
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
   * 直接释放指定键名的锁。通常应优先通过 LockLease.release() 释放；此方法用于需要直接操作键名的场景。
   * @param key 待释放的锁键名。
   */
  release(key: string): void {
    this.heldKeys.delete(key);
  }
}
