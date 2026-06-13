import type { ProviderSSEEvent } from './ProviderModels';

interface SSESeparator {
  index: number;
  length: number;
}

export class ProviderSSEParser {
  private buffer: string = '';

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
