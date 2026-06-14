/**
 * 描述创建角色卡时需要传入的参数，用于角色创建流程的输入验证和数据组装。
 */
export interface CharacterCreateParams {
  /**
   * 角色名称，用于在聊天界面和角色列表中标识该角色。
   */
  name: string;
  /**
   * 角色的文字描述，用于 AI 理解角色背景并生成背景一致的回复。
   */
  description: string;
  /**
   * 角色的性格描述，用于 AI 生成符合角色个性的对话风格。
   */
  personality: string;
  /**
   * 当前对话场景设定，用于为 AI 提供对话发生的环境上下文。
   */
  scenario: string;
  /**
   * 角色的第一条开场消息，在开始新对话时自动发送以引导对话方向。
   */
  firstMessage: string;
  /**
   * 角色的对话示例，用于引导 AI 模仿角色的说话方式和语言习惯。
   */
  exampleDialogue: string;
  /**
   * 角色标签列表，用于在角色列表中的分类筛选和搜索匹配。
   */
  tags: Array<string>;
  /**
   * 是否标记为收藏角色，用于在角色列表中快速筛选收藏项，可选。
   */
  favorite?: boolean;
  /**
   * 角色的话痨程度（0.0-1.0），用于影响 AI 回复的详细程度和主动发言倾向，可选。
   */
  talkativeness?: number;
  /**
   * 角色关联的世界设定标识，用于在对话中附加世界书 (Lorebook) 内容，可选。
   */
  world?: string;
}

/**
 * 描述更新角色卡时需要传入的参数，用于角色编辑流程的数据提交。
 */
export interface CharacterUpdateParams {
  /**
   * 角色名称，用于在聊天界面和角色列表中标识该角色。
   */
  name: string;
  /**
   * 角色的文字描述，用于 AI 理解角色背景并生成背景一致的回复。
   */
  description: string;
  /**
   * 角色的性格描述，用于 AI 生成符合角色个性的对话风格。
   */
  personality: string;
  /**
   * 当前对话场景设定，用于为 AI 提供对话发生的环境上下文。
   */
  scenario: string;
  /**
   * 角色的第一条开场消息，在开始新对话时自动发送以引导对话方向。
   */
  firstMessage: string;
  /**
   * 角色的对话示例，用于引导 AI 模仿角色的说话方式和语言习惯。
   */
  exampleDialogue: string;
  /**
   * 角色标签列表，用于在角色列表中的分类筛选和搜索匹配。
   */
  tags: Array<string>;
  /**
   * 是否标记为收藏角色，用于在角色列表中快速筛选收藏项。
   */
  favorite: boolean;
}

/**
 * 描述角色卡持久化存储或内存索引中的完整记录，用于角色管理全流程（创建、查询、更新、删除）的数据载体。
 */
export interface CharacterRecord {
  /**
   * schema 版本号，用于数据格式向下兼容和数据迁移的判断依据。
   */
  schemaVersion: number;
  /**
   * 角色记录的唯一标识，用于索引、关联聊天记录以及文件路径命名。
   */
  id: string;
  /**
   * 角色名称，用于在聊天界面和角色列表中标识该角色。
   */
  name: string;
  /**
   * 角色的文字描述，用于 AI 理解角色背景并生成背景一致的回复。
   */
  description: string;
  /**
   * 角色的性格描述，用于 AI 生成符合角色个性的对话风格。
   */
  personality: string;
  /**
   * 当前对话场景设定，用于为 AI 提供对话发生的环境上下文。
   */
  scenario: string;
  /**
   * 角色的第一条开场消息，在开始新对话时自动发送以引导对话方向。
   */
  firstMessage: string;
  /**
   * 角色的对话示例，用于引导 AI 模仿角色的说话方式和语言习惯。
   */
  exampleDialogue: string;
  /**
   * 角色创建者的备注说明，用于记录导入来源或自定义备忘，仅在详情页展示。
   */
  creatorNotes: string;
  /**
   * 自定义系统提示词，覆盖默认的 AI 行为指引，用于深度定制角色行为模式。
   */
  systemPrompt: string;
  /**
   * 对话历史结束后注入的额外指令，用于在每次 AI 回复前附加约束条件。
   */
  postHistoryInstructions: string;
  /**
   * 角色创建者名称，用于在角色详情中展示来源信息。
   */
  creator: string;
  /**
   * 角色卡的版本标识，用于追踪角色卡的迭代和变更记录。
   */
  characterVersion: string;
  /**
   * 角色头像文件的存储路径，用于角色列表和聊天窗口的头像展示。
   */
  avatarPath: string;
  /**
   * 角色标签列表，用于在角色列表中的分类筛选和搜索匹配。
   */
  tags: Array<string>;
  /**
   * 替代开场问候语列表，可在对话开始时让用户从多个开场白中选择。
   */
  alternateGreetings: Array<string>;
  /**
   * 是否标记为收藏角色，用于在角色列表中快速筛选收藏项。
   */
  favorite: boolean;
  /**
   * 角色的话痨程度（0.0-1.0），用于影响 AI 回复的详细程度和主动发言倾向。
   */
  talkativeness: number;
  /**
   * 角色关联的世界设定标识，用于在对话中附加世界书 (Lorebook) 内容。
   */
  world: string;
  /**
   * 角色卡的原始来源格式标记，如 'runtime_json' 或 'character_card_v2_json'，用于导入导出格式兼容。
   */
  sourceFormat: string;
  /**
   * 导入时保留的角色卡原始 JSON 字符串，用于直接导出原始格式而非重新构建。
   */
  sourceJson: string;
  /**
   * 角色记录的创建时间戳（毫秒），用于列表排序和时间线展示。
   */
  createdAt: number;
  /**
   * 角色记录的最后更新时间戳（毫秒），用于冲突检测和列表重排序。
   */
  updatedAt: number;
}

/**
 * 描述角色卡索引中的摘要条目，用于角色列表页的快速展示，避免加载完整角色记录。
 */
export interface CharacterIndexEntry {
  /**
   * 角色记录的唯一标识，用于关联索引条目与完整角色记录。
   */
  id: string;
  /**
   * 角色名称，用于在角色列表中显示条目标题。
   */
  name: string;
  /**
   * 角色头像文件的存储路径，用于在角色列表中展示头像缩略图。
   */
  avatarPath: string;
  /**
   * 角色标签列表，用于角色列表的分类筛选和搜索匹配。
   */
  tags: Array<string>;
  /**
   * 是否标记为收藏角色，用于在角色列表中高亮显示收藏项。
   */
  favorite: boolean;
  /**
   * 角色记录的创建时间戳（毫秒），用于列表排序。
   */
  createdAt: number;
  /**
   * 角色记录的最后更新时间戳（毫秒），用于列表按最近更新排序。
   */
  updatedAt: number;
}

/**
 * 描述角色卡模块在运行时交换的索引数据结构，用于角色列表查询和自增 ID 管理。
 */
export interface CharacterIndex {
  /**
   * schema 版本号，用于索引数据格式的向下兼容和迁移判断。
   */
  schemaVersion: number;
  /**
   * 下一条角色记录的自增编号，用于 createCharacter 时生成新的唯一标识。
   */
  nextId: number;
  /**
   * 角色索引条目列表，按创建顺序排列，用于角色列表展示。
   */
  items: Array<CharacterIndexEntry>;
}

/**
 * 描述角色数据变更事件（创建/更新）发布时携带的数据结构，供监听者获取变更后的角色副本用于 UI 刷新等后续处理。
 */
export interface CharacterEventPayload {
  /**
   * 发生变更的角色记录副本，供事件订阅者用于 UI 更新或联动处理。
   */
  character: CharacterRecord;
}

/**
 * 描述角色删除事件发布时携带的数据结构，供监听者清理与该角色关联的资源。
 */
export interface CharacterDeletedPayload {
  /**
   * 被删除的角色标识，供事件订阅者用于清理关联的聊天、配置等资源。
   */
  characterId: string;
}

/**
 * 描述 SillyTavern 角色卡 V2 格式的数据结构，用于导入/导出流程中与外部 SillyTavern 生态的角色卡交换。
 */
export interface CharacterCardV2 {
  /**
   * 角色卡规范标识，固定为 'chara_card_v2'，用于在导入时自动识别格式版本。
   */
  spec: string;
  /**
   * 角色卡规范版本号，如 '2.0'，用于导入时校验版本兼容性。
   */
  spec_version: string;
  /**
   * 角色卡的核心数据内容，包含角色名称、描述、对话示例等所有角色字段。
   */
  data: CharacterCardV2Data;
}

/**
 * 描述 SillyTavern 角色卡 V2 格式的核心数据字段，用于在导入/导出时转换角色信息。
 */
export interface CharacterCardV2Data {
  /**
   * 角色名称，用于在聊天界面和角色列表中标识该角色。
   */
  name: string;
  /**
   * 角色的文字描述，用于 AI 理解角色背景并生成背景一致的回复。
   */
  description: string;
  /**
   * 角色的性格描述，用于 AI 生成符合角色个性的对话风格。
   */
  personality: string;
  /**
   * 当前对话场景设定，用于为 AI 提供对话发生的环境上下文。
   */
  scenario: string;
  /**
   * 角色的第一条开场消息（V2 命名 first_mes），在开始新对话时自动发送。
   */
  first_mes: string;
  /**
   * 角色的对话示例（V2 命名 mes_example），用于引导 AI 模仿角色的说话方式。
   */
  mes_example: string;
  /**
   * 角色创建者的备注说明，用于记录导入来源或自定义备忘，可选。
   */
  creator_notes?: string;
  /**
   * 自定义系统提示词，覆盖默认的 AI 行为指引，可选。
   */
  system_prompt?: string;
  /**
   * 对话历史结束后注入的额外指令，用于在每次 AI 回复前附加约束条件，可选。
   */
  post_history_instructions?: string;
  /**
   * 角色创建者名称，用于在角色详情中展示来源信息，可选。
   */
  creator?: string;
  /**
   * 角色卡的版本标识，用于追踪角色卡的迭代和变更记录，可选。
   */
  character_version?: string;
  /**
   * 角色标签列表，用于在角色列表中的分类筛选和搜索匹配，可选。
   */
  tags?: Array<string>;
  /**
   * 替代开场问候语列表，可在对话开始时让用户从多个开场白中选择，可选。
   */
  alternate_greetings?: Array<string>;
  /**
   * 角色卡扩展字段，用于存储收藏状态、话痨程度等运行时特有的非标准字段，可选。
   */
  extensions?: CharacterCardV2Extensions;
}

/**
 * 描述 SillyTavern 角色卡 V2 格式的扩展字段，用于存储运行时特有的扩展属性。
 */
export interface CharacterCardV2Extensions {
  /**
   * 是否收藏，用于在角色列表中高亮显示收藏项，可选。
   */
  fav?: boolean;
  /**
   * 话痨程度（0.0-1.0），用于影响 AI 回复的详细程度和主动发言倾向，可选。
   */
  talkativeness?: number;
  /**
   * 角色关联的世界设定标识，用于在对话中附加世界书 (Lorebook) 内容，可选。
   */
  world?: string;
}
