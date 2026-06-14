/**
 * 描述运行时基础设施模块在运行时交换的数据结构。
 * 在 LockManager 中成功获取锁后返回，调用方在操作完成后应调用 release 释放锁。
 */
export interface LockLease {
  /**
   * 锁的键名，用于标识被锁定的资源（如任务 ID 或消息 ID）。
   */
  key: string;

  /**
   * 释放锁，使其他请求可以获取该键的锁。
   * 在临界区操作完成后由调用方调用，防止死锁。
   */
  release(): void;
}

/**
 * 描述尝试获取锁操作完成后返回给调用方的结果。
 * 由 LockManager.tryAcquire 返回，调用方根据 acquired 判断是否需要等待或重试。
 */
export interface TryLockResult {
  /**
   * 是否成功获取锁。
   */
  acquired: boolean;
  /**
   * 锁租赁（无论是否获取成功，都可用于释放）。
   */
  lease: LockLease;
}

/**
 * 已成功获取锁的租赁实现，持有锁的键并控制释放。
 */
class ActiveLockLease implements LockLease {
  /**
   * 锁的键名。
   */
  key: string;
  /**
   * 持有锁的键集合引用，引用自 LockManager.heldKeys。
   */
  private heldKeys: Set<string>;
  /**
   * 是否已释放（防止重复释放）。
   */
  private released: boolean = false;

  /**
   * 注入持锁集合，注册当前锁。
   * @param heldKeys 持锁键集合，来自 LockManager。
   * @param key 锁的键名。
   */
  constructor(heldKeys: Set<string>, key: string) {
    this.heldKeys = heldKeys;
    this.key = key;
  }

  /**
   * 释放锁：从持锁集合中移除当前键。
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
 * 空锁租赁（获取锁失败时的返回值），release 不执行任何操作。
 */
class EmptyLockLease implements LockLease {
  /**
   * 锁的键名。
   */
  key: string;

  /**
   * @param key 锁的键名。
   */
  constructor(key: string) {
    this.key = key;
  }

  /**
   * 空操作：未被获取的锁不需要释放。
   */
  release(): void {
  }
}

/**
 * 封装锁管理器相关状态和行为。
 * 在需要防止并发操作的关键路径中使用，如同步文件写入、避免重复创建等场景。
 */
export class LockManager {
  /**
   * 当前持有的键集合，用于判断锁是否已被占用。
   */
  private heldKeys: Set<string> = new Set<string>();

  /**
   * 获取锁；如果锁已被占用则抛出错误。
   * 在必须获取锁才能继续的关键操作中调用，如果获取失败则直接抛错。
   * @param key 要获取的锁键名，通常使用资源标识（如 chatId 或 messageId）。
   */
  async acquire(key: string): Promise<LockLease> {
    const result = await this.tryAcquire(key);
    if (!result.acquired) {
      throw new Error(`Lock already held: ${key}`);
    }
    return result.lease;
  }

  /**
   * 尝试获取锁（不抛出错误，通过返回结果判断）。
   * 在容忍获取失败的关键操作中调用，由调用方根据 TryLockResult.acquired 决定后续逻辑。
   * @param key 要获取的锁键名。
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
   * 释放指定键的锁（直接操作，不返回 lease）。
   * 在不方便管理 Lease 对象的场景下直接使用 key 释放锁。
   * @param key 要释放的锁键名。
   */
  release(key: string): void {
    this.heldKeys.delete(key);
  }
}
