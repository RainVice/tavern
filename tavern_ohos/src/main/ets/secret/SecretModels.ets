/**
 * 描述调用密钥引用能力时需要传入的参数。
 */
export interface SecretCreateParams {
  /**
   * 标识。
   */
  id: string;
  /**
   * provider 标识。
   */
  providerId: string;
  /**
   * 作用域。
   */
  scope: string;
  /**
   * 作用域标识。
   */
  scopeId: string;
  /**
   * label 值，由当前实例内部维护。
   */
  label: string;
  /**
   * 字段值。
   */
  value: string;
  /**
   * active 值，由当前实例内部维护。
   */
  active: boolean;
}

/**
 * 描述密钥引用持久化或内存索引中的一条记录。
 */
export interface SecretRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * 密钥引用，由当前实例内部维护。
   */
  secretRef: string;
  /**
   * provider 标识。
   */
  providerId: string;
  /**
   * 作用域。
   */
  scope: string;
  /**
   * 作用域标识。
   */
  scopeId: string;
  /**
   * label 值，由当前实例内部维护。
   */
  label: string;
  /**
   * active 值，由当前实例内部维护。
   */
  active: boolean;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述密钥引用持久化或内存索引中的一条记录。
 */
export interface SecretValueRecord {
  /**
   * 密钥引用，由当前实例内部维护。
   */
  secretRef: string;
  /**
   * 字段值。
   */
  value: string;
}

/**
 * 描述密钥引用持久化或内存索引中的一条记录。
 */
export interface SecretStateRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * 密钥引用，由当前实例内部维护。
   */
  secretRef: string;
  /**
   * provider 标识。
   */
  providerId: string;
  /**
   * 作用域。
   */
  scope: string;
  /**
   * 作用域标识。
   */
  scopeId: string;
  /**
   * label 值，由当前实例内部维护。
   */
  label: string;
  /**
   * masked Value 值，由当前实例内部维护。
   */
  maskedValue: string;
  /**
   * active 值，由当前实例内部维护。
   */
  active: boolean;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述密钥引用持久化或内存索引中的一条记录。
 */
export interface SecretExportRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * 密钥引用，由当前实例内部维护。
   */
  secretRef: string;
  /**
   * provider 标识。
   */
  providerId: string;
  /**
   * 作用域。
   */
  scope: string;
  /**
   * 作用域标识。
   */
  scopeId: string;
  /**
   * label 值，由当前实例内部维护。
   */
  label: string;
  /**
   * masked Value 值，由当前实例内部维护。
   */
  maskedValue: string;
  /**
   * active 值，由当前实例内部维护。
   */
  active: boolean;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}

/**
 * 描述密钥引用模块在运行时交换的数据结构。
 */
export interface SecretAccessOptions {
  /**
   * requester 标识。
   */
  requesterId: string;
  /**
   * permissions 列表，由当前实例内部维护。
   */
  permissions: Array<string>;
}

/**
 * 描述密钥引用事件发布时携带的数据结构。
 */
export interface SecretEventPayload {
  /**
   * secret 值，由当前实例内部维护。
   */
  secret: SecretRecord;
}

/**
 * 描述密钥引用事件发布时携带的数据结构。
 */
export interface SecretDeletedPayload {
  /**
   * 密钥引用，由当前实例内部维护。
   */
  secretRef: string;
  /**
   * provider 标识。
   */
  providerId: string;
}

/**
 * 描述密钥引用事件发布时携带的数据结构。
 */
export interface SecretRotatedPayload {
  /**
   * secret 值，由当前实例内部维护。
   */
  secret: SecretRecord;
  /**
   * previous Secret Ref 值，由当前实例内部维护。
   */
  previousSecretRef: string;
}
