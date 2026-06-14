import { EventBus } from '../runtime/EventBus';
import type {
  UIRequestEventPayload,
  UIRequestRecord,
  UIRequestResolvedPayload,
  UIRequestResponse,
} from './UIBridgeModels';

/**
 * 提供UI 桥接相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 在 Runtime 需要与宿主 UI 交互（弹窗、输入框、确认框、选择器、文件选择、Toast、加载动画、进度条、媒体预览等）时使用。
 */
export class UIBridgeRuntime {
  /**
   * 事件总线实例，用于发布 UI 请求和响应事件。
   */
  private events: EventBus;
  /**
   * 按 ID 保存的 UI 请求映射表。
   */
  private requests: Map<string, UIRequestRecord> = new Map<string, UIRequestRecord>();
  /**
   * 请求自增 ID 计数器。
   */
  private counter: number = 0;

  /**
   * 初始化 UIBridgeRuntime 实例。
   * @param events 事件总线实例，由宿主在初始化时注入。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 发起弹窗请求。
   * 在需要向用户展示信息提示时由 Runtime 调用。
   * @param title 弹窗标题。
   * @param message 弹窗消息。
   * @returns 新建的 UI 请求记录。
   */
  requestPopup(title: string, message: string): UIRequestRecord {
    return this.createRequest('popup', title, message, '', '', false, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 发起输入框请求。
   * 在需要用户输入文本时由 Runtime 调用。
   * @param title 标题。
   * @param message 提示消息。
   * @param defaultValue 默认输入值。
   */
  requestInput(title: string, message: string, defaultValue: string): UIRequestRecord {
    return this.createRequest('input', title, message, defaultValue, '', false, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 发起确认对话框请求。
   * 在需要用户确认操作时由 Runtime 调用。
   * @param title 标题。
   * @param message 确认消息。
   */
  requestConfirm(title: string, message: string): UIRequestRecord {
    return this.createRequest('confirm', title, message, '', '', false, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 发起选择列表请求。
   * 在需要用户从列表中选择时由 Runtime 调用。
   * @param title 标题。
   * @param options 可选项列表。
   * @param multiple 是否允许多选。
   * @returns 新建的 UI 请求记录。
   */
  requestSelect(title: string, options: Array<string>, multiple: boolean): UIRequestRecord {
    return this.createRequest('select', title, '', '', this.optionsJson(options), multiple, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 发起文件选择器请求。
   * 在需要用户选择文件时由 Runtime 调用。
   * @param title 标题。
   * @param extensions 允许的文件扩展名列表。
   * @param multiple 是否允许多选。
   * @returns 新建的 UI 请求记录。
   */
  requestFilePicker(title: string, extensions: Array<string>, multiple: boolean): UIRequestRecord {
    return this.createRequest('file_picker', title, '', '', this.optionsJson(extensions), multiple, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 发起 Toast 消息请求。
   * 在需要向用户展示简短提示消息时由 Runtime 调用。
   * @param message 消息内容。
   * @param severity 严重级别（如 "info" / "warning" / "error"）。
   */
  requestToast(message: string, severity: string): UIRequestRecord {
    return this.createRequest('toast', message, message, '', '', false, severity, true, '', '', '', 0, 0, false);
  }

  /**
   * 发起加载动画请求。
   * 在需要显示或隐藏加载状态时由 Runtime 调用。
   * @param title 标题。
   * @param visible 是否显示加载 UI。
   * @returns 新建的 UI 请求记录。
   */
  requestLoader(title: string, visible: boolean): UIRequestRecord {
    return this.createRequest('loader', title, '', '', '', false, '', visible, '', '', '', 0, 0, false);
  }

  /**
   * 发起进度条请求。
   * 在需要展示操作进度时由 Runtime 调用。
   * @param title 标题。
   * @param current 当前进度值。
   * @param total 总进度值。
   */
  requestProgress(title: string, current: number, total: number): UIRequestRecord {
    return this.createRequest('progress', title, '', '', '', false, '', true, '', '', '', current, total, false);
  }

  /**
   * 发起媒体预览请求。
   * 在需要展示图片或视频时由 Runtime 调用。
   * @param title 标题。
   * @param mediaType 媒体类型（如 "image" / "video"）。
   * @param mediaUri 媒体资源 URI。
   */
  requestMediaPreview(title: string, mediaType: string, mediaUri: string): UIRequestRecord {
    return this.createRequest('media_preview', title, '', '', '', false, '', true, mediaType, mediaUri, '', 0, 0, false);
  }

  /**
   * 发起音频播放请求。
   * 在需要播放语音或音频时由 Runtime 调用。
   * @param title 标题。
   * @param mediaUri 音频资源 URI。
   * @param autoPlay 是否自动播放。
   * @returns 新建的 UI 请求记录。
   */
  requestAudioPlayback(title: string, mediaUri: string, autoPlay: boolean): UIRequestRecord {
    return this.createRequest('audio_playback', title, '', '', '', false, '', true, 'audio', mediaUri, '', 0, 0, autoPlay);
  }

  /**
   * 发起剪贴板操作请求。
   * 在需要复制文本到剪贴板时由 Runtime 调用。
   * @param title 标题。
   * @param value 要复制到剪贴板的值。
   */
  requestClipboard(title: string, value: string): UIRequestRecord {
    return this.createRequest('clipboard', title, '', value, '', false, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 发起导航请求。
   * 在需要跳转到指定页面时由 Runtime 调用。
   * @param title 标题。
   * @param target 导航目标路径。
   */
  requestNavigation(title: string, target: string): UIRequestRecord {
    return this.createRequest('navigation', title, '', '', '', false, '', true, '', '', target, 0, 0, false);
  }

  /**
   * 发起权限请求弹窗。
   * 在需要请求用户授权时由 Runtime 调用。
   * @param title 标题。
   * @param message 权限说明消息。
   */
  requestPermission(title: string, message: string): UIRequestRecord {
    return this.createRequest('permission', title, message, '', '', false, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 宿主响应 UI 请求，标记为已处理并发布 ui.resolved 事件。
   * 在宿主 UI 处理完交互（用户已操作弹窗/输入框等）后调用，通知发起方获取用户输入结果。
   * @param requestId 目标请求标识。
   * @param response 宿主返回的响应。
   * @returns 更新后的请求记录。
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
   * 获取指定请求的记录。
   * @param requestId 目标请求标识。
   * @returns 请求记录副本。
   */
  getRequest(requestId: string): UIRequestRecord {
    return this.cloneRequest(this.requireRequest(requestId));
  }

  /**
   * 列出所有 UI 请求记录。
   * @returns 请求记录副本数组。
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
   * 获取所有未处理的（pending）请求。
   * @returns 未处理的请求记录副本列表。
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
   * 清理所有已处理的（resolved）请求。
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
   * 创建新的 UI 请求记录并发布 ui.requested 事件。
   * @param requestType 请求类型。
   * @param title 标题。
   * @param message 消息。
   * @param defaultValue 默认值。
   * @param optionsJson 选项 JSON。
   * @param multiple 是否多选。
   * @param severity 严重级别。
   * @param visible 是否可见。
   * @param mediaType 媒体类型。
   * @param mediaUri 媒体 URI。
   * @param target 导航目标。
   * @param progressCurrent 当前进度。
   * @param progressTotal 总进度。
   * @param autoPlay 是否自动播放。
   * @returns 新建的请求记录。
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
   * 确保指定请求存在，缺失时抛出错误。
   * @param requestId 目标请求标识。
   */
  private requireRequest(requestId: string): UIRequestRecord {
    const request = this.requests.get(requestId);
    if (request === undefined) {
      throw new Error(`UI request not found: ${requestId}`);
    }
    return request;
  }
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
   * 深度复制 UIRequestResponse，防止外部代码修改内部状态。
   * @param response 待复制的响应对象。
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
   * 深度复制 UIRequestRecord，防止外部代码修改内部状态。
   * @param request 待复制的请求记录。
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
