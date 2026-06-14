import type { TavernFileStore } from './TavernFileStore';

/**
 * 提供文件存储的存储实现，封装路径规范化和读写细节。
 */
export class JsonStore<T extends Object> {
  /**
   * 文件存储适配器实例，用于在 Runtime 的数据持久化流程中执行底层文件读写操作。
   */
  private files: TavernFileStore;
  /**
   * 数据文件的存储路径（相对存储根目录），用于确定数据在文件系统上的保存位置。
   */
  private path: string;

  /**
   * 初始化 JsonStore 实例，供各 Runtime 在数据持久化流程中使用。
   * @param files 用于读写文件的存储适配器，由宿主在初始化 Runtime 时注入。
   * @param path 数据文件的相对存储根路径，用于区分不同数据类别（如角色、聊天、设置等）的存储文件。
   */
  constructor(files: TavernFileStore, path: string) {
    this.files = files;
    this.path = path;
  }

  /**
   * 从文件读取已持久化的 JSON 对象并反序列化；文件不存在或为空时返回 defaultValue。
   * 在 Runtime 初始化加载数据（如角色列表、聊天记录、配置设置）时调用，是整个数据还原流程的入口。
   * @param defaultValue 文件不存在或内容为空时返回的默认值，用于保证 Runtime 首次启动时能获得有效的初始状态。
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
   * 把当前对象序列化为 JSON 并写入文件；写入后回读校验以确保一致性。
   * 在 Runtime 保存数据（如创建/更新角色、聊天消息、应用设置）时调用，是数据持久化流程的核心写入步骤。
   * @param value 要持久化的数据对象，由调用方（如对应 Runtime 的 save/update 方法）传入当前状态的快照。
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
