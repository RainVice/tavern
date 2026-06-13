import type { ProviderSSEEvent } from './ProviderModels';

/**
 * 描述Provider 请求模块在运行时交换的数据结构。
 */
interface SSESeparator {
  /**
   * 索引数据或循环位置，由当前实例内部维护。
   */
  index: number;
  /**
   * length 值，由当前实例内部维护。
   */
  length: number;
}

/**
 * 封装Provider 请求相关状态和行为。
 */
export class ProviderSSEParser {
  /**
   * buffer 值，由当前实例内部维护。
   */
  private buffer: string = '';

  /**
   * 执行 push 的内部处理步骤，供当前模块复用。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  push(chunk: string): Array<ProviderSSEEvent> {
    this.buffer = this.buffer + chunk;
    // 事件总线。
    const events = new Array<ProviderSSEEvent>();
    while (true) {
      const separator = this.findSeparator(this.buffer);
      if (separator.index < 0) {
        break;
      }
      const rawEvent = this.buffer.substring(0, separator.index);
      this.buffer = this.buffer.substring(separator.index + separator.length);
      const event = this.parseRawEvent(rawEvent);
      if (event !== null) {
        events.push(event);
      }
    }
    return events;
  }

  /**
   * 执行 flush 的内部处理步骤，供当前模块复用。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  flush(): Array<ProviderSSEEvent> {
    if (this.buffer.length === 0) {
      return [];
    }
    const rawEvent = this.buffer;
    this.buffer = '';
    const event = this.parseRawEvent(rawEvent);
    if (event === null) {
      return [];
    }
    return [event];
  }

  /**
   * 在当前集合中查找Separator 值，未命中时返回空值或默认位置。
   * @param value 要保存或比较的字段值。
   */
  private findSeparator(value: string): SSESeparator {
    const lf = value.indexOf('\n\n');
    const crlf = value.indexOf('\r\n\r\n');
    if (lf < 0 && crlf < 0) {
      return { index: -1, length: 0 };
    }
    if (lf >= 0 && (crlf < 0 || lf < crlf)) {
      return { index: lf, length: 2 };
    }
    return { index: crlf, length: 4 };
  }

  /**
   * 解析RawEvent，非法输入会返回失败标记或空结果。
   */
  private parseRawEvent(rawEvent: string): ProviderSSEEvent | null {
    const lines = rawEvent.replace(/\r\n/g, '\n').split('\n');
    // event 名称。
    let eventName = 'message';
    // event 标识。
    let eventId = '';
    const dataLines = new Array<string>();
    for (let index = 0; index < lines.length; index += 1) {
      const line = lines[index];
      if (line.length === 0 || line.startsWith(':')) {
        continue;
      }
      const colon = line.indexOf(':');
      const field = colon < 0 ? line : line.substring(0, colon);
      let value = colon < 0 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }
      if (field === 'event') {
        eventName = value;
      } else if (field === 'id') {
        eventId = value;
      } else if (field === 'data') {
        dataLines.push(value);
      }
    }
    if (dataLines.length === 0) {
      return null;
    }
    return {
      event: eventName,
      data: dataLines.join('\n'),
      id: eventId,
    };
  }
}
