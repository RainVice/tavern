/**
 * 描述调用标签能力时需要传入的参数。
 * 在标签管理流程中，用于创建或更新标签记录。
 */
export interface TagCreateParams {
  /**
   * 标签 ID（可选，不传时自动生成）。用于在导入场景中保留原始 ID 或指定特定标识。
   */
  id?: string;
  /**
   * 标签名称，在 TagRuntime 中作为去重依据，同名标签不允许重复创建。
   */
  name: string;
  /**
   * 文件夹类型（如 "NONE" / "FOLDER"），用于标记标签是否为文件夹标签，影响 UI 展示的树形结构。
   */
  folderType?: string;
  /**
   * 过滤器状态，用于 UI 上的标签筛选逻辑，自定义扩展字段。
   */
  filterState?: string;
  /**
   * 手动排序的序号，用于自定义排序模式下标签在列表中的顺序位置。
   */
  sortOrder?: number;
  /**
   * 标签显示颜色，用于 UI 上的标签标记颜色（如主色/前景色）。
   */
  color?: string;
  /**
   * 标签辅助颜色（如渐变尾色），用于 UI 上更丰富的颜色展示。
   */
  color2?: string;
  /**
   * 是否在角色卡上隐藏该标签，影响标签在角色详情页面的可见性。
   */
  hiddenOnCharacterCard?: boolean;
}

/**
 * 描述标签持久化或内存索引中的一条记录。
 * 在标签管理流程中，用于标识和分类角色、聊天等实体。
 */
export interface TagRecord {
  /**
   * 标签唯一标识，由 createTag 自动生成或通过 params.id 指定。
   */
  id: string;
  /**
   * 标签名称，用于去重和 UI 展示。
   */
  name: string;
  /**
   * 文件夹类型（如 "NONE" / "FOLDER"），决定标签在 UI 上是否以文件夹形式展示。
   */
  folderType: string;
  /**
   * 过滤器状态，自定义扩展字段。
   */
  filterState: string;
  /**
   * 手动排序序号，用于自定义排序模式下标签在列表中的顺序。
   */
  sortOrder: number;
  /**
   * 标签显示颜色。
   */
  color: string;
  /**
   * 标签辅助颜色。
   */
  color2: string;
  /**
   * 创建日期时间戳（毫秒）。
   */
  createDate: number;
  /**
   * 是否在角色卡上隐藏。
   */
  hiddenOnCharacterCard: boolean;
}

/**
 * 描述标签导入操作完成后返回的结果。
 * 在从外部数据（如角色卡文件）解析并导入标签时使用，记录导入的详细统计信息。
 */
export interface TagImportResult {
  /**
   * 导入操作关联的实体键（如角色或聊天的标识），用于确定标签绑定到哪个实体。
   */
  entityKey: string;
  /**
   * 成功导入的标签记录列表，包含已创建和已有的标签。
   */
  imported: Array<TagRecord>;
  /**
   * 被忽略的标签名称列表，因策略限制（如 none 策略或 only_existing 策略下不存在的标签）未导入。
   */
  ignored: Array<string>;
  /**
   * 本次导入过程中新创建的标签记录，区别于已存在的标签。
   */
  created: Array<TagRecord>;
}

/**
 * 描述标签事件发布时携带的数据结构。
 * TagRuntime 在创建或更新标签后发布，通知宿主 UI 更新标签展示。
 */
export interface TagEventPayload {
  /**
   * 变更的标签记录。
   */
  tag: TagRecord;
}

/**
 * 描述标签映射事件发布时携带的数据结构。
 * TagRuntime 在标签-实体映射关系变更后发布，通知宿主 UI 刷新标签关联状态。
 */
export interface TagMapEventPayload {
  /**
   * 实体键（关联的聊天/角色标识），确定哪个实体的标签映射发生了变化。
   */
  entityKey: string;
  /**
   * 与该实体关联的标签 ID 列表。
   */
  tagIds: Array<string>;
}
