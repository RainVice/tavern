/**
 * 描述世界书模块在运行时交换的数据结构。
 */
export interface WorldBook {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * next Entry 标识。
   */
  nextEntryId: number;
  /**
   * 条目列表，由当前实例内部维护。
   */
  entries: Array<WorldInfoEntry>;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述世界书模块在运行时交换的数据结构。
 */
export interface WorldBookIndex {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * next 标识。
   */
  nextId: number;
  /**
   * 项目列表，由当前实例内部维护。
   */
  items: Array<WorldBookIndexEntry>;
}

/**
 * 描述世界书持久化或内存索引中的一条记录。
 */
export interface WorldBookIndexEntry {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * entry Count 值，由当前实例内部维护。
   */
  entryCount: number;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述调用世界书能力时需要传入的参数。
 */
export interface WorldInfoEntryCreateParams {
  /**
   * comment 值，由当前实例内部维护。
   */
  comment: string;
  /**
   * keys 列表，由当前实例内部维护。
   */
  keys: Array<string>;
  /**
   * secondary Keys 列表，由当前实例内部维护。
   */
  secondaryKeys: Array<string>;
  /**
   * 内容。
   */
  content: string;
  /**
   * constant 值，由当前实例内部维护。
   */
  constant: boolean;
  /**
   * selective 值，由当前实例内部维护。
   */
  selective: boolean;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * insertion Order 值，由当前实例内部维护。
   */
  insertionOrder: number;
  /**
   * position 值，由当前实例内部维护。
   */
  position: string;
  /**
   * case Sensitive 值，由当前实例内部维护。
   */
  caseSensitive: boolean;
}

/**
 * 描述调用世界书能力时需要传入的参数。
 */
export interface WorldInfoEntryUpdateParams {
  /**
   * comment 值，由当前实例内部维护。
   */
  comment: string;
  /**
   * keys 列表，由当前实例内部维护。
   */
  keys: Array<string>;
  /**
   * secondary Keys 列表，由当前实例内部维护。
   */
  secondaryKeys: Array<string>;
  /**
   * 内容。
   */
  content: string;
  /**
   * constant 值，由当前实例内部维护。
   */
  constant: boolean;
  /**
   * selective 值，由当前实例内部维护。
   */
  selective: boolean;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * insertion Order 值，由当前实例内部维护。
   */
  insertionOrder: number;
  /**
   * position 值，由当前实例内部维护。
   */
  position: string;
  /**
   * case Sensitive 值，由当前实例内部维护。
   */
  caseSensitive: boolean;
}

/**
 * 描述世界书持久化或内存索引中的一条记录。
 */
export interface WorldInfoEntry {
  /**
   * 标识。
   */
  id: string;
  /**
   * uid 值，由当前实例内部维护。
   */
  uid: number;
  /**
   * comment 值，由当前实例内部维护。
   */
  comment: string;
  /**
   * keys 列表，由当前实例内部维护。
   */
  keys: Array<string>;
  /**
   * secondary Keys 列表，由当前实例内部维护。
   */
  secondaryKeys: Array<string>;
  /**
   * 内容。
   */
  content: string;
  /**
   * constant 值，由当前实例内部维护。
   */
  constant: boolean;
  /**
   * selective 值，由当前实例内部维护。
   */
  selective: boolean;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * insertion Order 值，由当前实例内部维护。
   */
  insertionOrder: number;
  /**
   * position 值，由当前实例内部维护。
   */
  position: string;
  /**
   * case Sensitive 值，由当前实例内部维护。
   */
  caseSensitive: boolean;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述世界书模块在运行时交换的数据结构。
 */
export interface WorldInfoActivation {
  /**
   * 条目列表，由当前实例内部维护。
   */
  entries: Array<WorldInfoEntry>;
  /**
   * matches 列表，由当前实例内部维护。
   */
  matches: Array<WorldInfoMatch>;
  /**
   * prompt Text 值，由当前实例内部维护。
   */
  promptText: string;
}

/**
 * 描述世界书模块在运行时交换的数据结构。
 */
export interface WorldInfoMatch {
  /**
   * 世界书标识。
   */
  worldBookId: string;
  /**
   * 条目标识。
   */
  entryId: string;
  /**
   * 键名，由当前实例内部维护。
   */
  key: string;
}

/**
 * 描述世界书事件发布时携带的数据结构。
 */
export interface WorldInfoActivationPayload {
  /**
   * world Book 标识列表。
   */
  worldBookIds: Array<string>;
  /**
   * 条目列表，由当前实例内部维护。
   */
  entries: Array<WorldInfoEntry>;
  /**
   * matches 列表，由当前实例内部维护。
   */
  matches: Array<WorldInfoMatch>;
}

/**
 * 描述世界书模块在运行时交换的数据结构。
 */
export interface WorldInfoImportData {
  /**
   * schema Version 值，由当前实例内部维护。
   */
  schemaVersion: number;
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * next Entry 标识。
   */
  nextEntryId: number;
  /**
   * 条目列表，由当前实例内部维护。
   */
  entries: Array<WorldInfoEntry>;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述世界书事件发布时携带的数据结构。
 */
export interface WorldInfoEventPayload {
  /**
   * world Book 值，由当前实例内部维护。
   */
  worldBook: WorldBook;
}
