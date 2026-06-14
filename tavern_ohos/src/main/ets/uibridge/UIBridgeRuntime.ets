import { EventBus } from '../runtime/EventBus';
import type {
  UIRequestEventPayload,
  UIRequestRecord,
  UIRequestResolvedPayload,
  UIRequestResponse,
} from './UIBridgeModels';

/**
 * 提供UI 桥接相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class UIBridgeRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 按 ID 索引的所有 UI 交互请求记录。
   */
  private requests: Map<string, UIRequestRecord> = new Map<string, UIRequestRecord>();
  /**
   * 自增计数器，用于生成请求 ID。
   */
  private counter: number = 0;

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 发起一个弹窗提示请求（requestType = "popup"）。
   * @param title 弹窗标题。
   * @param message 弹窗正文消息。
   * @returns 新增的请求记录。
   */
  requestPopup(title: string, message: string): UIRequestRecord {
    return this.createRequest('popup', title, message, '', '', false, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 发起一个文本输入请求（requestType = "input"）。
   * @param title 输入框标题。
   * @param message 输入框提示文本。
   * @param defaultValue 输入框预填的默认值。
   * @returns 新增的请求记录。
   */
  requestInput(title: string, message: string, defaultValue: string): UIRequestRecord {
    return this.createRequest('input', title, message, defaultValue, '', false, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 发起一个确认弹窗请求（requestType = "confirm"）。
   * @param title 确认框标题。
   * @param message 确认框正文消息。
   * @returns 新增的请求记录。
   */
  requestConfirm(title: string, message: string): UIRequestRecord {
    return this.createRequest('confirm', title, message, '', '', false, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 发起一个选项选择请求（requestType = "select"）。
   * @param title 选择框标题。
   * @param options 供用户选择的选项列表。
   * @param multiple 是否允许多选。
   * @returns 新增的请求记录。
   */
  requestSelect(title: string, options: Array<string>, multiple: boolean): UIRequestRecord {
    return this.createRequest('select', title, '', '', this.optionsJson(options), multiple, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 发起一个文件选择请求（requestType = "file_picker"）。
   * @param title 文件选择器标题。
   * @param extensions 允许的文件扩展名列表。
   * @param multiple 是否允许多选。
   * @returns 新增的请求记录。
   */
  requestFilePicker(title: string, extensions: Array<string>, multiple: boolean): UIRequestRecord {
    return this.createRequest('file_picker', title, '', '', this.optionsJson(extensions), multiple, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 发起一个 Toast 通知请求（requestType = "toast"）。
   * @param message Toast 显示的消息文本。
   * @param severity 消息严重级别（如 "info" / "warning" / "error"）。
   * @returns 新增的请求记录。
   */
  requestToast(message: string, severity: string): UIRequestRecord {
    return this.createRequest('toast', message, message, '', '', false, severity, true, '', '', '', 0, 0, false);
  }

  /**
   * 发起一个加载指示器请求（requestType = "loader"）。
   * @param title 加载提示文本。
   * @param visible 是否显示加载指示器。
   * @returns 新增的请求记录。
   */
  requestLoader(title: string, visible: boolean): UIRequestRecord {
    return this.createRequest('loader', title, '', '', '', false, '', visible, '', '', '', 0, 0, false);
  }

  /**
   * 发起一个进度条请求（requestType = "progress"）。
   * @param title 进度标题。
   * @param current 当前进度值。
   * @param total 总进度值。
   * @returns 新增的请求记录。
   */
  requestProgress(title: string, current: number, total: number): UIRequestRecord {
    return this.createRequest('progress', title, '', '', '', false, '', true, '', '', '', current, total, false);
  }

  /**
   * 发起一个媒体预览请求（requestType = "media_preview"）。
   * @param title 预览标题。
   * @param mediaType 媒体类型（如 "image" / "video"）。
   * @param mediaUri 媒体资源 URI。
   * @returns 新增的请求记录。
   */
  requestMediaPreview(title: string, mediaType: string, mediaUri: string): UIRequestRecord {
    return this.createRequest('media_preview', title, '', '', '', false, '', true, mediaType, mediaUri, '', 0, 0, false);
  }

  /**
   * 发起一个音频播放请求（requestType = "audio_playback"）。
   * @param title 播放标题。
   * @param mediaUri 音频资源 URI。
   * @param autoPlay 是否自动开始播放。
   * @returns 新增的请求记录。
   */
  requestAudioPlayback(title: string, mediaUri: string, autoPlay: boolean): UIRequestRecord {
    return this.createRequest('audio_playback', title, '', '', '', false, '', true, 'audio', mediaUri, '', 0, 0, autoPlay);
  }

  /**
   * 发起一个剪贴板操作请求（requestType = "clipboard"）。
   * @param title 剪贴板操作标题。
   * @param value 要复制到剪贴板的文本。
   * @returns 新增的请求记录。
   */
  requestClipboard(title: string, value: string): UIRequestRecord {
    return this.createRequest('clipboard', title, '', value, '', false, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 发起一个页面导航请求（requestType = "navigation"）。
   * @param title 导航标题。
   * @param target 目标页面或路由标识。
   * @returns 新增的请求记录。
   */
  requestNavigation(title: string, target: string): UIRequestRecord {
    return this.createRequest('navigation', title, '', '', '', false, '', true, '', '', target, 0, 0, false);
  }

  /**
   * 发起一个权限请求（requestType = "permission"）。
   * @param title 权限请求标题。
   * @param message 权限说明消息。
   * @returns 新增的请求记录。
   */
  requestPermission(title: string, message: string): UIRequestRecord {
    return this.createRequest('permission', title, message, '', '', false, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 响应用户对指定请求的交互结果，标记请求为已解决并发布 ui.resolved 事件。
   * @param requestId 待响应的请求 ID。
   * @param response 用户的响应数据（包含输入值、选择项等）。
   * @returns 更新后的请求记录副本。
   */
  respond(requestId: string, response: UIRequestResponse): UIRequestRecord {
    const request = this.requireRequest(requestId);
    request.response = this.cloneResponse(response);
    request.resolved = true;
    request.updatedAt = Date.now();
    const payload: UIRequestResolvedPayload = {
      request: this.cloneRequest(request),
    };
    this.events.publish<UIRequestResolvedPayload>('ui.resolved', payload);
    return this.cloneRequest(request);
  }

  /**
   * 根据 ID 获取指定请求记录的副本。
   * @param requestId 目标请求 ID。
   * @returns 请求记录副本，调用方可安全读取而不影响内部状态。
   */
  getRequest(requestId: string): UIRequestRecord {
    return this.cloneRequest(this.requireRequest(requestId));
  }

  /**
   * 获取所有请求记录的副本列表。
   * @returns 所有请求记录的副本数组，调用方可安全读取。
   */
  listRequests(): Array<UIRequestRecord> {
    const result = new Array<UIRequestRecord>();
    const requests = Array.from(this.requests.values());
    for (let index = 0; index < requests.length; index += 1) {
      result.push(this.cloneRequest(requests[index]));
    }
    return result;
  }

  /**
   * 获取所有尚未响应的待处理请求记录列表。
   * @returns 未解决请求记录的副本数组。
   */
  getPendingRequests(): Array<UIRequestRecord> {
    const result = new Array<UIRequestRecord>();
    const requests = Array.from(this.requests.values());
    for (let index = 0; index < requests.length; index += 1) {
      if (!requests[index].resolved) {
        result.push(this.cloneRequest(requests[index]));
      }
    }
    return result;
  }

  /**
   * 清理所有已解决的请求记录。
   */
  clearResolved(): void {
    const keys = Array.from(this.requests.keys());
    for (let index = 0; index < keys.length; index += 1) {
      const request = this.requests.get(keys[index]);
      if (request !== undefined && request.resolved) {
        this.requests.delete(keys[index]);
      }
    }
  }

  /**
   * 创建一条新的请求记录，写入内部存储并发布 ui.requested 事件。
   * @param requestType 请求类型。
   * @param title 标题。
   * @param message 消息文本。
   * @param defaultValue 输入框默认值。
   * @param optionsJson 选项 JSON 字符串。
   * @param multiple 是否允许多选。
   * @param severity 严重级别。
   * @param visible 是否可见（用于 loader / progress）。
   * @param mediaType 媒体类型。
   * @param mediaUri 媒体资源 URI。
   * @param target 导航目标。
   * @param progressCurrent 当前进度。
   * @param progressTotal 总进度。
   * @param autoPlay 是否自动播放。
   * @returns 新建请求记录的副本。
   */
  private createRequest(
    requestType: string,
    title: string,
    message: string,
    defaultValue: string,
    optionsJson: string,
    multiple: boolean,
    severity: string,
    visible: boolean,
    mediaType: string,
    mediaUri: string,
    target: string,
    progressCurrent: number,
    progressTotal: number,
    autoPlay: boolean,
  ): UIRequestRecord {
    this.counter += 1;
    const now = Date.now();
    const request: UIRequestRecord = {
      id: `ui-request-${this.counter}`,
      requestType: requestType,
      title: title,
      message: message,
      defaultValue: defaultValue,
      optionsJson: optionsJson,
      multiple: multiple,
      severity: severity,
      visible: visible,
      mediaType: mediaType,
      mediaUri: mediaUri,
      target: target,
      progressCurrent: progressCurrent,
      progressTotal: progressTotal,
      autoPlay: autoPlay,
      resolved: false,
      response: this.emptyResponse(),
      createdAt: now,
      updatedAt: now,
    };
    this.requests.set(request.id, this.cloneRequest(request));
    const payload: UIRequestEventPayload = {
      request: this.cloneRequest(request),
    };
    this.events.publish<UIRequestEventPayload>('ui.requested', payload);
    return this.cloneRequest(request);
  }

  /**
   * 按 ID 获取请求记录，不存在时抛出错误。
   * @param requestId 目标请求 ID。
   * @returns 内部存储的请求记录引用。
   */
  private requireRequest(requestId: string): UIRequestRecord {
    const request = this.requests.get(requestId);
    if (request === undefined) {
      throw new Error(`UI request not found: ${requestId}`);
    }
    return request;
  }
  /**
   * 创建一个空响应对象，用于新请求的默认 response 值。
   */
  private emptyResponse(): UIRequestResponse {
    const response: UIRequestResponse = {
      value: '',
      selectedValues: new Array<string>(),
      confirmed: false,
      cancelled: false,
      filePaths: new Array<string>(),
      metadataJson: '',
    };
    return response;
  }

  /**
   * 深拷贝响应对象，避免外部引用修改内部状态。
   * @param response 原始响应对象。
   * @returns 独立副本。
   */
  private cloneResponse(response: UIRequestResponse): UIRequestResponse {
    const cloned: UIRequestResponse = {
      value: response.value,
      selectedValues: response.selectedValues.slice(),
      confirmed: response.confirmed,
      cancelled: response.cancelled,
      filePaths: response.filePaths.slice(),
      metadataJson: response.metadataJson,
    };
    return cloned;
  }

  /**
   * 深拷贝请求记录，避免外部引用修改内部状态。
   * @param request 原始请求记录。
   * @returns 独立副本。
   */
  private cloneRequest(request: UIRequestRecord): UIRequestRecord {
    return {
      id: request.id,
      requestType: request.requestType,
      title: request.title,
      message: request.message,
      defaultValue: request.defaultValue,
      optionsJson: request.optionsJson,
      multiple: request.multiple,
      severity: request.severity,
      visible: request.visible,
      mediaType: request.mediaType,
      mediaUri: request.mediaUri,
      target: request.target,
      progressCurrent: request.progressCurrent,
      progressTotal: request.progressTotal,
      autoPlay: request.autoPlay,
      resolved: request.resolved,
      response: this.cloneResponse(request.response),
      createdAt: request.createdAt,
      updatedAt: request.updatedAt,
    };
  }
  private optionsJson(options: Array<string>): string {
    const escaped = new Array<string>();
    for (let index = 0; index < options.length; index += 1) {
      escaped.push(`"${options[index].replace(/"/g, '\\"')}"`);
    }
    return `[${escaped.join(',')}]`;
  }
}
