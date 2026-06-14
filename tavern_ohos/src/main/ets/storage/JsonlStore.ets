import type { TavernFileStore } from './TavernFileStore';

/**
 * 基于 TavernFileStore 的 JSONL（每行一条 JSON 记录）文件存取。
 *
 * 每条记录独占一行，写入时通过 append 追加，读取时逐行解析；
 * 支持分页读取（readRange）和全量压缩重写（compact）。
 */
export class JsonlStore<T extends Object> {
  /**
   * TavernFileStore 实例，由外部注入。
   */
  private files: TavernFileStore;
  /**
   * 文件的相对存储路径。
   */
  private path: string;

  /**
   * @param files TavernFileStore 实例。
   * @param path 文件的相对存储路径。
   */
  constructor(files: TavernFileStore, path: string) {
    this.files = files;
    this.path = path;
  }

  /**
   * 将一条记录序列化为 JSON 后追加到文件末尾。
   * @param value 待追加的记录数据。
   */
  async append(value: T): Promise<void> {
    await this.files.appendText(this.path, `${JSON.stringify(value)}\n`);
  }

  /**
   * 读取文件中所有记录并反序列化为数组。
   * @returns 所有记录列表；返回值是副本，调用方可安全读取。
   */
  async readAll(): Promise<Array<T>> {
    const exists = await this.files.exists(this.path);
    if (!exists) {
      return new Array<T>();
    }
    const content = await this.files.readText(this.path);
    return this.parseLines(content);
  }

  /**
   * 按起始索引和数量读取文件中的部分记录。
   * @param startIndex 分页起始索引（从 0 开始）。
   * @param count 欲读取的记录数量。
   * @returns JSON 记录列表副本。
   */
  async readRange(startIndex: number, count: number): Promise<Array<T>> {
    const all = await this.readAll();
    if (startIndex < 0 || count <= 0 || startIndex >= all.length) {
      return new Array<T>();
    }
    return all.slice(startIndex, startIndex + count);
  }

  /**
   * 以提供的记录列表覆盖整个文件内容。
   *
   * 用于日志压缩（compaction）、去重或者重新排序后将结果写回，
   * 写入后会再次读取并比对数量以确保数据完整。
   * @param values 覆盖写入的记录列表。
   */
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

  /**
   * 将文本内容按行解析为记录数组。
   *
   * 空行和纯空白行会被跳过。
   * @param content 待解析的文本内容。
   * @returns JSON 记录列表副本。
   */
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
