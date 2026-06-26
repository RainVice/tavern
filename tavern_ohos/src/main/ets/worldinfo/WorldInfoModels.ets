/**
 * 一个完整的世界书，包含所有条目元数据。
 */
export interface WorldBook {
  /**
   * 数据格式版本号，用于迁移兼容。
   */
  schemaVersion: number;
  /**
   * 世界书的唯一标识符。
   */
  id: string;
  /**
   * 世界书的显示名称。
   */
  name: string;
  /**
   * 下一条新增条目的递进序号。
   */
  nextEntryId: number;
  /**
   * 世界书中的条目列表。
   */
  entries: Array<WorldInfoEntry>;
  /**
   * 世界书的创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 世界书的最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 世界书索引，用于快速检索和展示所有世界书的概要信息。
 */
export interface WorldBookIndex {
  /**
   * 数据格式版本号，用于迁移兼容。
   */
  schemaVersion: number;
  /**
   * 下一个世界书 ID 的递进序号。
   */
  nextId: number;
  /**
   * 索引项列表。
   */
  items: Array<WorldBookIndexEntry>;
}

/**
 * 世界书索引中的单条摘要信息。
 */
export interface WorldBookIndexEntry {
  /**
   * 世界书的唯一标识符。
   */
  id: string;
  /**
   * 世界书的显示名称。
   */
  name: string;
  /**
   * 世界书中的条目数量。
   */
  entryCount: number;
  /**
   * 世界书的创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 世界书的最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 创建世界书条目时需要传入的参数。
 */
export interface WorldInfoEntryCreateParams {
  /**
   * 条目的备注说明。
   */
  comment: string;
  /**
   * 主要关键词列表，用于文本匹配触发。
   */
  keys: Array<string>;
  /**
   * 次要关键词列表，与主要关键词配合用于选择性激活。
   */
  secondaryKeys: Array<string>;
  /**
   * 条目触发时注入的文本内容。
   */
  content: string;
  /**
   * 是否为常驻激活（忽略关键词匹配）。
   */
  constant: boolean;
  /**
   * 是否启用选择性匹配（需要同时命中主要和次要关键词）。
   */
  selective: boolean;
  /**
   * 条目是否启用。
   */
  enabled: boolean;
  /**
   * 条目在激活时的插入顺序序号。
   */
  insertionOrder: number;
  /**
   * 条目内容在提示词中的插入位置策略。
   */
  position: string;
  /**
   * 关键词匹配是否区分大小写。
   */
  caseSensitive: boolean;
  /**
   * 是否整词匹配关键词。
   */
  matchWholeWords?: boolean;
  /**
   * 条目触发概率，范围 0-100。
   */
  probability?: number;
  /**
   * 递归激活时是否禁止把本条内容继续放入扫描缓冲区。
   */
  excludeRecursion?: boolean;
  /**
   * 条目深度设置，由宿主 Prompt 流程解释。
   */
  depth?: number;
  /**
   * 递归扫描深度设置，由宿主 Prompt 流程解释。
   */
  scanDepth?: number;
  /**
   * 角色过滤策略，由宿主 Prompt 流程解释。
   */
  role?: string;
  /**
   * 条目分组名称。
   */
  group?: string;
  /**
   * 是否覆盖分组策略。
   */
  groupOverride?: boolean;
  /**
   * 分组权重。
   */
  groupWeight?: number;
  /**
   * 自动化标识。
   */
  automationId?: string;
}

/**
 * 更新世界书条目时需要传入的参数，字段含义与创建参数一致。
 */
export interface WorldInfoEntryUpdateParams {
  /**
   * 条目的备注说明。
   */
  comment: string;
  /**
   * 主要关键词列表，用于文本匹配触发。
   */
  keys: Array<string>;
  /**
   * 次要关键词列表，与主要关键词配合用于选择性激活。
   */
  secondaryKeys: Array<string>;
  /**
   * 条目触发时注入的文本内容。
   */
  content: string;
  /**
   * 是否为常驻激活（忽略关键词匹配）。
   */
  constant: boolean;
  /**
   * 是否启用选择性匹配。
   */
  selective: boolean;
  /**
   * 条目是否启用。
   */
  enabled: boolean;
  /**
   * 条目在激活时的插入顺序序号。
   */
  insertionOrder: number;
  /**
   * 条目内容在提示词中的插入位置策略。
   */
  position: string;
  /**
   * 关键词匹配是否区分大小写。
   */
  caseSensitive: boolean;
  /**
   * 是否整词匹配关键词。
   */
  matchWholeWords?: boolean;
  /**
   * 条目触发概率，范围 0-100。
   */
  probability?: number;
  /**
   * 递归激活时是否禁止把本条内容继续放入扫描缓冲区。
   */
  excludeRecursion?: boolean;
  /**
   * 条目深度设置，由宿主 Prompt 流程解释。
   */
  depth?: number;
  /**
   * 递归扫描深度设置，由宿主 Prompt 流程解释。
   */
  scanDepth?: number;
  /**
   * 角色过滤策略，由宿主 Prompt 流程解释。
   */
  role?: string;
  /**
   * 条目分组名称。
   */
  group?: string;
  /**
   * 是否覆盖分组策略。
   */
  groupOverride?: boolean;
  /**
   * 分组权重。
   */
  groupWeight?: number;
  /**
   * 自动化标识。
   */
  automationId?: string;
}

/**
 * 世界书中的一个条目，包含关键词组和触发内容。
 */
export interface WorldInfoEntry {
  /**
   * 条目的唯一标识符。
   */
  id: string;
  /**
   * 条目的递进序号（与 id 相对应）。
   */
  uid: number;
  /**
   * 条目的备注说明。
   */
  comment: string;
  /**
   * 主要关键词列表，用于文本匹配触发。
   */
  keys: Array<string>;
  /**
   * 次要关键词列表，与主要关键词配合用于选择性激活。
   */
  secondaryKeys: Array<string>;
  /**
   * 条目触发时注入的文本内容。
   */
  content: string;
  /**
   * 是否为常驻激活（忽略关键词匹配）。
   */
  constant: boolean;
  /**
   * 是否启用选择性匹配。
   */
  selective: boolean;
  /**
   * 条目是否启用。
   */
  enabled: boolean;
  /**
   * 条目在激活时的插入顺序序号。
   */
  insertionOrder: number;
  /**
   * 条目内容在提示词中的插入位置策略。
   */
  position: string;
  /**
   * 关键词匹配是否区分大小写。
   */
  caseSensitive: boolean;
  /**
   * 是否整词匹配关键词。
   */
  matchWholeWords?: boolean;
  /**
   * 条目触发概率，范围 0-100。
   */
  probability?: number;
  /**
   * 递归激活时是否禁止把本条内容继续放入扫描缓冲区。
   */
  excludeRecursion?: boolean;
  /**
   * 条目深度设置，由宿主 Prompt 流程解释。
   */
  depth?: number;
  /**
   * 递归扫描深度设置，由宿主 Prompt 流程解释。
   */
  scanDepth?: number;
  /**
   * 角色过滤策略，由宿主 Prompt 流程解释。
   */
  role?: string;
  /**
   * 条目分组名称。
   */
  group?: string;
  /**
   * 是否覆盖分组策略。
   */
  groupOverride?: boolean;
  /**
   * 分组权重。
   */
  groupWeight?: number;
  /**
   * 自动化标识。
   */
  automationId?: string;
  /**
   * 条目的创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 条目的最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 世界书激活的结果，包含匹配的条目和生成的提示词文本。
 */
export interface WorldInfoActivation {
  /**
   * 激活的条目列表。
   */
  entries: Array<WorldInfoEntry>;
  /**
   * 匹配详情列表。
   */
  matches: Array<WorldInfoMatch>;
  /**
   * 拼接后的提示词文本。
   */
  promptText: string;
}

/**
 * 描述单次关键词匹配的结果。
 */
export interface WorldInfoMatch {
  /**
   * 命中的世界书标识。
   */
  worldBookId: string;
  /**
   * 命中的条目标识。
   */
  entryId: string;
  /**
   * 匹配到的关键词。
   */
  key: string;
}

/**
 * 世界书激活事件发布时携带的数据载荷。
 */
export interface WorldInfoActivationPayload {
  /**
   * 参与激活的世界书标识列表。
   */
  worldBookIds: Array<string>;
  /**
   * 激活的条目列表。
   */
  entries: Array<WorldInfoEntry>;
  /**
   * 匹配详情列表。
   */
  matches: Array<WorldInfoMatch>;
}

/**
 * 从外部导入的世界书数据格式。
 */
export interface WorldInfoImportData {
  /**
   * 数据格式版本号。
   */
  schemaVersion: number;
  /**
   * 世界书的唯一标识符。
   */
  id: string;
  /**
   * 世界书的显示名称。
   */
  name: string;
  /**
   * 导入时的下一条条目递进序号。
   */
  nextEntryId: number;
  /**
   * 条目列表。
   */
  entries: Array<WorldInfoEntry>;
  /**
   * 创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 世界书变更事件发布时携带的数据载荷。
 */
export interface WorldInfoEventPayload {
  /**
   * 变更后的世界书记录。
   */
  worldBook: WorldBook;
}
