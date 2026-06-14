import type {
  ProviderId,
  SecretPermission,
  SecretRef,
  TavernScope,
} from '../contracts/PublicContracts';

/**
 * 创建密钥引用时需传入的参数集合。
 */
export interface SecretCreateParams {
  /**
   * 密钥唯一标识。
   */
  id: string;
  /**
   * 密钥所属的模型提供商标识。
   */
  providerId: ProviderId;
  /**
   * 密钥适用的作用域。
   */
  scope: TavernScope;
  /**
   * 作用域下的具体对象标识。
   */
  scopeId: string;
  /**
   * 展示标签，由内部维护。
   */
  label: string;
  /**
   * 密钥明文值，仅在创建时设置。
   */
  value: string;
  /**
   * 是否启用，由内部维护。
   */
  active: boolean;
}

/**
 * 内存索引中的完整密钥记录。
 */
export interface SecretRecord {
  /**
   * 密钥唯一标识。
   */
  id: string;
  /**
   * 密钥引用，由内部自动生成。
   */
  secretRef: SecretRef;
  /**
   * 密钥所属的模型提供商标识。
   */
  providerId: ProviderId;
  /**
   * 密钥适用的作用域。
   */
  scope: TavernScope;
  /**
   * 作用域下的具体对象标识。
   */
  scopeId: string;
  /**
   * 展示标签，由内部维护。
   */
  label: string;
  /**
   * 是否启用，由内部维护。
   */
  active: boolean;
  /**
   * 创建时间戳，由内部维护。
   */
  createdAt: number;
  /**
   * 最后更新时间戳，由内部维护。
   */
  updatedAt: number;
}

/**
 * 密钥值与引用之间的映射记录。
 */
export interface SecretValueRecord {
  /**
   * 密钥引用。
   */
  secretRef: SecretRef;
  /**
   * 密钥明文值。
   */
  value: string;
}

/**
 * 包含脱敏值的密钥状态快照，供 UI 层展示。
 */
export interface SecretStateRecord {
  /**
   * 密钥唯一标识。
   */
  id: string;
  /**
   * 密钥引用，由内部自动生成。
   */
  secretRef: SecretRef;
  /**
   * 密钥所属的模型提供商标识。
   */
  providerId: ProviderId;
  /**
   * 密钥适用的作用域。
   */
  scope: TavernScope;
  /**
   * 作用域下的具体对象标识。
   */
  scopeId: string;
  /**
   * 展示标签，由内部维护。
   */
  label: string;
  /**
   * 脱敏后的密钥值，供 UI 安全展示。
   */
  maskedValue: string;
  /**
   * 是否启用，由内部维护。
   */
  active: boolean;
  /**
   * 最后更新时间戳，由内部维护。
   */
  updatedAt: number;
}

/**
 * 导出格式的密钥记录，包含脱敏值与备份所需全部字段。
 */
export interface SecretExportRecord {
  /**
   * 密钥唯一标识。
   */
  id: string;
  /**
   * 密钥引用，由内部自动生成。
   */
  secretRef: SecretRef;
  /**
   * 密钥所属的模型提供商标识。
   */
  providerId: ProviderId;
  /**
   * 密钥适用的作用域。
   */
  scope: TavernScope;
  /**
   * 作用域下的具体对象标识。
   */
  scopeId: string;
  /**
   * 展示标签，由内部维护。
   */
  label: string;
  /**
   * 脱敏后的密钥值。
   */
  maskedValue: string;
  /**
   * 是否启用，由内部维护。
   */
  active: boolean;
  /**
   * 最后更新时间戳，由内部维护。
   */
  updatedAt: number;
}

/**
 * 访问密钥时传入的权限和上下文选项。
 */
export interface SecretAccessOptions {
  /**
   * 发起访问的调用方标识。
   */
  requesterId: string;
  /**
   * 调用方持有的权限列表，由内部维护。
   */
  permissions: Array<SecretPermission>;
}

/**
 * 密钥相关事件（创建、更新）携带的数据载荷。
 */
export interface SecretEventPayload {
  /**
   * 受影响的密钥记录。
   */
  secret: SecretRecord;
}

/**
 * 密钥删除事件携带的数据载荷。
 */
export interface SecretDeletedPayload {
  /**
   * 被删除的密钥引用。
   */
  secretRef: SecretRef;
  /**
   * 被删除密钥所属的提供商标识。
   */
  providerId: ProviderId;
}

/**
 * 密钥轮换事件携带的数据载荷，包含新旧引用信息。
 */
export interface SecretRotatedPayload {
  /**
   * 轮换后新建的密钥记录。
   */
  secret: SecretRecord;
  /**
   * 轮换前的旧密钥引用。
   */
  previousSecretRef: SecretRef;
}
