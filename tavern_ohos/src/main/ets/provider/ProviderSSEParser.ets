import type { ProviderSSEEvent } from './ProviderModels';

/**
 * SSE 分隔符在字符串中的位置和长度信息。
 */
interface SSESeparator {
  /** 分隔符的起始索引，-1 表示未找到。 */
  index: number;
  /** 分隔符的长度："\n\n" 为 2，"\r\n\r\n" 为 4。 */
  length: number;
}

/**
 * SSE (Server-Sent Events) 协议解析器。
 * 将流式原始数据块按 SSE 协议规范解析为结构化事件对象。
 */
export class ProviderSSEParser {
  /** 尚未完成解析的缓冲区数据。 */
  private buffer: string = '';

  /**
   * 向解析器推送新的数据块，从中提取完整的事件并返回。
   * @param chunk 原始数据块字符串。
   * @returns 从当前缓冲区中解析出的完整 SSE 事件列表。
   */
  push(chunk: string): Array<ProviderSSEEvent> {
    this.buffer = this.buffer + chunk;
    // 从缓冲区中循环提取完整的事件
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
   * 刷新缓冲区中剩余的未完成数据，将其作为最后一个事件解析并返回。
   * @returns 缓冲区残留数据解析后的事件列表（最多一个事件）。
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
   * 在字符串中查找 SSE 事件分隔符（"\n\n" 或 "\r\n\r\n"），优先匹配先出现的。
   * @param value 要搜索的目标字符串。
   * @returns 分隔符的位置和长度。
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
   * 解析原始事件字符串为结构化 SSE 事件对象。
   * 按照 SSE 协议规范，识别 event、id、data 字段，忽略注释行（以 ":" 开头）。
   * @param rawEvent 两个事件分隔符之间的原始文本。
   * @returns 解析后的 SSE 事件，若无可用的 data 字段则返回 null。
   */
  private parseRawEvent(rawEvent: string): ProviderSSEEvent | null {
    const lines = rawEvent.replace(/\r\n/g, '\n').split('\n');
    // 默认事件名称为 "message"
    let eventName = 'message';
    // SSE 事件标识
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
