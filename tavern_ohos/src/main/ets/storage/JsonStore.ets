import type { TavernFileStore } from './TavernFileStore';

/**
 * 基于 TavernFileStore 的 JSON 文件存取。
 *
 * 以 JSON.stringify / JSON.parse 完成序列化与反序列化，
 * 每次写入后会读取文件内容进行校验，确保数据安全落盘。
 */
export class JsonStore<T extends Object> {
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
   * 读取 JSON 文件内容并反序列化为指定类型。
   *
   * 文件不存在或内容为空时返回 defaultValue，不会抛出异常。
   * @param defaultValue 文件不存在或为空时返回的默认值。
   */
  async read(defaultValue: T): Promise<T> {
    const exists = await this.files.exists(this.path);
    if (!exists) {
      return defaultValue;
    }
    const content = await this.files.readText(this.path);
    if (content.trim().length === 0) {
      return defaultValue;
    }

    return JSON.parse(content) as T;
  }

  /**
   * 将数据序列化后写入 JSON 文件。
   *
   * 写入后会重新读取文件内容进行比对，内容不一致时抛错。
   * @param value 待序列化并写入的数据。
   */
  async write(value: T): Promise<void> {
    const content = JSON.stringify(value);
    await this.files.writeText(this.path, content, true);
    const saved = await this.files.readText(this.path);
    if (saved !== content) {
      throw new Error(`JSON write verification failed: ${this.path}`);
    }
  }
}
