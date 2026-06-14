/**
 * 创建用户人格时所需的输入参数。
 * 用于 PersonaRuntime.createPersona 和 updatePersona 方法，定义用户人格的所有可配置字段。
 */
export interface PersonaCreateParams {
  /**
   * 用户人格的唯一标识，用于在运行时索引和定位特定人格。
   */
  id: string;
  /**
   * 用户人格的显示名称，用于在 UI 中展示，以及在 Prompt 中作为用户标识。
   */
  name: string;
  /**
   * 用户人格的描述，用于在 Prompt 中描述用户角色背景，影响 AI 对用户身份的理解。
   */
  description: string;
  /**
   * 用户人格的头像引用标识，用于在聊天界面中显示用户头像。
   */
  avatarRef: string;
  /**
   * 用户人格的标签列表，用于分类和过滤用户人格。
   */
  tags: Array<string>;
  /**
   * 用户人格关联的 lorebook 标识，用于在 Prompt 中注入用户相关的世界设定。
   */
  lorebookId: string;
  /**
   * Prompt 注入策略，决定如何将用户人格描述注入到系统提示词中。
   */
  promptInjectionStrategy: string;
  /**
   * 用户宏变量的值，用于在 Prompt 中替换 {{user}} 等模板占位符，标识用户名称。
   */
  userMacroValue: string;
  /**
   * 用户人格是否启用，禁用的人格不会在其他功能中被使用。
   */
  enabled: boolean;
}

/**
 * 用户人格的持久化记录。
 * 存储用户人格的完整数据，由 PersonaRuntime 管理其生命周期。
 */
export interface PersonaRecord {
  /**
   * 用户人格的唯一标识，用于在运行时索引和定位特定人格。
   */
  id: string;
  /**
   * 用户人格的显示名称。
   */
  name: string;
  /**
   * 用户人格的描述。
   */
  description: string;
  /**
   * 用户人格的头像引用标识。
   */
  avatarRef: string;
  /**
   * 用户人格的标签列表。
   */
  tags: Array<string>;
  /**
   * 用户人格关联的 lorebook 标识。
   */
  lorebookId: string;
  /**
   * Prompt 注入策略。
   */
  promptInjectionStrategy: string;
  /**
   * 用户宏变量的值，用于替换模板中的 {{user}} 等占位符。
   */
  userMacroValue: string;
  /**
   * 用户人格是否启用。
   */
  enabled: boolean;
  /**
   * 记录最近更新时间戳，用于排序和判断数据新鲜度。
   */
  updatedAt: number;
}

/**
 * 用户人格与作用域的绑定记录。
 * 用于将特定用户人格绑定到某个作用域（如聊天、角色），
 * 通过 buildPromptDataForScope 可以按作用域解析出当前应使用的人格。
 */
export interface PersonaBindingRecord {
  /**
   * 绑定作用域（如 chat、character），用于在获取绑定时确定范围。
   */
  scope: string;
  /**
   * 作用域下的具体对象标识，与 scope 组合形成唯一绑定键。
   */
  scopeId: string;
  /**
   * 绑定的用户人格标识，用于定位被绑定的用户人格记录。
   */
  personaId: string;
  /**
   * 绑定的最近更新时间戳，用于追踪绑定变更时间。
   */
  updatedAt: number;
}

/**
 * 构建 Prompt 时所需的用户人格数据摘要。
 * 由 PersonaRuntime.buildPromptData 生成，提供给 Prompt 组装流程中合成提示词。
 */
export interface PersonaPromptData {
  /**
   * 用户人格标识。
   */
  personaId: string;
  /**
   * 用户人格的显示名称。
   */
  name: string;
  /**
   * 用户人格的描述，用于注入到系统提示词中描述用户角色。
   */
  description: string;
  /**
   * 用户人格的头像引用标识。
   */
  avatarRef: string;
  /**
   * 用户人格关联的 lorebook 标识，用于在 Prompt 中注入用户相关的世界设定。
   */
  lorebookId: string;
  /**
   * Prompt 注入策略。
   */
  promptInjectionStrategy: string;
  /**
   * 用户宏变量的值。
   */
  userMacroValue: string;
  /**
   * 用户人格的标签列表。
   */
  tags: Array<string>;
}

/**
 * 用户人格的导出/导入格式。
 * 用于序列化用户人格数据以便备份恢复或在不同运行环境间迁移。
 */
export interface PersonaExportData {
  /**
   * 要导出或导入的用户人格记录，包含完整的人格数据。
   */
  persona: PersonaRecord;
}

/**
 * 用户人格切换时通过事件总线发布的数据载荷。
 * 由 selectPersona 发布，通知监听方（如聊天界面）当前用户身份已变更。
 */
export interface PersonaChangedPayload {
  /**
   * 切换后用于发送对话的用户人格记录，供监听方更新当前用户身份显示。
   */
  persona: PersonaRecord;
  /**
   * 切换前的用户人格标识，供监听方处理切换前的状态清理。
   */
  previousPersonaId: string;
}

/**
 * 用户人格更新时通过事件总线发布的数据载荷。
 * 由 createPersona、updatePersona、importPersona 发布，通知监听方（如 UI 层）刷新人格列表。
 */
export interface PersonaUpdatedPayload {
  /**
   * 已更新的用户人格记录，供监听方获取更新的详情。
   */
  persona: PersonaRecord;
}

/**
 * 用户人格被删除时通过事件总线发布的数据载荷。
 * 由 deletePersona 发布，通知监听方（如 UI 层）移除相关的人格显示。
 */
export interface PersonaDeletedPayload {
  /**
   * 被删除的用户人格标识，供监听方清理与该人格相关的引用和缓存。
   */
  personaId: string;
}
