/**
 * 描述调用标签能力时需要传入的参数。
 */
export interface TagCreateParams {
  /**
   * 可选的自定义标签标识；不传时由运行时自动生成。
   */
  id?: string;
  /**
   * 标签显示名称。
   */
  name: string;
  /**
   * 文件夹分类类型（如 "NONE" / "FOLDER" / ...）。
   */
  folderType?: string;
  /**
   * 过滤状态标记。
   */
  filterState?: string;
  /**
   * 排序优先级（值越小越靠前）。
   */
  sortOrder?: number;
  /**
   * 标签的主色值。
   */
  color?: string;
  /**
   * 标签的辅助色值。
   */
  color2?: string;
  /**
   * 是否在角色卡片上隐藏此标签。
   */
  hiddenOnCharacterCard?: boolean;
}

/**
 * 描述标签持久化或内存索引中的一条记录。
 */
export interface TagRecord {
  /**
   * 标签唯一标识。
   */
  id: string;
  /**
   * 标签显示名称。
   */
  name: string;
  /**
   * 文件夹分类类型（如 "NONE" / "FOLDER" / ...）。
   */
  folderType: string;
  /**
   * 过滤状态标记。
   */
  filterState: string;
  /**
   * 排序优先级（值越小越靠前）。
   */
  sortOrder: number;
  /**
   * 标签的主色值。
   */
  color: string;
  /**
   * 标签的辅助色值。
   */
  color2: string;
  /**
   * 标签创建时间戳。
   */
  createDate: number;
  /**
   * 是否在角色卡片上隐藏此标签。
   */
  hiddenOnCharacterCard: boolean;
}

/**
 * 描述标签操作完成后返回给调用方的结果。
 */
export interface TagImportResult {
  /**
   * 导入操作关联的实体键。
   */
  entityKey: string;
  /**
   * 已成功导入的标签记录列表。
   */
  imported: Array<TagRecord>;
  /**
   * 被忽略的标签名称列表。
   */
  ignored: Array<string>;
  /**
   * 本次导入过程中新创建的标签记录。
   */
  created: Array<TagRecord>;
}

/**
 * 描述标签事件发布时携带的数据结构。
 */
export interface TagEventPayload {
  /**
   * 变更事件关联的标签记录。
   */
  tag: TagRecord;
}

/**
 * 描述标签映射事件发布时携带的数据结构。
 */
export interface TagMapEventPayload {
  /**
   * 映射变更涉及的实体键。
   */
  entityKey: string;
  /**
   * 绑定到该实体的标签标识列表。
   */
  tagIds: Array<string>;
}
