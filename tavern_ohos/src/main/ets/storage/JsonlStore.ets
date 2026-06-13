import type { TavernFileStore } from './TavernFileStore';

export class JsonlStore<T extends Object> {
  private files: TavernFileStore;
  private path: string;

  constructor(files: TavernFileStore, path: string) {
    this.files = files;
    this.path = path;
  }

  async append(value: T): Promise<void> {
    await this.files.appendText(this.path, `${JSON.stringify(value)}\n`);
  }

  async readAll(): Promise<Array<T>> {
    const exists = await this.files.exists(this.path);
    if (!exists) {
      return new Array<T>();
    }

    const content = await this.files.readText(this.path);
    return this.parseLines(content);
  }

  async readRange(startIndex: number, count: number): Promise<Array<T>> {
    const all = await this.readAll();
    if (startIndex < 0 || count <= 0 || startIndex >= all.length) {
      return new Array<T>();
    }
    return all.slice(startIndex, startIndex + count);
  }

  async compact(values: Array<T>): Promise<void> {
    const lines = new Array<string>();
    for (let index = 0; index < values.length; index += 1) {
      lines.push(JSON.stringify(values[index]));
    }

    const content = lines.length === 0 ? '' : `${lines.join('\n')}\n`;
    await this.files.writeText(this.path, content, true);
    const saved = await this.readAll();
    if (saved.length !== values.length) {
      throw new Error(`JSONL compact verification failed: ${this.path}`);
    }
  }

  private parseLines(content: string): Array<T> {
    const records = new Array<T>();
    const lines = content.split('\n');
    for (let index = 0; index < lines.length; index += 1) {
      const line = lines[index].trim();
      if (line.length === 0) {
        continue;
      }
      records.push(JSON.parse(line) as T);
    }
    return records;
  }
}
