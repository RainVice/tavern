import type { TavernFileStore } from './TavernFileStore';

/**
 * 提供文件存储的存储实现，封装路径规范化和读写细节。
 */
export class JsonStore<T extends Object> {
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
   * 读取目标对象，并转换为运行时使用的数据结构。
   * @param defaultValue 未输入时使用的默认值。
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
   * 写入目标对象，持久化当前运行时状态。
   * @param value 要保存或比较的字段值。
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
