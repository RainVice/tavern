import fileIo from '@ohos.file.fs';

/**
 * 定义 Runtime 访问文件系统的最小能力。
 *
 * 常规场景使用 SandboxTavernFileStore；测试、加密存储或云同步等特殊场景可自行实现该接口。
 */
export interface TavernFileStore {
  /**
   * 确保目录路径存在，必要时创建缺失的中间目录。
   * @param path 目标文件或目录路径。
   */
  ensureDirectory(path: string): Promise<void>;

  /**
   * 检查指定路径是否存在文件或目录，调用方可据此决定读取、写入或创建。
   * @param path 目标文件或目录路径。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  exists(path: string): Promise<boolean>;

  /**
   * 读取指定路径的文本内容，路径不存在时由存储实现抛出错误。
   * @param path 目标文件或目录路径。
   */
  readText(path: string): Promise<string>;

  /**
   * 把文本写入指定路径，并按参数决定是否保留备份。
   * @param path 目标文件或目录路径。
   * @param content 要写入或追加的文本内容。
   * @param createBackup 写入前是否创建备份。
   */
  writeText(path: string, content: string, createBackup: boolean): Promise<void>;

  /**
   * 向指定文本文件追加内容，常用于 JSONL 或日志类存储。
   * @param path 目标文件或目录路径。
   * @param content 要写入或追加的文本内容。
   */
  appendText(path: string, content: string): Promise<void>;

  /**
   * 删除指定文件或目录，具体递归策略由存储实现负责。
   * @param path 目标文件或目录路径。
   */
  delete(path: string): Promise<void>;

  /**
   * 列出指定目录下的直接子项名称，用于构建索引或资源列表。
   * @param path 目标文件或目录路径。
   * @returns 文件/目录名称列表副本。
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
   * 应用沙箱中的存储根目录。
   */
  private baseDirectory: string;

  /**
   * @param baseDirectory 应用可写沙箱目录，例如宿主从上下文取得的 `filesDir`。
   */
  constructor(baseDirectory: string) {
    this.baseDirectory = this.normalizeBaseDirectory(baseDirectory);
  }

  /**
   * 确保目录路径存在，必要时创建缺失的中间目录。
   * @param path 相对 SDK 存储根的目录路径。
   */
  async ensureDirectory(path: string): Promise<void> {
    const target = this.resolvePath(path);
    if (await this.exists(path)) {
      return;
    }
    try {
      await fileIo.mkdir(target, true);
    } catch (error) {
      if (await this.exists(path)) {
        return;
      }
      throw new Error(`创建目录失败: ${path}, ${String(error)}`);
    }
  }

  /**
   * 检查指定路径是否存在文件或目录。
   * @param path 相对 SDK 存储根的文件或目录路径。
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
   * @param path 相对 SDK 存储根的文件路径。
   */
  async readText(path: string): Promise<string> {
    try {
      return await fileIo.readText(this.resolvePath(path));
    } catch (error) {
      throw new Error(`读取文件失败: ${path}, ${String(error)}`);
    }
  }

  /**
   * 写入文本内容；写入前按需创建父目录；如需备份，将已有文件复制为 .bak。
   * @param path 相对 SDK 存储根的文件路径。
   * @param content 要写入的文本。
   * @param createBackup 写入前是否将已有文件复制为 `.bak` 备份。
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
   * 向文本文件尾部追加内容，文件不存在时创建文件。
   * @param path 相对 SDK 存储根的文件路径。
   * @param content 要追加的文本。
   */
  async appendText(path: string, content: string): Promise<void> {
    const target = this.resolvePath(path);
    await this.ensureParentDirectory(path);
    await this.writeFile(target, content, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.APPEND);
  }

  /**
   * 删除指定文件或空目录；路径不存在时不做处理。
   * @param path 相对 SDK 存储根的文件或目录路径。
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
   * @param path 相对 SDK 存储根的目录路径。
   */
  async list(path: string): Promise<Array<string>> {
    if (!(await this.exists(path))) {
      return new Array<string>();
    }
    try {
      const names = await fileIo.listFile(this.resolvePath(path), { recursion: false });
      return names.sort();
    } catch (error) {
      if (String(error).indexOf('Not a directory') >= 0) {
        return new Array<string>();
      }
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
 * 用于测试和示例的内存文件系统实现。
 *
 * 所有文件内容存放在 Map 中，目录结构存放在 Set 中，不涉及真实磁盘 I/O。
 */
export class InMemoryFileStore implements TavernFileStore {
  /**
   * 以规范化后的相对路径保存文件文本内容。
   */
  private files: Map<string, string> = new Map<string, string>();
  /**
   * 记录已经创建的目录路径，用于模拟目录存在性和 list 行为。
   */
  private directories: Set<string> = new Set<string>();

  /**
   * 初始化当前运行时实例。
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
   * 检查指定路径是否存在文件或目录，调用方可据此决定读取、写入或创建。
   * @param path 目标文件或目录路径。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  async exists(path: string): Promise<boolean> {
    const normalized = this.normalize(path);
    return this.files.has(normalized) || this.directories.has(normalized);
  }

  /**
   * 读取指定路径的文本内容，路径不存在时由存储实现抛出错误。
   * @param path 目标文件或目录路径。
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
   * 把文本写入指定路径，并按参数决定是否保留备份。
   * @param path 目标文件或目录路径。
   * @param content 要写入或追加的文本内容。
   * @param createBackup 写入前是否创建备份。
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
   * 向指定文本文件追加内容，常用于 JSONL 或日志类存储。
   * @param path 目标文件或目录路径。
   * @param content 要写入或追加的文本内容。
   */
  async appendText(path: string, content: string): Promise<void> {
    const normalized = this.normalize(path);
    await this.ensureParentDirectory(normalized);
    const previous = this.files.get(normalized);
    this.files.set(normalized, previous === undefined ? content : previous + content);
  }

  /**
   * 删除指定文件或目录，具体递归策略由存储实现负责。
   * @param path 目标文件或目录路径。
   */
  async delete(path: string): Promise<void> {
    const normalized = this.normalize(path);
    this.files.delete(normalized);
    this.directories.delete(normalized);
  }

  /**
   * 列出指定目录下的直接子项名称，用于构建索引或资源列表。
   * @param path 目标文件或目录路径。
   * @returns 文件/目录名称列表副本。
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
   * 写文件前确保父目录存在。
   * 路径中不含斜杠（即文件位于根目录）时不做处理。
   * @param path 目标文件或目录路径。
   */
  private async ensureParentDirectory(path: string): Promise<void> {
    const lastSlash = path.lastIndexOf('/');
    if (lastSlash < 0) {
      return;
    }
    await this.ensureDirectory(path.substring(0, lastSlash));
  }

  /**
   * 从完整路径中提取当前 List 目录的直接子项名称。
   *
   * 用于 list() 去重——检查 candidate 路径是否以 prefix 开头，
   * 如果是则提取其下一级名称加入 results。
   * @param results 用于收集并去重子项名称的集合。
   * @param prefix 当前 list 目录的规范化前缀。
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
   * 把路径统一成正斜杠分隔的相对路径，并折叠空段和当前目录段。
   * @param path 目标文件或目录路径。
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
