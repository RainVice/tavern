import type { TavernFileStore } from './TavernFileStore';

/**
 * 提供文件存储的存储实现，封装路径规范化和读写细节。
 */
export class JsonlStore<T extends Object> {
  /**
   * 文件存储适配器实例，用于在 Runtime 的数据持久化流程中执行底层文件读写操作。
   */
  private files: TavernFileStore;
  /**
   * 数据文件的存储路径（相对存储根目录），用于确定追加式日志数据的文件保存位置。
   */
  private path: string;

  /**
   * 初始化 JsonlStore 实例，供各 Runtime 在需要追加写入的流程中使用。
   * @param files 用于读写文件的存储适配器，由宿主在初始化 Runtime 时注入。
   * @param path 数据文件的相对存储根路径，用于区分不同数据类别的日志存储文件。
   */
  constructor(files: TavernFileStore, path: string) {
    this.files = files;
    this.path = path;
  }

  /**
   * 在 JSONL 文件尾部追加一行序列化后的记录。
   * 在需要增量记录操作日志（如消息编辑历史、事件流）时调用，适用于只追加不覆盖的持久化场景。
   * @param value 要追加的记录对象，会被序列化为 JSON。由调用方传入当前操作产生的增量数据。
   */
  async append(value: T): Promise<void> {
    await this.files.appendText(this.path, `${JSON.stringify(value)}\n`);
  }

  /**
   * 读取全部 JSONL 记录并反序列化为数组。
   * 在 Runtime 初始化时用于还原所有历史记录，或在需要全量遍历日志数据时调用。
   * @returns 文件中所有记录的列表，按写入顺序返回（最早写入的记录排在最前）。
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
   * 按分页范围读取记录，返回指定起始索引和数量的子集。
   * 在需要分段加载历史记录（如 UI 列表滚动分页、预览最近 N 条记录）时调用，避免一次读取全部数据。
   * @param startIndex 起始索引（从 0 开始），对应记录在文件中的写入顺序位置。
   * @param count 最多返回的记录数量，用于控制单次读取的数据量。
   * @returns 指定范围内的记录列表，索引越界时返回空数组。
   */
  async readRange(startIndex: number, count: number): Promise<Array<T>> {
    const all = await this.readAll();
    if (startIndex < 0 || count <= 0 || startIndex >= all.length) {
      return new Array<T>();
    }
    return all.slice(startIndex, startIndex + count);
  }

  /**
   * 用给定的完整记录列表重写整个 JSONL 文件（即 compact 操作）。
   * 在需要进行垃圾回收或数据压缩（如删除过期记录后重写文件）时调用，将内存中整理后的数据写回文件。
   * @param values 要全部写入的记录列表，是经过调用方过滤/合并后的最终数据。
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
   * 把多行字符串按行解析，过滤空行，反序列化为对象数组。
   * @param content 要解析的文件文本内容，来自底层文件读取的结果。
   * @returns 反序列化后的记录数组，按行号顺序排列。
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
