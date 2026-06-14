/**
 * 描述调用群聊能力时需要传入的参数，
 * 用于在创建或更新群聊时向 GroupRuntime 提供完整的群聊配置信息。
 */
export interface GroupCreateParams {
  /**
   * 群聊的唯一标识，创建后作为 GroupRecord.id 持久化，
   * 用于在运行时索引中唯一标识一个群聊。
   */
  id: string;
  /**
   * 群聊名称，用于在 UI 群聊列表和提示词构建中显示群聊标题。
   */
  name: string;
  /**
   * 群聊描述信息，用于说明群聊的用途或背景设定。
   */
  description: string;
  /**
   * 关联的聊天标识，用于将此群聊与特定的聊天会话绑定，
   * 使得群聊内的消息归属于该聊天。
   */
  chatId: string;
  /**
   * 群聊是否启用（激活状态），控制群聊是否参与 AI 生成流程。
   */
  enabled: boolean;
  /**
   * 群聊发言激活策略，例如 'auto'（自动轮换）、'manual'（手动指定）、'rotate'（轮流），
   * 用于决定 selectSpeaker 时如何选取发言成员。
   */
  activationStrategy: string;
}

/**
 * 描述群聊持久化或内存索引中的一条记录，
 * 用于在 GroupRuntime 的 groups 索引中存储单个群聊的完整快照。
 */
export interface GroupRecord {
  /**
   * 数据模式的版本号，用于数据迁移兼容性判断，
   * 当未来 GroupRecord 结构发生变化时据此执行数据升级逻辑。
   */
  schemaVersion: number;
  /**
   * 群聊的唯一标识，作为 groups 索引中的主键，
   * 用于查找、更新、删除群聊以及关联成员和请求。
   */
  id: string;
  /**
   * 群聊名称，用于 UI 显示和提示词构建。
   */
  name: string;
  /**
   * 群聊描述信息，说明群聊的用途或背景设定。
   */
  description: string;
  /**
   * 关联的聊天标识，用于将群聊与特定聊天会话绑定，
   * 以便在聊天视图中展示群聊的对话历史。
   */
  chatId: string;
  /**
   * 绑定的用户人格标识，通过 bindPersona 设置，
   * 用于在提示词构建中提供用户的角色扮演身份信息。
   */
  personaId: string;
  /**
   * 群聊是否启用（激活状态），控制群聊是否参与 AI 生成流程。
   */
  enabled: boolean;
  /**
   * 群聊发言激活策略，例如 'auto'、'manual'、'rotate'，
   * 用于决定 selectSpeaker 时如何选取发言成员。
   */
  activationStrategy: string;
  /**
   * 记录创建时间戳（毫秒），群聊首次创建时设置。
   */
  createdAt: number;
  /**
   * 记录最后更新时间戳（毫秒），群聊信息更新时刷新。
   */
  updatedAt: number;
}

/**
 * 描述调用群聊能力时需要传入的参数，
 * 用于在向群聊添加成员时提供角色信息和发言行为配置。
 */
export interface GroupMemberCreateParams {
  /**
   * 成员对应的角色标识，用于关联角色系统中的角色数据，
   * 在移除成员时也通过此标识查找。
   */
  characterId: string;
  /**
   * 角色名称，用于在提示词构建中生成成员名称列表。
   */
  characterName: string;
  /**
   * 成员在群聊中的角色，如 'main_character'（主角）、'side_character'（配角）、'narrator'（旁白），
   * 用于影响 AI 生成时该成员的发言风格和行为模式。
   */
  role: string;
  /**
   * 成员在群聊中的发言活跃度，数值越高越可能被 selectMostTalkative 选中发言，
   * 用于调节群聊中各个角色的发言频率分布。
   */
  talkativeness: number;
  /**
   * 成员是否启用（在群聊中活跃），禁用的成员不会参与发言选择和提示词构建。
   */
  enabled: boolean;
  /**
   * 该成员激活时使用的世界信息文本，
   * 用于在 buildPromptData 中合并到世界信息，提供该成员独有的上下文。
   */
  worldInfoText: string;
}

/**
 * 描述群聊持久化或内存索引中的一条记录，
 * 用于在 GroupRuntime 的 members 索引中存储单个群聊成员的完整快照。
 */
export interface GroupMemberRecord {
  /**
   * 所属群聊的标识，用于在成员列表中关联到具体的群聊。
   */
  groupId: string;
  /**
   * 成员对应的角色标识，用于关联角色系统中的角色数据，
   * 在 findMember 和 removeMember 中通过此标识查找成员。
   */
  characterId: string;
  /**
   * 角色名称，用于在提示词构建和 UI 显示中展示成员名称。
   */
  characterName: string;
  /**
   * 成员在群聊中的角色，如 'main_character'、'side_character'、'narrator'，
   * 用于影响 AI 生成时该成员的发言风格。
   */
  role: string;
  /**
   * 成员在群聊中的排序序号，由 addMember 自动设置或 reorderMembers 调整，
   * 用于控制成员在 UI 列表和提示词中的排列顺序。
   */
  order: number;
  /**
   * 成员的发言活跃度，数值越高越可能被 selectMostTalkative 选中发言，
   * 用于调节群聊中各角色的发言频率。
   */
  talkativeness: number;
  /**
   * 成员是否启用（在群聊中活跃），禁用的成员在 selectSpeaker 时不会被选中。
   */
  enabled: boolean;
  /**
   * 该成员激活时使用的世界信息文本，
   * 在 buildPromptData 的 mergeWorldInfo 中与共享世界信息合并。
   */
  worldInfoText: string;
  /**
   * 记录创建时间戳（毫秒），成员首次添加到群聊时设置。
   */
  createdAt: number;
  /**
   * 记录最后更新时间戳（毫秒），成员信息更新时刷新。
   */
  updatedAt: number;
}

/**
 * 描述群聊持久化或内存索引中的一条记录，
 * 用于在 bindPersona 操作后将群聊与用户人格的绑定关系持久化。
 */
export interface GroupPersonaBindingRecord {
  /**
   * 群聊标识，用于标识哪个群聊绑定了用户人格。
   */
  groupId: string;
  /**
   * 绑定的用户人格标识，用于在 AI 提示词中提供用户的角色扮演身份。
   */
  personaId: string;
  /**
   * 绑定记录最后更新时间戳（毫秒），绑定操作执行时刷新。
   */
  updatedAt: number;
}

/**
 * 描述群聊模块在运行时交换的数据结构，
 * 用于在 buildPromptData 流程中向 AI 生成模块提供完整的群聊上下文信息。
 */
export interface GroupPromptData {
  /**
   * 群聊标识，用于关联生成请求对应的群聊。
   */
  groupId: string;
  /**
   * 群聊名称，用于构建提示词开头的群聊标识。
   */
  groupName: string;
  /**
   * 绑定的用户人格标识，用于在提示词中标记用户身份。
   */
  personaId: string;
  /**
   * 群聊成员名称列表（逗号分隔），
   * 用于在提示词中列出所有参与的成员名称。
   */
  memberNames: string;
  /**
   * 聚合后的世界信息文本，包含共享信息和各成员独有的 worldInfoText，
   * 用于为 AI 提供全局和个体上下文。
   */
  worldInfoText: string;
  /**
   * 构建完成的提示词文本，包含群聊上下文、成员和世界信息，
   * 可直接作为 AI 生成请求的上下文输入。
   */
  promptText: string;
}

/**
 * 描述发送给外部服务或宿主网络层的请求数据，
 * 用于将群聊中的生成（发言/续写/工具调用）请求加入队列并传递给 AI 服务。
 */
export interface GroupGenerationRequest {
  /**
   * 生成请求的唯一标识，格式为 'group-request-{自增数字}'，
   * 用于在请求队列中唯一标记一次生成请求。
   */
  id: string;
  /**
   * 所属群聊的标识，用于在请求列表中关联具体的群聊。
   */
  groupId: string;
  /**
   * 关联的聊天标识，用于确定生成内容的归属聊天会话。
   */
  chatId: string;
  /**
   * 关联的消息标识，用于在 regenerate 操作时指定要重新生成的消息。
   */
  messageId: string;
  /**
   * 生成请求的类型，如 'regenerate'（重新生成）、'continue'（续写）、'tool_call'（工具调用），
   * 用于决定 AI 生成的行为模式。
   */
  requestType: string;
  /**
   * 发言角色的标识，当 requestType 为 'regenerate' 时指定由哪个角色重新发言。
   */
  speakerCharacterId: string;
  /**
   * 要调用的工具名称，当 requestType 为 'tool_call' 时指定需要调用的 AI 工具。
   */
  toolName: string;
  /**
   * 请求创建时间戳（毫秒），用于记录请求的生成时间。
   */
  createdAt: number;
}

/**
 * 描述群聊模块在运行时交换的数据结构，
 * 用于在 exportGroup / importGroup 操作中承载完整的单个群聊数据。
 */
export interface GroupExportData {
  /**
   * 导出的主群聊记录，包含群聊 ID、名称、描述、关联聊天等元数据。
   */
  group: GroupRecord;
  /**
   * 群聊成员记录列表，包含各成员的角色、活跃度、世界信息等配置。
   */
  members: Array<GroupMemberRecord>;
  /**
   * 群聊相关的生成请求列表，包含待处理的 regenerate/continue/tool_call 记录。
   */
  requests: Array<GroupGenerationRequest>;
}

/**
 * 描述群聊索引文件中的持久化元数据，
 * 用于在 saveToStore / loadFromStore 流程中记录存储状态，供下次启动恢复。
 */
export interface GroupStorageIndex {
  /**
   * 数据模式的版本号，用于数据迁移兼容性判断。
   */
  schemaVersion: number;
  /**
   * 所有群聊的标识列表，
   * 用于在 loadFromStore 时遍历加载每个群聊的详细快照文件。
   */
  groupIds: Array<string>;
  /**
   * 下一次生成请求编号之前已经使用过的最大编号，
   * 用于在导入请求时保持计数器不冲突。
   */
  requestCounter: number;
}

/**
 * 描述单个群聊文件中的完整持久化快照，
 * 用于在 saveToStore / loadFromStore 流程中将单个群聊的完整数据写入或恢复。
 */
export interface GroupStorageSnapshot {
  /**
   * 数据模式的版本号，用于数据迁移兼容性判断。
   */
  schemaVersion: number;
  /**
   * 单个群聊的完整记录快照，包含群聊元数据。
   */
  group: GroupRecord;
  /**
   * 群聊成员记录列表快照，包含各成员的详细配置。
   */
  members: Array<GroupMemberRecord>;
  /**
   * 群聊生成请求列表快照，包含当前所有待处理请求。
   */
  requests: Array<GroupGenerationRequest>;
}

/**
 * 描述群聊事件发布时携带的数据结构，
 * 用于在群聊创建、更新、导入、人格绑定时通过 EventBus 广播给其他模块。
 */
export interface GroupEventPayload {
  /**
   * 事件关联的群聊记录副本，
   * 供监听方获取最新的群聊元数据。
   */
  group: GroupRecord;
}

/**
 * 描述群聊事件发布时携带的数据结构，
 * 用于在群聊被删除时通过 EventBus 广播给 UI 层和其他模块。
 */
export interface GroupDeletedPayload {
  /**
   * 被删除群聊的标识，
   * 供监听方据此从本地缓存或 UI 列表中移除对应条目。
   */
  groupId: string;
}

/**
 * 描述群聊事件发布时携带的数据结构，
 * 用于在成员被添加到群聊时通过 EventBus 广播给 UI 层和其他模块。
 */
export interface GroupMemberAddedPayload {
  /**
   * 目标群聊标识，用于标识成员被添加到了哪个群聊。
   */
  groupId: string;
  /**
   * 被添加的角色标识，用于关联角色系统中的角色数据。
   */
  characterId: string;
  /**
   * 被添加的成员记录副本，
   * 供监听方获取新的成员信息。
   */
  member: GroupMemberRecord;
}

/**
 * 描述群聊事件发布时携带的数据结构，
 * 用于在群聊发言者被选中时通过 EventBus 广播给 UI 层和其他模块。
 */
export interface GroupSpeakerSelectedPayload {
  /**
   * 目标群聊标识，用于标识哪个群聊选中了发言者。
   */
  groupId: string;
  /**
   * 被选中的角色标识，用于通知 UI 层更新发言者指示器。
   */
  characterId: string;
  /**
   * 被选中的成员记录副本，
   * 供监听方获取被选成员的信息。
   */
  member: GroupMemberRecord;
}
