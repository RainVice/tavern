/**
 * 描述UI 桥接模块在运行时交换的数据结构。
 * 宿主 UI 在处理完 UI 请求后，通过该结构将用户操作的结果返回给 UIBridgeRuntime。
 */
export interface UIRequestResponse {
  /**
   * 用户输入的字段值，用于 input 类型请求的用户输入内容。
   */
  value: string;
  /**
   * 用户选中的值列表（多选场景），用于 select 类型请求的多选项结果。
   */
  selectedValues: Array<string>;
  /**
   * 用户是否确认，用于 confirm 类型请求的确认结果。
   */
  confirmed: boolean;
  /**
   * 用户是否取消，用于所有可被取消的请求类型。
   */
  cancelled: boolean;
  /**
   * 用户选择的文件路径列表，用于 file_picker 类型请求的文件选择结果。
   */
  filePaths: Array<string>;
  /**
   * 附加元数据的 JSON 字符串，用于扩展请求的自定义数据。
   */
  metadataJson: string;
}

/**
 * 描述 UI 桥接请求的完整记录。
 * 在 Runtime 需要与宿主 UI 交互时创建，通过事件发布给宿主处理。
 */
export interface UIRequestRecord {
  /**
   * 请求唯一标识，由 createRequest 自动生成（格式为 "ui-request-{计数器}"）。
   */
  id: string;
  /**
   * 请求类型（如 "popup" / "input" / "confirm" / "select" / "file_picker" 等），决定宿主 UI 展示的交互形式。
   */
  requestType: string;
  /**
   * 请求标题，用于 UI 弹窗或提示的标题。
   */
  title: string;
  /**
   * 请求消息内容，用于 UI 展示的提示文本。
   */
  message: string;
  /**
   * 默认输入值，用于 input 类型请求的预填充文本。
   */
  defaultValue: string;
  /**
   * 选项列表的 JSON 字符串，用于 select 类型请求的可选项。
   */
  optionsJson: string;
  /**
   * 是否允许多选，用于 select 和 file_picker 类型请求。
   */
  multiple: boolean;
  /**
   * 严重级别（如 "info" / "warning" / "error"），用于 Toast 等请求的级别区分。
   */
  severity: string;
  /**
   * 是否显示对应 UI，用于 loader 类型请求控制加载动画的可见性。
   */
  visible: boolean;
  /**
   * 媒体类型，用于 media_preview 和 audio_playback 请求的资源类型标识。
   */
  mediaType: string;
  /**
   * 媒体资源 URI，用于 media_preview 和 audio_playback 请求的资源定位。
   */
  mediaUri: string;
  /**
   * 导航目标，用于 navigation 类型请求的路由目标路径。
   */
  target: string;
  /**
   * 当前进度值，用于 progress 请求的进度展示。
   */
  progressCurrent: number;
  /**
   * 总进度值，用于 progress 请求的进度范围。
   */
  progressTotal: number;
  /**
   * 是否自动播放媒体，用于 audio_playback 请求的播放行为控制。
   */
  autoPlay: boolean;
  /**
   * 是否已被宿主处理（resolved），由 respond 方法标记。
   */
  resolved: boolean;
  /**
   * 宿主返回的响应。
   */
  response: UIRequestResponse;
  /**
   * 创建时间戳。
   */
  createdAt: number;
  /**
   * 最近更新时间戳。
   */
  updatedAt: number;
}

/**
 * 描述 UI 请求事件发布时携带的数据结构。
 * UIBridgeRuntime 在 createRequest 后发布 ui.requested 事件，通知宿主 UI 展示对应的交互组件。
 */
export interface UIRequestEventPayload {
  /**
   * 待处理的 UI 请求记录。
   */
  request: UIRequestRecord;
}

/**
 * 描述 UI 请求已处理事件发布时携带的数据结构。
 * UIBridgeRuntime 在 respond 后发布 ui.resolved 事件，通知发起方请求已得到响应。
 */
export interface UIRequestResolvedPayload {
  /**
   * 已处理的 UI 请求记录。
   */
  request: UIRequestRecord;
}
