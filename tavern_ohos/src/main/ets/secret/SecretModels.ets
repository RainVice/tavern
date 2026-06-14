/**
 * 描述调用密钥引用能力时需要传入的参数。
 * 用于在 createSecret 方法中定义新密钥的完整信息，最终存储为 SecretRecord 和 SecretValueRecord。
 */
export interface SecretCreateParams {
  /**
   * 标识，与 providerId 拼接后生成唯一密钥引用标识（secretRef = "secret:providerId:id"），
   * 用于在内存索引中唯一确定该密钥。
   */
  id: string;
  /**
   * provider 标识，用于限定密钥所属的 provider 范围，在 createSecret 中与 id 拼接生成 secretRef，
   * 在 readActiveSecret 等操作中按 providerId + scope + scopeId 查找激活密钥。
   */
  providerId: string;
  /**
   * 作用域，定义密钥的使用范围（如 "global"、"character"、"chat"），
   * 用于在 deactivateProviderScope 中确定同作用域下的密钥互斥关系。
   */
  scope: string;
  /**
   * 作用域标识，作用域下的具体对象标识（如角色 ID、聊天 ID），
   * 与 scope 组合用于精确确定密钥的互斥分组。
   */
  scopeId: string;
  /**
   * 密钥的显示标签，由用户在 UI 中输入，用于在密钥管理界面中标识该密钥的用途（如 "OpenAI API Key"）。
   */
  label: string;
  /**
   * 密钥的文本值（明文），由用户在 UI 中输入，存储到 values 映射中供 API 鉴权时读取。
   */
  value: string;
  /**
   * 该密钥是否处于激活状态。当 active 为 true 时，createSecret 会自动停用同 provider+scope+scopeId 下的其他密钥，
   * 确保请求中优先使用激活的密钥。
   */
  active: boolean;
}

/**
 * 描述密钥引用持久化或内存索引中的一条记录。
 * 由 createSecret 生成，存储密钥的元信息（不含明文值），用于索引、管理和导出。
 */
export interface SecretRecord {
  /**
   * 标识，与 createParams.id 对应，在密钥管理中用于向用户展示和有针对性操作。
   */
  id: string;
  /**
   * 密钥引用标识，格式如 "secret:providerId:id"，在 records 和 values Map 中作为唯一键，
   * 用于后续 updateSecret、deleteSecret、readSecret 等操作。
   */
  secretRef: string;
  /**
   * provider 标识，限定该密钥所属的 provider，用于 listSecretStates 按 provider 过滤查询。
   */
  providerId: string;
  /**
   * 作用域，定义密钥的使用范围，与 scopeId 配合确定密钥互斥分组。
   */
  scope: string;
  /**
   * 作用域标识，与 scope 配合用于 deactivateProviderScope 中的精确匹配，
   * 确保同作用域下只有一个密钥处于激活状态。
   */
  scopeId: string;
  /**
   * 密钥的显示标签，用于在 UI 密钥管理列表中展示该密钥的名称。
   */
  label: string;
  /**
   * 密钥是否激活。激活态密钥在 readActiveSecret 中被优先返回，用于 API 鉴权请求。
   * 同一 provider+scope+scopeId 分组中始终只有一条激活记录。
   */
  active: boolean;
  /**
   * 密钥创建时间戳（毫秒），用于在密钥管理界面按创建时间排序或展示。
   */
  createdAt: number;
  /**
   * 密钥最近更新时间戳（毫秒），标识最后一次修改（更新标签/激活状态/轮换）的时间。
   */
  updatedAt: number;
}

/**
 * 描述密钥引用持久化或内存索引中的一条记录。
 * 存储密钥的明文值，与 SecretRecord 分离存储以提高安全性，
 * 由 createSecret 生成，通过 readSecret 读取。
 */
export interface SecretValueRecord {
  /**
   * 密钥引用标识，格式如 "secret:providerId:id"，与 SecretRecord 中的 secretRef 一一对应，
   * 在 values Map 中作为唯一键。
   */
  secretRef: string;
  /**
   * 字段值，密钥的明文文本，存储在独立的值映射中与记录元信息隔离，
   * 仅在 readSecret 通过权限检查后才能获取。
   */
  value: string;
}

/**
 * 描述密钥引用持久化或内存索引中的一条记录。
 * 由 listSecretStates 从 SecretRecord 和 SecretValueRecord 合并生成，
 * 用于在 UI 密钥管理界面展示脱敏后的密钥状态。
 */
export interface SecretStateRecord {
  /**
   * 标识，与 SecretRecord.id 对应，用于在 UI 中标识该密钥条目。
   */
  id: string;
  /**
   * 密钥引用标识，格式如 "secret:providerId:id"，在 UI 中作为密钥的全局唯一标识展示。
   */
  secretRef: string;
  /**
   * provider 标识，用于在 UI 中按 provider 分组展示密钥列表。
   */
  providerId: string;
  /**
   * 作用域，在 UI 中展示密钥的使用范围。
   */
  scope: string;
  /**
   * 作用域标识，在 UI 中展示密钥作用的具体对象。
   */
  scopeId: string;
  /**
   * 密钥的显示标签，在 UI 密钥列表中展示该密钥的名称标识。
   */
  label: string;
  /**
   * 脱敏后的密钥值，由 maskValue 方法处理，短密钥完全遮蔽，长密钥仅保留末尾3位。
   * 用于在前端安全显示密钥状态而不泄露明文。
   */
  maskedValue: string;
  /**
   * 密钥是否激活，在 UI 中以视觉高亮方式展示，同时用于 readActiveSecret 方法查找。
   */
  active: boolean;
  /**
   * 密钥最近更新时间戳（毫秒），在 UI 中展示最后修改时间。
   */
  updatedAt: number;
}

/**
 * 描述密钥引用持久化或内存索引中的一条记录。
 * 由 exportIndex 从 SecretRecord 和 SecretValueRecord 合并生成，仅包含脱敏值不含明文。
 * 用于数据备份或在不同实例间迁移密钥元信息。
 */
export interface SecretExportRecord {
  /**
   * 标识，与 SecretRecord.id 对应，用于在导出记录中标识该密钥。
   */
  id: string;
  /**
   * 密钥引用标识，格式如 "secret:providerId:id"，在导入时用于去重或映射。
   */
  secretRef: string;
  /**
   * provider 标识，在导出记录中标识密钥所属的 provider。
   */
  providerId: string;
  /**
   * 作用域，在导出记录中描述密钥的使用范围。
   */
  scope: string;
  /**
   * 作用域标识，在导出记录中描述密钥作用的具体对象。
   */
  scopeId: string;
  /**
   * 密钥的显示标签，在备份文件中记录该密钥的名称。
   */
  label: string;
  /**
   * 脱敏后的密钥值，由 maskValue 方法处理，短密钥完全遮蔽，长密钥仅保留末尾3位。
   * 用于在前端安全显示密钥状态而不泄露明文。
   */
  maskedValue: string;
  /**
   * 密钥是否激活，在导出记录中保留激活状态以在导入时恢复。
   */
  active: boolean;
  /**
   * 密钥最近更新时间戳（毫秒），在导出记录中保留时间信息。
   */
  updatedAt: number;
}

/**
 * 描述密钥引用模块在运行时交换的数据结构。
 * 在 readSecret 和 readActiveSecret 方法中用于权限校验，
 * 确保调用方有权读取密钥明文值。
 */
export interface SecretAccessOptions {
  /**
   * 调用者标识，用于在鉴权逻辑中判断调用方身份（当前实现中未直接使用，预留扩展）。
   */
  requesterId: string;
  /**
   * 调用方持有的权限列表，在 canRead 方法中检查是否包含 "secret:read" 权限，
   * 只有包含此权限的调用方才允许读取密钥明文。
   */
  permissions: Array<string>;
}

/**
 * 描述密钥引用事件发布时携带的数据结构。
 * 当密钥被创建（createSecret）或更新（updateSecret）时，
 * 通过事件总线发布 "secret.created" 或 "secret.updated" 事件。
 */
export interface SecretEventPayload {
  /**
   * 发生变化的密钥记录对象副本，宿主可监听对应事件来同步 UI 或触发持久化。
   */
  secret: SecretRecord;
}

/**
 * 描述密钥引用事件发布时携带的数据结构。
 * 当密钥被 deleteSecret 方法删除时，通过事件总线通知宿主或其他模块。
 */
export interface SecretDeletedPayload {
  /**
   * 被删除的密钥引用标识，宿主可监听 "secret.deleted" 事件来同步 UI 并清理相关引用。
   */
  secretRef: string;
  /**
   * 密钥所属的 provider 标识，供宿主在清理时按 provider 维度处理。
   */
  providerId: string;
}

/**
 * 描述密钥引用事件发布时携带的数据结构。
 * 当密钥通过 rotateSecret 方法进行轮换时，通过事件总线通知宿主或其他模块。
 */
export interface SecretRotatedPayload {
  /**
   * 轮换后新创建的密钥记录，宿主可监听 "secret.rotated" 事件以获取新密钥信息并更新 UI。
   */
  secret: SecretRecord;
  /**
   * 轮换前的旧密钥引用标识，供宿主在展示轮换历史或清理旧密钥时使用。
   */
  previousSecretRef: string;
}
