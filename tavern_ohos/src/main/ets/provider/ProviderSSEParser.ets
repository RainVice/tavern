import type { ProviderSSEEvent } from './ProviderModels';

/**
 * SSE 分隔符位置与长度，标识缓冲区中事件边界的位置。
 */
interface SSESeparator {
  /**
   * 分隔符在字符串中的起始索引。
   */
  index: number;
  /**
   * 分隔符的长度（2 对应 \n\n，4 对应 \r\n\r\n）。
   */
  length: number;
}

/**
 * SSE（Server-Sent Events）解析器。
 * 将原始 SSE 数据流解析为 ProviderSSEEvent 对象数组。
 */
export class ProviderSSEParser {
  /**
   * 未完成解析的缓冲区数据。
   */
  private buffer: string = '';

  /**
   * 向解析器推入数据块，解析并返回其中完整的 SSE 事件。
   * @param chunk 原始 SSE 数据块字符串。
   * @returns 解析出的完整 SSE 事件列表。
   */
  push(chunk: string): Array<ProviderSSEEvent> {
    this.buffer = this.buffer + chunk;
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
   * 刷新缓冲区中残留的未完成数据，将其作为最后一个事件返回。
   * @returns 缓冲区中的最后一个 SSE 事件（可能为空列表）。
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
   * 在字符串中查找 SSE 事件分隔符（\n\n 或 \r\n\r\n），返回位置和长度。
   * @param value 待搜索的字符串。
   * @returns 分隔符信息，未找到时 index 为 -1。
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
   * 解析单条原始 SSE 事件文本，提取 event、id 和 data 字段。
   * 不符合 SSE 格式的文本返回 null。
   * @param rawEvent 原始 SSE 事件文本。
   * @returns 解析后的 SSE 事件对象，或 null。
   */
  private parseRawEvent(rawEvent: string): ProviderSSEEvent | null {
    const lines = rawEvent.replace(/\r\n/g, '\n').split('\n');
    let eventName = 'message';
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
