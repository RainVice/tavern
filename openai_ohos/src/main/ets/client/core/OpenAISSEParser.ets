/**
 * SSE 事件。
 *
 * API：Responses streaming、Images streaming、Realtime 等 SSE 接口。
 * 说明：表示一条 Server-Sent Events 消息，包含事件名、数据和可选 ID。
 */
export interface OpenAISSEEvent {
  /**
   * 事件名。
   *
   * API：SSE streaming。
   * 说明：来自 `event:` 行；如果服务端未提供，则为 `message`。
   */
  event: string;

  /**
   * 事件数据。
   *
   * API：SSE streaming。
   * 说明：由一个或多个 `data:` 行拼接而成；`[DONE]` 也会原样返回。
   */
  data: string;

  /**
   * 事件 ID。
   *
   * API：SSE streaming。
   * 说明：来自 `id:` 行；多数 OpenAI 流式事件不会设置。
   */
  id?: string;
}

/**
 * SSE 增量解析器。
 *
 * API：Responses streaming、Images streaming、Realtime 等 SSE 接口。
 * 说明：可多次调用 `push()` 追加网络分片，解析完整事件；最后调用 `flush()` 处理尾部残留。
 */
export class OpenAISSEParser {
  private buffer: string = '';

  /**
   * 追加一个文本分片并解析完整 SSE 事件。
   *
   * API：SSE streaming。
   * 说明：如果分片中没有完整事件，返回空数组并保留缓冲区。
   */
  push(chunk: string): Array<OpenAISSEEvent> {
    this.buffer = this.buffer + chunk;
    const events: Array<OpenAISSEEvent> = [];
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
   * 解析并清空尾部残留。
   *
   * API：SSE streaming。
   * 说明：连接结束时调用；残留内容能组成事件时返回该事件。
   */
  flush(): Array<OpenAISSEEvent> {
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

  private parseRawEvent(rawEvent: string): OpenAISSEEvent | null {
    const lines = rawEvent.replace(/\r\n/g, '\n').split('\n');
    let eventName = 'message';
    let eventID: string | null = null;
    const dataLines: Array<string> = [];
    for (let index = 0; index < lines.length; index++) {
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
        eventID = value;
      } else if (field === 'data') {
        dataLines.push(value);
      }
    }
    if (dataLines.length === 0) {
      return null;
    }
    const event: OpenAISSEEvent = {
      event: eventName,
      data: dataLines.join('\n'),
    };
    if (eventID !== null) {
      event.id = eventID;
    }
    return event;
  }
}

interface SSESeparator {
  index: number;
  length: number;
}
