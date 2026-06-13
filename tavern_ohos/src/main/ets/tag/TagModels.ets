/**
 * 描述调用标签能力时需要传入的参数。
 */
export interface TagCreateParams {
  /**
   * 标识。
   */
  id?: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * folder Type 值，由当前实例内部维护。
   */
  folderType?: string;
  /**
   * filter State 值，由当前实例内部维护。
   */
  filterState?: string;
  /**
   * sort Order 值，由当前实例内部维护。
   */
  sortOrder?: number;
  /**
   * color 值，由当前实例内部维护。
   */
  color?: string;
  /**
   * color2 值，由当前实例内部维护。
   */
  color2?: string;
  /**
   * hidden On Character Card 值，由当前实例内部维护。
   */
  hiddenOnCharacterCard?: boolean;
}

/**
 * 描述标签持久化或内存索引中的一条记录。
 */
export interface TagRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * folder Type 值，由当前实例内部维护。
   */
  folderType: string;
  /**
   * filter State 值，由当前实例内部维护。
   */
  filterState: string;
  /**
   * sort Order 值，由当前实例内部维护。
   */
  sortOrder: number;
  /**
   * color 值，由当前实例内部维护。
   */
  color: string;
  /**
   * color2 值，由当前实例内部维护。
   */
  color2: string;
  /**
   * create Date 值，由当前实例内部维护。
   */
  createDate: number;
  /**
   * hidden On Character Card 值，由当前实例内部维护。
   */
  hiddenOnCharacterCard: boolean;
}

/**
 * 描述标签操作完成后返回给调用方的结果。
 */
export interface TagImportResult {
  /**
   * entity Key 值，由当前实例内部维护。
   */
  entityKey: string;
  /**
   * 导入结果，由当前实例内部维护。
   */
  imported: Array<TagRecord>;
  /**
   * ignored 值，由当前实例内部维护。
   */
  ignored: Array<string>;
  /**
   * 创建后的记录，由当前实例内部维护。
   */
  created: Array<TagRecord>;
}

/**
 * 描述标签事件发布时携带的数据结构。
 */
export interface TagEventPayload {
  /**
   * tag 值，由当前实例内部维护。
   */
  tag: TagRecord;
}

/**
 * 描述标签事件发布时携带的数据结构。
 */
export interface TagMapEventPayload {
  /**
   * entity Key 值，由当前实例内部维护。
   */
  entityKey: string;
  /**
   * tag 标识列表。
   */
  tagIds: Array<string>;
}
