/**
 * 描述世界书模块在运行时交换的数据结构。
 */
export interface WorldBook {
  /**
   * 数据模式版本号，用于世界书数据格式的兼容性检测和迁移。
   */
  schemaVersion: number;
  /**
   * 世界书唯一标识，用于世界书的查询、删除和导入导出等操作。
   */
  id: string;
  /**
   * 世界书名称，用于在管理界面中标识和展示。
   */
  name: string;
  /**
   * 下一条目的自动递增 ID，用于保证条目 ID 在添加时递增且不重复。
   */
  nextEntryId: number;
  /**
   * 世界书包含的条目列表，每个条目包含关键词、内容、触发条件等完整定义。
   */
  entries: Array<WorldInfoEntry>;
  /**
   * 世界书创建时间戳（毫秒），用于记录世界书的创建时间。
   */
  createdAt: number;
  /**
   * 世界书最后更新时间戳（毫秒），用于追踪世界书的最近修改时间。
   */
  updatedAt: number;
}

/**
 * 描述世界书索引结构，用于快速列出所有世界书而不必逐个加载完整数据。
 */
export interface WorldBookIndex {
  /**
   * 数据模式版本号，用于索引数据格式的兼容性检测。
   */
  schemaVersion: number;
  /**
   * 下一个可用的 ID 编号，用于自动增长的世界书 ID 分配。
   */
  nextId: number;
  /**
   * 索引项列表，每个项包含世界书的概要信息，供管理页面快速展示。
   */
  items: Array<WorldBookIndexEntry>;
}

/**
 * 描述世界书索引中的一条概要记录，用于世界书列表快速展示，无需加载完整的世界书数据。
 */
export interface WorldBookIndexEntry {
  /**
   * 世界书唯一标识，用于索引查询和完整数据加载的关联键。
   */
  id: string;
  /**
   * 世界书名称，用于管理界面中标识世界书。
   */
  name: string;
  /**
   * 世界书中的条目数量，用于在列表页展示条目计数。
   */
  entryCount: number;
  /**
   * 世界书创建时间戳（毫秒），用于列表排序和时间展示。
   */
  createdAt: number;
  /**
   * 世界书最后更新时间戳（毫秒），用于列表排序和最近修改时间展示。
   */
  updatedAt: number;
}

/**
 * 描述创建世界书条目时需要传入的参数，定义了条目触发的关键词、内容和行为配置。
 */
export interface WorldInfoEntryCreateParams {
  /**
   * 条目注释/说明，用于在管理界面中描述条目用途。
   */
  comment: string;
  /**
   * 触发关键词列表，用于在消息文本中匹配并激活该条目。
   */
  keys: Array<string>;
  /**
   * 次要关键词列表（配合 selective 模式使用），需与主要关键词同时命中才激活。
   */
  secondaryKeys: Array<string>;
  /**
   * 条目内容（插入到提示词中的文本），当条目被激活时注入到模型输入中，用于影响模型行为。
   */
  content: string;
  /**
   * 是否为常驻条目（始终激活，不依赖关键词匹配），用于始终生效的背景设定。
   */
  constant: boolean;
  /**
   * 是否需要主要和次要关键词同时匹配才激活，用于提高匹配精度。
   */
  selective: boolean;
  /**
   * 条目是否启用，控制条目是否参与关键词匹配和激活。
   */
  enabled: boolean;
  /**
   * 插入顺序权重，影响条目在提示词中的排列顺序，用于控制不同条目的优先级。
   */
  insertionOrder: number;
  /**
   * 条目在提示词中的插入位置（如前面、后面等），用于控制条目在提示词中的位置策略。
   */
  position: string;
  /**
   * 关键词匹配是否区分大小写，用于控制匹配的严格程度。
   */
  caseSensitive: boolean;
}

/**
 * 描述更新世界书条目时需要传入的参数，与创建参数结构一致，用于在编辑条目时写入新值。
 */
export interface WorldInfoEntryUpdateParams {
  /**
   * 条目注释/说明，用于在管理界面中描述条目用途。
   */
  comment: string;
  /**
   * 触发关键词列表，用于在消息文本中匹配并激活该条目。
   */
  keys: Array<string>;
  /**
   * 次要关键词列表（配合 selective 模式使用），需与主要关键词同时命中才激活。
   */
  secondaryKeys: Array<string>;
  /**
   * 条目内容，当条目被激活时注入到模型输入中的文本。
   */
  content: string;
  /**
   * 是否为常驻条目，始终激活不依赖关键词匹配。
   */
  constant: boolean;
  /**
   * 是否需要主要和次要关键词同时匹配。
   */
  selective: boolean;
  /**
   * 条目是否启用。
   */
  enabled: boolean;
  /**
   * 插入顺序权重，影响提示词中的排列顺序。
   */
  insertionOrder: number;
  /**
   * 条目在提示词中的插入位置。
   */
  position: string;
  /**
   * 关键词匹配是否区分大小写。
   */
  caseSensitive: boolean;
}

/**
 * 描述世界书中的单个条目持久化记录，包含条目 ID、关键词、内容和触发配置等完整信息。
 */
export interface WorldInfoEntry {
  /**
   * 条目唯一标识，格式为 "entry-N"，用于条目查询、更新和删除操作。
   */
  id: string;
  /**
   * 条目内部序列号，用于 ID 去重和排序，保持与 nextEntryId 的数值一致性。
   */
  uid: number;
  /**
   * 条目注释/说明，用于管理界面中的人类可读备注。
   */
  comment: string;
  /**
   * 触发关键词列表，用于在消息文本中匹配并激活该条目。
   */
  keys: Array<string>;
  /**
   * 次要关键词列表，配合 selective 模式使用以提高匹配精度。
   */
  secondaryKeys: Array<string>;
  /**
   * 条目内容，当条目被激活时注入到提示词中影响模型行为的文本。
   */
  content: string;
  /**
   * 是否为常驻条目，始终激活不依赖关键词。
   */
  constant: boolean;
  /**
   * 是否需要主要和次要关键词同时匹配。
   */
  selective: boolean;
  /**
   * 条目是否启用。
   */
  enabled: boolean;
  /**
   * 插入顺序权重，影响条目在提示词中的排列顺序。
   */
  insertionOrder: number;
  /**
   * 条目在提示词中的插入位置（如前置、后置等）。
   */
  position: string;
  /**
   * 关键词匹配是否区分大小写。
   */
  caseSensitive: boolean;
  /**
   * 条目创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 条目最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 描述世界书条目激活操作完成后返回的结果，包含激活的条目、匹配信息和组装后的提示词文本。
 */
export interface WorldInfoActivation {
  /**
   * 激活的条目列表，每个条目包含完整定义，供模型输入构建时使用。
   */
  entries: Array<WorldInfoEntry>;
  /**
   * 条目的匹配信息列表，标识每个条目因何关键词被激活，用于调试和展示。
   */
  matches: Array<WorldInfoMatch>;
  /**
   * 组装后的提示词文本（所有激活条目的内容拼接而成），用于直接注入到模型输入中。
   */
  promptText: string;
}

/**
 * 描述世界书条目的关键词匹配结果，标识哪个世界书的哪个条目因哪个关键词被触发。
 */
export interface WorldInfoMatch {
  /**
   * 匹配来源的世界书标识，用于追溯匹配结果归属。
   */
  worldBookId: string;
  /**
   * 匹配的条目标识，用于定位具体被激活的条目。
   */
  entryId: string;
  /**
   * 命中的关键词，用于展示匹配详情和调试。
   */
  key: string;
}

/**
 * 描述世界书条目激活事件发布时携带的数据结构，供事件订阅方在条目激活时执行后续处理。
 */
export interface WorldInfoActivationPayload {
  /**
   * 参与激活的世界书 ID 列表，供事件订阅方知晓数据来源。
   */
  worldBookIds: Array<string>;
  /**
   * 激活的条目列表，供事件订阅方获取所有被激活的条目。
   */
  entries: Array<WorldInfoEntry>;
  /**
   * 条目的匹配信息列表，供事件订阅方获取匹配详情。
   */
  matches: Array<WorldInfoMatch>;
}

/**
 * 描述世界书导入时使用的数据格式，与 WorldBook 结构一致，用于 JSON 反序列化导入。
 */
export interface WorldInfoImportData {
  /**
   * 数据模式版本号。
   */
  schemaVersion: number;
  /**
   * 世界书唯一标识（导入时会被重新分配）。
   */
  id: string;
  /**
   * 世界书名称（导入时可覆盖）。
   */
  name: string;
  /**
   * 下一条目的自动递增 ID。
   */
  nextEntryId: number;
  /**
   * 条目列表。
   */
  entries: Array<WorldInfoEntry>;
  /**
   * 世界书创建时间戳（毫秒）。
   */
  createdAt: number;
  /**
   * 世界书最后更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 描述世界书事件（创建、更新、删除、导入）发布时携带的数据结构。
 */
export interface WorldInfoEventPayload {
  /**
   * 事件关联的世界书数据，供事件订阅方获取完整的变更详情。
   */
  worldBook: WorldBook;
}
