import type { TavernScope } from '../contracts/PublicContracts';

/**
 * 调用方创建或更新用户人格时必须提供的参数。
 */
export interface PersonaCreateParams {
  /**
   * 用户人格唯一标识，创建后不可变更。
   */
  id: string;
  /**
   * 用户人格显示名称。
   */
  name: string;
  /**
   * 用户人格的描述文本，用于上下文注入。
   */
  description: string;
  /**
   * 用户头像的资源引用路径。
   */
  avatarRef: string;
  /**
   * 用户人格标签列表，用于分类和筛选。
   */
  tags: Array<string>;
  /**
   * 关联的 lorebook（世界书）记录标识。
   */
  lorebookId: string;
  /**
   * Prompt 注入策略的取值，决定描述文本以何种方式拼入 Prompt。
   */
  promptInjectionStrategy: string;
  /**
   * 用户宏变量的取值，可在 Prompt 模板中展开。
   */
  userMacroValue: string;
  /**
   * 是否已启用。禁用的人格不会出现在 Prompt 构建结果中。
   */
  enabled: boolean;
}

/**
 * 持久化或内存中存储的一条完整用户人格记录。
 * 与 {@link PersonaCreateParams} 相比，多出 updatedAt 时间戳字段。
 */
export interface PersonaRecord {
  /**
   * 用户人格唯一标识。
   */
  id: string;
  /**
   * 用户人格显示名称。
   */
  name: string;
  /**
   * 用户人格的描述文本，用于上下文注入。
   */
  description: string;
  /**
   * 用户头像的资源引用路径。
   */
  avatarRef: string;
  /**
   * 用户人格标签列表，用于分类和筛选。
   */
  tags: Array<string>;
  /**
   * 关联的 lorebook（世界书）记录标识。
   */
  lorebookId: string;
  /**
   * Prompt 注入策略的取值，决定描述文本以何种方式拼入 Prompt。
   */
  promptInjectionStrategy: string;
  /**
   * 用户宏变量的取值，可在 Prompt 模板中展开。
   */
  userMacroValue: string;
  /**
   * 是否已启用。
   */
  enabled: boolean;
  /**
   * 最近一次更新时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 用户人格与作用域之间的绑定关系记录。
 * 用于将特定人格绑定到某个作用域（如聊天会话）下的具体对象。
 */
export interface PersonaBindingRecord {
  /**
   * 绑定所属的作用域类型。
   */
  scope: TavernScope;
  /**
   * 作用域下具体对象的标识。
   */
  scopeId: string;
  /**
   * 所绑定的用户人格标识。
   */
  personaId: string;
  /**
   * 绑定建立或最近修改的时间戳（毫秒）。
   */
  updatedAt: number;
}

/**
 * 运行时构建的用户人格 Prompt 数据。
 * 包含拼接 Prompt 所需的全部字段，由 {@link PersonaRuntime} 负责生成。
 */
export interface PersonaPromptData {
  /**
   * 源用户人格标识。
   */
  personaId: string;
  /**
   * 用户人格显示名称。
   */
  name: string;
  /**
   * 用户人格的描述文本，用于上下文注入。
   */
  description: string;
  /**
   * 用户头像的资源引用路径。
   */
  avatarRef: string;
  /**
   * 关联的 lorebook（世界书）记录标识。
   */
  lorebookId: string;
  /**
   * Prompt 注入策略的取值。
   */
  promptInjectionStrategy: string;
  /**
   * 用户宏变量的取值。
   */
  userMacroValue: string;
  /**
   * 用户人格标签列表。
   */
  tags: Array<string>;
}

/**
 * 导出用户人格时的序列化数据结构。
 * 包含完整的 {@link PersonaRecord}，可用于备份或跨实例迁移。
 */
export interface PersonaExportData {
  /**
   * 导出的完整用户人格记录。
   */
  persona: PersonaRecord;
}

/**
 * 用户人格切换事件（persona.changed）携带的载荷。
 */
export interface PersonaChangedPayload {
  /**
   * 切换后的用户人格记录。
   */
  persona: PersonaRecord;
  /**
   * 切换前的用户人格标识；首次选择时为空字符串。
   */
  previousPersonaId: string;
}

/**
 * 用户人格更新或导入事件（persona.updated / persona.imported）携带的载荷。
 */
export interface PersonaUpdatedPayload {
  /**
   * 更新后的用户人格记录。
   */
  persona: PersonaRecord;
}

/**
 * 用户人格删除事件（persona.deleted）携带的载荷。
 */
export interface PersonaDeletedPayload {
  /**
   * 被删除的用户人格标识。
   */
  personaId: string;
}
