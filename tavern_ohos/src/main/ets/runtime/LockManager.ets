export interface LockLease {
  key: string;

  release(): void;
}

export interface TryLockResult {
  acquired: boolean;
  lease: LockLease;
}

class ActiveLockLease implements LockLease {
  key: string;
  private heldKeys: Set<string>;
  private released: boolean = false;

  constructor(heldKeys: Set<string>, key: string) {
    this.heldKeys = heldKeys;
    this.key = key;
  }

  release(): void {
    if (this.released) {
      return;
    }
    this.released = true;
    this.heldKeys.delete(this.key);
  }
}

class EmptyLockLease implements LockLease {
  key: string;

  constructor(key: string) {
    this.key = key;
  }

  release(): void {
  }
}

export class LockManager {
  private heldKeys: Set<string> = new Set<string>();

  async acquire(key: string): Promise<LockLease> {
    const result = await this.tryAcquire(key);
    if (!result.acquired) {
      throw new Error(`Lock already held: ${key}`);
    }
    return result.lease;
  }

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

  release(key: string): void {
    this.heldKeys.delete(key);
  }
}
