/**
 * 描述调用用户人格能力时需要传入的参数。
 */
export interface PersonaCreateParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * avatar Ref 值，由当前实例内部维护。
   */
  avatarRef: string;
  /**
   * tags 列表，由当前实例内部维护。
   */
  tags: Array<string>;
  /**
   * lorebook 标识。
   */
  lorebookId: string;
  /**
   * prompt Injection Strategy 值，由当前实例内部维护。
   */
  promptInjectionStrategy: string;
  /**
   * user Macro Value 值，由当前实例内部维护。
   */
  userMacroValue: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
}

/**
 * 描述用户人格持久化或内存索引中的一条记录。
 */
export interface PersonaRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * avatar Ref 值，由当前实例内部维护。
   */
  avatarRef: string;
  /**
   * tags 列表，由当前实例内部维护。
   */
  tags: Array<string>;
  /**
   * lorebook 标识。
   */
  lorebookId: string;
  /**
   * prompt Injection Strategy 值，由当前实例内部维护。
   */
  promptInjectionStrategy: string;
  /**
   * user Macro Value 值，由当前实例内部维护。
   */
  userMacroValue: string;
  /**
   * enabled 值，由当前实例内部维护。
   */
  enabled: boolean;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述用户人格持久化或内存索引中的一条记录。
 */
export interface PersonaBindingRecord {
  /**
   * 作用域。
   */
  scope: string;
  /**
   * 作用域标识。
   */
  scopeId: string;
  /**
   * persona 标识。
   */
  personaId: string;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述用户人格模块在运行时交换的数据结构。
 */
export interface PersonaPromptData {
  /**
   * persona 标识。
   */
  personaId: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * description 值，由当前实例内部维护。
   */
  description: string;
  /**
   * avatar Ref 值，由当前实例内部维护。
   */
  avatarRef: string;
  /**
   * lorebook 标识。
   */
  lorebookId: string;
  /**
   * prompt Injection Strategy 值，由当前实例内部维护。
   */
  promptInjectionStrategy: string;
  /**
   * user Macro Value 值，由当前实例内部维护。
   */
  userMacroValue: string;
  /**
   * tags 列表，由当前实例内部维护。
   */
  tags: Array<string>;
}

/**
 * 描述用户人格模块在运行时交换的数据结构。
 */
export interface PersonaExportData {
  /**
   * persona 值，由当前实例内部维护。
   */
  persona: PersonaRecord;
}

/**
 * 描述用户人格事件发布时携带的数据结构。
 */
export interface PersonaChangedPayload {
  /**
   * persona 值，由当前实例内部维护。
   */
  persona: PersonaRecord;
  /**
   * previous Persona 标识。
   */
  previousPersonaId: string;
}

/**
 * 描述用户人格事件发布时携带的数据结构。
 */
export interface PersonaUpdatedPayload {
  /**
   * persona 值，由当前实例内部维护。
   */
  persona: PersonaRecord;
}

/**
 * 描述用户人格事件发布时携带的数据结构。
 */
export interface PersonaDeletedPayload {
  /**
   * persona 标识。
   */
  personaId: string;
}
