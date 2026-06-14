/**
 * 描述UI 桥接模块在运行时交换的数据结构。
 */
export interface UIRequestResponse {
  /**
   * 字段值。
   */
  value: string;
  /**
   * selected Values 列表，由当前实例内部维护。
   */
  selectedValues: Array<string>;
  /**
   * confirmed 值，由当前实例内部维护。
   */
  confirmed: boolean;
  /**
   * cancelled 值，由当前实例内部维护。
   */
  cancelled: boolean;
  /**
   * file Paths 列表，由当前实例内部维护。
   */
  filePaths: Array<string>;
  /**
   * metadata JSON 字符串。
   */
  metadataJson: string;
}

/**
 * 描述UI 桥接持久化或内存索引中的一条记录。
 */
export interface UIRequestRecord {
  /**
   * 标识。
   */
  id: string;
  /**
   * request Type 值，由当前实例内部维护。
   */
  requestType: string;
  /**
   * 标题，由当前实例内部维护。
   */
  title: string;
  /**
   * 消息数据。
   */
  message: string;
  /**
   * default Value 值，由当前实例内部维护。
   */
  defaultValue: string;
  /**
   * options JSON 字符串。
   */
  optionsJson: string;
  /**
   * multiple 值，由当前实例内部维护。
   */
  multiple: boolean;
  /**
   * severity 值，由当前实例内部维护。
   */
  severity: string;
  /**
   * visible 值，由当前实例内部维护。
   */
  visible: boolean;
  /**
   * media Type 值，由当前实例内部维护。
   */
  mediaType: string;
  /**
   * media Uri 值，由当前实例内部维护。
   */
  mediaUri: string;
  /**
   * 目标对象，由当前实例内部维护。
   */
  target: string;
  /**
   * progress Current 值，由当前实例内部维护。
   */
  progressCurrent: number;
  /**
   * progress Total 值，由当前实例内部维护。
   */
  progressTotal: number;
  /**
   * auto Play 值，由当前实例内部维护。
   */
  autoPlay: boolean;
  /**
   * resolved 值，由当前实例内部维护。
   */
  resolved: boolean;
  /**
   * response 值，由当前实例内部维护。
   */
  response: UIRequestResponse;
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
 * 描述UI 桥接事件发布时携带的数据结构。
 */
export interface UIRequestEventPayload {
  /**
   * request 值，由当前实例内部维护。
   */
  request: UIRequestRecord;
}

/**
 * 描述UI 桥接事件发布时携带的数据结构。
 */
export interface UIRequestResolvedPayload {
  /**
   * request 值，由当前实例内部维护。
   */
  request: UIRequestRecord;
}
