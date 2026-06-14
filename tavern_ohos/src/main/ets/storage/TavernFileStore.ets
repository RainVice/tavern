import fileIo from '@ohos.file.fs';

/**
 * 定义 Runtime 访问文件系统的最小能力。
 *
 * 普通应用接入时直接使用 SandboxTavernFileStore；只有测试、加密存储或云同步等特殊场景才需要自定义实现。
 */
export interface TavernFileStore {
  /**
   * 确保目录路径存在，必要时创建缺失的中间目录。
   * 在写入文件前由存储层自动调用，用于保证目标路径的父目录结构完整。
   * @param path 目标文件或目录路径，相对于存储根目录。
   */
  ensureDirectory(path: string): Promise<void>;

  /**
   * 检查指定路径是否存在文件或目录。
   * 在读取或写入前由存储层调用，用于判断文件是否需要初始化默认值或执行后续操作。
   * @param path 要检查的文件或目录路径，相对于存储根目录。
   * @returns 路径存在时返回 true，否则返回 false。
   */
  exists(path: string): Promise<boolean>;

  /**
   * 读取指定路径的文本内容，路径不存在时抛出错误。
   * 由 JsonStore / JsonlStore 在还原数据时调用，是数据读取链的最底层操作。
   * @param path 要读取的文件路径，相对于存储根目录。
   */
  readText(path: string): Promise<string>;

  /**
   * 把文本写入指定路径，按参数决定是否创建 .bak 备份。
   * 由 JsonStore / JsonlStore 在持久化数据时调用，是数据写入链的最底层操作。
   * @param path 要写入的文件路径，相对于存储根目录。
   * @param content 要写入的文本内容，通常是序列化后的 JSON 数据。
   * @param createBackup 写入前是否把已有文件创建为备份，用于防止写入失败导致数据丢失。
   */
  writeText(path: string, content: string, createBackup: boolean): Promise<void>;

  /**
   * 向指定文件尾部追加文本内容（文件不存在时创建）。
   * 由 JsonlStore 在 append 操作时调用，用于增量日志场景的写入。
   * @param path 要追加的文件路径，相对于存储根目录。
   * @param content 要追加的文本内容，通常是序列化后的一行 JSON 数据。
   */
  appendText(path: string, content: string): Promise<void>;

  /**
   * 删除指定文件或空目录；路径不存在时静默返回。
   * 在 Runtime 清理数据（如删除角色、聊天记录、缩略图或主题文件）时调用。
   * @param path 要删除的文件或目录路径，相对于存储根目录。
   */
  delete(path: string): Promise<void>;

  /**
   * 列出指定目录下的直接子项名称。
   * 在需要遍历目录内容（如列出所有备份文件、扫描存储结构）时调用。
   * @param path 要列出的目录路径，相对于存储根目录。
   * @returns 子项名称的数组（仅直接子项，不递归），按字母序排列。
   */
  list(path: string): Promise<Array<string>>;
}

/**
 * 基于 HarmonyOS 应用沙箱目录的默认文件存储实现。
 *
 * 传入 `context.filesDir` 或应用自行选择的沙箱子目录即可；SDK 内部会在写入时按需创建父目录。
 */
export class SandboxTavernFileStore implements TavernFileStore {
  /**
   * 应用沙箱中的存储根目录，在构造函数中根据传入的 baseDirectory 初始化，作为所有相对路径的前缀。
   */
  private baseDirectory: string;

  /**
   * @param baseDirectory 应用沙箱可写目录，通常传入宿主通过 context.filesDir 获取的路径，用于确定所有文件操作的根目录。
   */
  constructor(baseDirectory: string) {
    this.baseDirectory = this.normalizeBaseDirectory(baseDirectory);
  }

  /**
   * 确保目录路径存在，必要时递归创建缺失的中间目录。
   * 在写入文件前自动调用，用于保证目标路径的父目录结构完整。
   * @param path 相对存储根目录的目录路径。
   */
  async ensureDirectory(path: string): Promise<void> {
    const target = this.resolvePath(path);
    if (await this.isDirectory(target)) {
      return;
    }
    try {
      await fileIo.mkdir(target, true);
    } catch (error) {
      if (await this.isDirectory(target)) {
        return;
      }
      throw new Error(`创建目录失败: ${path}, ${String(error)}`);
    }
  }

  /**
   * 检查指定路径是否存在文件或目录。
   * @param path 相对存储根目录的文件或目录路径。
   */
  async exists(path: string): Promise<boolean> {
    try {
      return await fileIo.access(this.resolvePath(path));
    } catch (error) {
      return false;
    }
  }

  /**
   * 读取指定路径的文本内容。
   * @param path 相对存储根目录的文件路径。
   */
  async readText(path: string): Promise<string> {
    try {
      return await fileIo.readText(this.resolvePath(path));
    } catch (error) {
      throw new Error(`读取文件失败: ${path}, ${String(error)}`);
    }
  }

  /**
   * 写入文本内容，写入前按需确保父目录存在。
   * @param path 相对存储根目录的文件路径。
   * @param content 要写入的文本。
   * @param createBackup 写入前是否把已有文件复制为 .bak 备份。
   */
  async writeText(path: string, content: string, createBackup: boolean): Promise<void> {
    const target = this.resolvePath(path);
    await this.ensureParentDirectory(path);
    if (createBackup && await this.exists(path)) {
      try {
        await fileIo.copyFile(target, `${target}.bak`);
      } catch (error) {
        throw new Error(`创建备份失败: ${path}, ${String(error)}`);
      }
    }
    await this.writeFile(target, content, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
  }

  /**
   * 向文本文件尾部追加内容，文件不存在时自动创建。
   * @param path 相对存储根目录的文件路径。
   * @param content 要追加的文本。
   */
  async appendText(path: string, content: string): Promise<void> {
    const target = this.resolvePath(path);
    await this.ensureParentDirectory(path);
    await this.writeFile(target, content, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.APPEND);
  }

  /**
   * 删除指定文件或空目录；路径不存在时不做处理。
   * @param path 相对存储根目录的文件或目录路径。
   */
  async delete(path: string): Promise<void> {
    const target = this.resolvePath(path);
    if (!(await this.exists(path))) {
      return;
    }
    try {
      await fileIo.unlink(target);
    } catch (error) {
      try {
        await fileIo.rmdir(target);
      } catch (directoryError) {
        throw new Error(`删除路径失败: ${path}, ${String(directoryError)}`);
      }
    }
  }

  /**
   * 列出指定目录下的直接子项名称。
   * @param path 相对存储根目录的目录路径。
   */
  async list(path: string): Promise<Array<string>> {
    if (!(await this.exists(path))) {
      return new Array<string>();
    }
    try {
      const names = await fileIo.listFile(this.resolvePath(path), { recursion: false });
      return names.sort();
    } catch (error) {
      throw new Error(`列出目录失败: ${path}, ${String(error)}`);
    }
  }

  private async ensureParentDirectory(path: string): Promise<void> {
    const normalized = this.normalizeRelativePath(path);
    const lastSlash = normalized.lastIndexOf('/');
    if (lastSlash < 0) {
      return;
    }
    await this.ensureDirectory(normalized.substring(0, lastSlash));
  }

  private async isDirectory(path: string): Promise<boolean> {
    try {
      const stat = await fileIo.stat(path);
      return stat.isDirectory();
    } catch (error) {
      return false;
    }
  }

  private async writeFile(path: string, content: string, mode: number): Promise<void> {
    let file: fileIo.File | undefined = undefined;
    try {
      file = await fileIo.open(path, mode);
      await fileIo.write(file.fd, content, { encoding: 'utf-8' });
    } catch (error) {
      throw new Error(`写入文件失败: ${path}, ${String(error)}`);
    } finally {
      if (file !== undefined) {
        try {
          await fileIo.close(file);
        } catch (error) {
        }
      }
    }
  }

  private resolvePath(path: string): string {
    const normalized = this.normalizeRelativePath(path);
    return normalized.length === 0 ? this.baseDirectory : `${this.baseDirectory}/${normalized}`;
  }

  private normalizeBaseDirectory(path: string): string {
    const normalized = path.replace(/\\/g, '/');
    let end = normalized.length;
    while (end > 1 && normalized.charAt(end - 1) === '/') {
      end -= 1;
    }
    return normalized.substring(0, end);
  }

  private normalizeRelativePath(path: string): string {
    const parts = path.replace(/\\/g, '/').split('/');
    const normalized = new Array<string>();
    for (let index = 0; index < parts.length; index += 1) {
      const part = parts[index];
      if (part.length === 0 || part === '.') {
        continue;
      }
      if (part === '..') {
        throw new Error(`非法存储路径: ${path}`);
      }
      normalized.push(part);
    }
    return normalized.join('/');
  }
}

/**
 * 提供仅用于测试和示例的内存文件系统实现。
 * 在单元测试或示例代码中替代 SandboxTavernFileStore，避免对实际文件系统的依赖。
 */
export class InMemoryFileStore implements TavernFileStore {
  /**
   * 以规范化相对路径为键，保存文件文本内容。
   */
  private files: Map<string, string> = new Map<string, string>();
  /**
   * 已创建的目录路径集合，模拟目录存在性和 list 行为。
   */
  private directories: Set<string> = new Set<string>();

  /**
   * 初始化 InMemoryFileStore，默认包含根目录。
   */
  constructor() {
    this.directories.add('');
  }

  /**
   * 确保目录路径存在，必要时创建缺失的中间目录。
   * @param path 目标文件或目录路径。
   */
  async ensureDirectory(path: string): Promise<void> {
    const normalized = this.normalize(path);
    if (normalized.length === 0) {
      this.directories.add('');
      return;
    }
    const parts = normalized.split('/');
    let current = '';
    for (let index = 0; index < parts.length; index += 1) {
      current = current.length === 0 ? parts[index] : `${current}/${parts[index]}`;
      this.directories.add(current);
    }
  }

  /**
   * 检查指定路径是否存在文件或目录。
   * @param path 要检查的文件或目录路径。
   * @returns 存在文件或目录记录时返回 true，否则返回 false。
   */
  async exists(path: string): Promise<boolean> {
    const normalized = this.normalize(path);
    return this.files.has(normalized) || this.directories.has(normalized);
  }

  /**
   * 读取指定路径的文本内容；文件不存在时抛出错误。
   * @param path 要读取的文件路径。
   */
  async readText(path: string): Promise<string> {
    const normalized = this.normalize(path);
    const content = this.files.get(normalized);
    if (content === undefined) {
      throw new Error(`File not found: ${normalized}`);
    }
    return content;
  }

  /**
   * 把文本写入指定路径，按参数决定是否保留 .bak 备份。
   * @param path 要写入的文件路径。
   * @param content 要写入的文本。
   * @param createBackup 写入前是否复制已有文件为 .bak。
   */
  async writeText(path: string, content: string, createBackup: boolean): Promise<void> {
    const normalized = this.normalize(path);
    await this.ensureParentDirectory(normalized);

    if (createBackup) {
      const backupContent = this.files.get(normalized);
      this.files.set(`${normalized}.bak`, backupContent === undefined ? '' : backupContent);
    }

    this.files.set(`${normalized}.tmp`, content);
    this.files.set(normalized, content);
    this.files.delete(`${normalized}.tmp`);
  }

  /**
   * 向指定文件尾部追加文本内容。
   * @param path 要追加的文件路径。
   * @param content 要追加的文本。
   */
  async appendText(path: string, content: string): Promise<void> {
    const normalized = this.normalize(path);
    await this.ensureParentDirectory(normalized);
    const previous = this.files.get(normalized);
    this.files.set(normalized, previous === undefined ? content : previous + content);
  }

  /**
   * 删除指定文件或目录。
   * @param path 要删除的文件或目录路径。
   */
  async delete(path: string): Promise<void> {
    const normalized = this.normalize(path);
    this.files.delete(normalized);
    this.directories.delete(normalized);
  }

  /**
   * 列出指定目录下的直接子项名称。
   * @param path 要列出的目录路径。
   * @returns 子项名称的数组，按字母排序。
   */
  async list(path: string): Promise<Array<string>> {
    const normalized = this.normalize(path);
    const prefix = normalized.length === 0 ? '' : `${normalized}/`;
    const results = new Set<string>();

    this.files.forEach((_value: string, key: string) => {
      this.collectChild(results, prefix, key);
    });
    this.directories.forEach((key: string) => {
      this.collectChild(results, prefix, key);
    });

    return Array.from(results).sort();
  }

  /**
   * 写入文件前确保父目录存在于目录集合中。
   * @param path 已规范化的文件路径。
   */
  private async ensureParentDirectory(path: string): Promise<void> {
    const lastSlash = path.lastIndexOf('/');
    if (lastSlash < 0) {
      return;
    }
    await this.ensureDirectory(path.substring(0, lastSlash));
  }

  /**
   * 从完整路径中提取当前目录下的直接子项名称，加入结果集合。
   * @param results 用于去重的子项名称集合。
   * @param prefix 当前目录的规范化前缀（以 / 结尾）。
   * @param candidate 待检查的文件或目录完整路径。
   */
  private collectChild(results: Set<string>, prefix: string, candidate: string): void {
    if (candidate.length === 0 || !candidate.startsWith(prefix) || candidate === prefix) {
      return;
    }
    const rest = candidate.substring(prefix.length);
    const slashIndex = rest.indexOf('/');
    results.add(slashIndex < 0 ? rest : rest.substring(0, slashIndex));
  }

  /**
   * 把路径统一为正斜杠分隔的相对路径，折叠空段和当前目录段，阻止父目录逃逸。
   * @param path 要规范化的路径。
   */
  private normalize(path: string): string {
    const parts = path.replace(/\\/g, '/').split('/');
    const normalized = new Array<string>();
    for (let index = 0; index < parts.length; index += 1) {
      const part = parts[index];
      if (part.length === 0 || part === '.') {
        continue;
      }
      if (part === '..') {
        if (normalized.length > 0 && normalized[normalized.length - 1] !== '..') {
          normalized.pop();
        } else {
          normalized.push(part);
        }
        continue;
      }
      normalized.push(part);
    }
    return normalized.join('/');
  }

}
