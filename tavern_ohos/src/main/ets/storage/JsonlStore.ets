import type { TavernFileStore } from './TavernFileStore';

/**
 * 提供文件存储的存储实现，封装路径规范化和读写细节。
 */
export class JsonlStore<T extends Object> {
  /**
   * 文件存储适配器。
   */
  private files: TavernFileStore;
  /**
   * 路径。
   */
  private path: string;

  /**
   * 初始化当前运行时实例。
   * @param files 文件存储适配器。
   * @param path 路径。
   */
  constructor(files: TavernFileStore, path: string) {
    this.files = files;
    this.path = path;
  }

  /**
   * 追加目标对象，保留既有内容并写入新增片段。
   * @param value 要保存或比较的字段值。
   */
  async append(value: T): Promise<void> {
    await this.files.appendText(this.path, `${JSON.stringify(value)}\n`);
  }

  /**
   * 读取All 值，并转换为运行时使用的数据结构。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 读取Range 值，并转换为运行时使用的数据结构。
   * @param startIndex 分页起始索引。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  async readRange(startIndex: number, count: number): Promise<Array<T>> {
    const all = await this.readAll();
    if (startIndex < 0 || count <= 0 || startIndex >= all.length) {
      return new Array<T>();
    }
    return all.slice(startIndex, startIndex + count);
  }

  /**
   * 执行 compact 的内部处理步骤，供当前模块复用。
   * @param values 待处理的值列表。
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
   * 解析输入内容并转换为Lines 列表结构。
   * @param content 要写入或追加的文本内容。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
