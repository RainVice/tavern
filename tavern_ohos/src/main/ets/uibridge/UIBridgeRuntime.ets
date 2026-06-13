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
   * requests 列表，由当前实例内部维护。
   */
  private requests: Map<string, UIRequestRecord> = new Map<string, UIRequestRecord>();
  /**
   * counter 值，由当前实例内部维护。
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
   * 执行 requestPopup 的内部处理步骤，供当前模块复用。
   * @param title 标题。
   * @param message 消息记录。
   */
  requestPopup(title: string, message: string): UIRequestRecord {
    return this.createRequest('popup', title, message, '', '', false, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 执行 requestInput 的内部处理步骤，供当前模块复用。
   * @param title 标题。
   * @param message 消息记录。
   * @param defaultValue 未输入时使用的默认值。
   */
  requestInput(title: string, message: string, defaultValue: string): UIRequestRecord {
    return this.createRequest('input', title, message, defaultValue, '', false, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 执行 requestConfirm 的内部处理步骤，供当前模块复用。
   * @param title 标题。
   * @param message 消息记录。
   */
  requestConfirm(title: string, message: string): UIRequestRecord {
    return this.createRequest('confirm', title, message, '', '', false, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 执行 requestSelect 的内部处理步骤，供当前模块复用。
   * @param title 标题。
   * @param options 控制本次调用行为的选项。
   * @param multiple 是否允许多选。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  requestSelect(title: string, options: Array<string>, multiple: boolean): UIRequestRecord {
    return this.createRequest('select', title, '', '', this.optionsJson(options), multiple, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 执行 requestFilePicker 的内部处理步骤，供当前模块复用。
   * @param title 标题。

   * @param multiple 是否允许多选。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  requestFilePicker(title: string, extensions: Array<string>, multiple: boolean): UIRequestRecord {
    return this.createRequest('file_picker', title, '', '', this.optionsJson(extensions), multiple, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 执行 requestToast 的内部处理步骤，供当前模块复用。
   * @param message 消息记录。
   */
  requestToast(message: string, severity: string): UIRequestRecord {
    return this.createRequest('toast', message, message, '', '', false, severity, true, '', '', '', 0, 0, false);
  }

  /**
   * 执行 requestLoader 的内部处理步骤，供当前模块复用。
   * @param title 标题。
   * @param visible 是否显示对应 UI。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  requestLoader(title: string, visible: boolean): UIRequestRecord {
    return this.createRequest('loader', title, '', '', '', false, '', visible, '', '', '', 0, 0, false);
  }

  /**
   * 执行 requestProgress 的内部处理步骤，供当前模块复用。
   * @param title 标题。
   * @param current 当前处理路径或状态。
   * @param total 总进度值。
   */
  requestProgress(title: string, current: number, total: number): UIRequestRecord {
    return this.createRequest('progress', title, '', '', '', false, '', true, '', '', '', current, total, false);
  }

  /**
   * 执行 requestMediaPreview 的内部处理步骤，供当前模块复用。
   * @param title 标题。
   * @param mediaType 媒体类型。
   * @param mediaUri 媒体资源 URI。
   */
  requestMediaPreview(title: string, mediaType: string, mediaUri: string): UIRequestRecord {
    return this.createRequest('media_preview', title, '', '', '', false, '', true, mediaType, mediaUri, '', 0, 0, false);
  }

  /**
   * 执行 requestAudioPlayback 的内部处理步骤，供当前模块复用。
   * @param title 标题。
   * @param mediaUri 媒体资源 URI。
   * @param autoPlay 是否自动播放。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  requestAudioPlayback(title: string, mediaUri: string, autoPlay: boolean): UIRequestRecord {
    return this.createRequest('audio_playback', title, '', '', '', false, '', true, 'audio', mediaUri, '', 0, 0, autoPlay);
  }

  /**
   * 执行 requestClipboard 的内部处理步骤，供当前模块复用。
   * @param title 标题。
   * @param value 要保存或比较的字段值。
   */
  requestClipboard(title: string, value: string): UIRequestRecord {
    return this.createRequest('clipboard', title, '', value, '', false, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 执行 requestNavigation 的内部处理步骤，供当前模块复用。
   * @param title 标题。
   * @param target 目标对象。
   */
  requestNavigation(title: string, target: string): UIRequestRecord {
    return this.createRequest('navigation', title, '', '', '', false, '', true, '', '', target, 0, 0, false);
  }

  /**
   * 执行 requestPermission 的内部处理步骤，供当前模块复用。
   * @param title 标题。
   * @param message 消息记录。
   */
  requestPermission(title: string, message: string): UIRequestRecord {
    return this.createRequest('permission', title, message, '', '', false, '', true, '', '', '', 0, 0, false);
  }

  /**
   * 执行 respond 的内部处理步骤，供当前模块复用。
   * @param requestId 目标请求标识。
   * @param response 宿主返回的响应对象。
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
   * 读取指定请求，不存在时抛出错误。
   * @param requestId 目标请求标识。
   * @returns 更新或读取后的记录副本。
   */
  getRequest(requestId: string): UIRequestRecord {
    return this.cloneRequest(this.requireRequest(requestId));
  }

  /**
   * 读取请求列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 读取Pending Requests 列表，不存在时通常抛出错误或返回空值。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 删除或清理Resolved，并同步维护相关索引或状态。
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
   * 创建新的请求记录，写入存储并返回副本。

   * @param title 标题。
   * @param message 消息记录。
   * @param defaultValue 未输入时使用的默认值。
   * @param optionsJson options JSON 字符串。
   * @param multiple 是否允许多选。

   * @param visible 是否显示对应 UI。
   * @param mediaType 媒体类型。
   * @param mediaUri 媒体资源 URI。
   * @param target 目标对象。


   * @param autoPlay 是否自动播放。
   * @returns 更新或读取后的记录副本。
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
   * 读取必须存在的Request 值，缺失时抛出错误。
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
   * 复制Response 值，避免外部修改内部状态。
   * @param response 宿主返回的响应对象。
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
   * 复制Request 值，避免外部修改内部状态。
   * @param request 待处理的请求对象。
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
