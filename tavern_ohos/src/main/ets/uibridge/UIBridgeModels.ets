/**
 * 描述 UI 桥接模块中弹窗、输入框等交互请求的响应数据结构。
 */
export interface UIRequestResponse {
  /**
   * 用户输入的文本值。
   */
  value: string;
  /**
   * 多选场景下用户勾选的选项列表。
   */
  selectedValues: Array<string>;
  /**
   * 确认弹窗中用户是否点击了确认。
   */
  confirmed: boolean;
  /**
   * 用户是否取消了当前交互（关闭弹窗或按取消）。
   */
  cancelled: boolean;
  /**
   * 文件选择场景中用户选取的文件路径列表。
   */
  filePaths: Array<string>;
  /**
   * 响应附带的额外元数据 JSON 字符串。
   */
  metadataJson: string;
}

/**
 * 描述 UI 桥接模块中一条请求记录的完整数据结构，覆盖弹窗、输入、选择、进度等所有交互类型。
 */
export interface UIRequestRecord {
  /**
   * 请求唯一标识（如 "ui-request-1"）。
   */
  id: string;
  /**
   * 请求类型，决定 UI 层渲染的交互组件（popup / input / confirm / select / file_picker / toast / loader / progress / media_preview / audio_playback / clipboard / navigation / permission）。
   */
  requestType: string;
  /**
   * 弹窗标题或交互提示的标题文本。
   */
  title: string;
  /**
   * 弹窗正文或输入框的提示消息。
   */
  message: string;
  /**
   * 输入框场景的默认预填值。
   */
  defaultValue: string;
  /**
   * 选择场景的选项列表（JSON 序列化字符串，格式如 `["opt1","opt2"]`）。
   */
  optionsJson: string;
  /**
   * 是否允许在 select / file_picker 中多选。
   */
  multiple: boolean;
  /**
   * toast 或权限请求的严重级别（如 "info" / "warning" / "error"）。
   */
  severity: string;
  /**
   * loader / progress 等组件是否可见。
   */
  visible: boolean;
  /**
   * 媒体预览或播放的媒体类型（如 "audio" / "image" / "video"）。
   */
  mediaType: string;
  /**
   * 媒体资源的 URI 路径。
   */
  mediaUri: string;
  /**
   * navigation 类型请求的目标页面或路由标识。
   */
  target: string;
  /**
   * 进度条的当前进度值。
   */
  progressCurrent: number;
  /**
   * 进度条的总进度值。
   */
  progressTotal: number;
  /**
   * 音频播放是否自动开始。
   */
  autoPlay: boolean;
  /**
   * 请求是否已被用户响应或关闭。
   */
  resolved: boolean;
  /**
   * 请求被响应后存放的响应数据。
   */
  response: UIRequestResponse;
  /**
   * 请求记录的创建时间戳。
   */
  createdAt: number;
  /**
   * 请求记录的最近更新时间戳。
   */
  updatedAt: number;
}

/**
 * 描述 UI 桥接模块发布请求事件（如 ui.requested）时携带的负载数据结构。
 */
export interface UIRequestEventPayload {
  /**
   * 被发布的请求记录。
   */
  request: UIRequestRecord;
}

/**
 * 描述 UI 桥接模块发布请求已响应事件（如 ui.resolved）时携带的负载数据结构。
 */
export interface UIRequestResolvedPayload {
  /**
   * 已被响应的请求记录（包含用户输入或选择的回填值）。
   */
  request: UIRequestRecord;
}
