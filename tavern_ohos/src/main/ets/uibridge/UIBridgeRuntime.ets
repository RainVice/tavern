import { EventBus } from '../runtime/EventBus';
import type {
  UIRequestEventPayload,
  UIRequestRecord,
  UIRequestResolvedPayload,
  UIRequestResponse,
} from './UIBridgeModels';

export class UIBridgeRuntime {
  private events: EventBus;
  private requests: Map<string, UIRequestRecord> = new Map<string, UIRequestRecord>();
  private counter: number = 0;

  constructor(events: EventBus) {
    this.events = events;
  }

  requestPopup(title: string, message: string): UIRequestRecord {
    return this.createRequest('popup', title, message, '', '', false, '', true, '', '', '', 0, 0, false);
  }

  requestInput(title: string, message: string, defaultValue: string): UIRequestRecord {
    return this.createRequest('input', title, message, defaultValue, '', false, '', true, '', '', '', 0, 0, false);
  }

  requestConfirm(title: string, message: string): UIRequestRecord {
    return this.createRequest('confirm', title, message, '', '', false, '', true, '', '', '', 0, 0, false);
  }

  requestSelect(title: string, options: Array<string>, multiple: boolean): UIRequestRecord {
    return this.createRequest('select', title, '', '', this.optionsJson(options), multiple, '', true, '', '', '', 0, 0, false);
  }

  requestFilePicker(title: string, extensions: Array<string>, multiple: boolean): UIRequestRecord {
    return this.createRequest('file_picker', title, '', '', this.optionsJson(extensions), multiple, '', true, '', '', '', 0, 0, false);
  }

  requestToast(message: string, severity: string): UIRequestRecord {
    return this.createRequest('toast', message, message, '', '', false, severity, true, '', '', '', 0, 0, false);
  }

  requestLoader(title: string, visible: boolean): UIRequestRecord {
    return this.createRequest('loader', title, '', '', '', false, '', visible, '', '', '', 0, 0, false);
  }

  requestProgress(title: string, current: number, total: number): UIRequestRecord {
    return this.createRequest('progress', title, '', '', '', false, '', true, '', '', '', current, total, false);
  }

  requestMediaPreview(title: string, mediaType: string, mediaUri: string): UIRequestRecord {
    return this.createRequest('media_preview', title, '', '', '', false, '', true, mediaType, mediaUri, '', 0, 0, false);
  }

  requestAudioPlayback(title: string, mediaUri: string, autoPlay: boolean): UIRequestRecord {
    return this.createRequest('audio_playback', title, '', '', '', false, '', true, 'audio', mediaUri, '', 0, 0, autoPlay);
  }

  requestClipboard(title: string, value: string): UIRequestRecord {
    return this.createRequest('clipboard', title, '', value, '', false, '', true, '', '', '', 0, 0, false);
  }

  requestNavigation(title: string, target: string): UIRequestRecord {
    return this.createRequest('navigation', title, '', '', '', false, '', true, '', '', target, 0, 0, false);
  }

  requestPermission(title: string, message: string): UIRequestRecord {
    return this.createRequest('permission', title, message, '', '', false, '', true, '', '', '', 0, 0, false);
  }

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

  getRequest(requestId: string): UIRequestRecord {
    return this.cloneRequest(this.requireRequest(requestId));
  }

  listRequests(): Array<UIRequestRecord> {
    const result = new Array<UIRequestRecord>();
    const requests = Array.from(this.requests.values());
    for (let index = 0; index < requests.length; index += 1) {
      result.push(this.cloneRequest(requests[index]));
    }
    return result;
  }

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

  clearResolved(): void {
    const keys = Array.from(this.requests.keys());
    for (let index = 0; index < keys.length; index += 1) {
      const request = this.requests.get(keys[index]);
      if (request !== undefined && request.resolved) {
        this.requests.delete(keys[index]);
      }
    }
  }

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
