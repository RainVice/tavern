import { fileIo } from '@kit.CoreFileKit';
import type { TavernFileStore } from 'tavern_ohos';

export class HarmonyTavernFileStore implements TavernFileStore {
  private readonly basePath: string;

  constructor(basePath: string) {
    this.basePath = this.normalizeBasePath(basePath);
    this.ensureDirectoryResolved(this.basePath);
  }

  async ensureDirectory(path: string): Promise<void> {
    this.ensureDirectoryResolved(this.resolvePath(path));
  }

  async ensureTavernDataLayout(rootPath: string): Promise<void> {
    const root = this.normalizeRelativePath(rootPath);
    const directories = this.buildTavernDirectories(root);
    for (let index = 0; index < directories.length; index += 1) {
      await this.ensureDirectory(directories[index]);
    }

    const files = this.buildTavernFiles(root);
    for (let index = 0; index < files.length; index += 1) {
      const filePath = files[index][0];
      if (!(await this.exists(filePath))) {
        await this.writeText(filePath, files[index][1], false);
      }
    }
  }

  async exists(path: string): Promise<boolean> {
    return this.existsResolvedPath(this.resolvePath(path));
  }

  async readText(path: string): Promise<string> {
    return this.readResolvedText(this.resolvePath(path));
  }

  async writeText(path: string, content: string, createBackup: boolean): Promise<void> {
    const targetPath = this.resolvePath(path);
    await this.ensureParentDirectory(path);

    if (createBackup && this.existsResolvedPath(targetPath)) {
      this.copyResolvedFile(targetPath, `${targetPath}.bak`);
    }

    const tempPath = `${targetPath}.tmp`;
    this.writeFile(tempPath, content, false);
    if (this.existsResolvedPath(targetPath)) {
      this.unlinkResolvedPath(targetPath);
    }
    this.moveResolvedFile(tempPath, targetPath);
  }

  async appendText(path: string, content: string): Promise<void> {
    await this.ensureParentDirectory(path);
    this.writeFile(this.resolvePath(path), content, true);
  }

  async delete(path: string): Promise<void> {
    const targetPath = this.resolvePath(path);
    if (!this.existsResolvedPath(targetPath)) {
      return;
    }
    this.deleteResolvedPath(targetPath);
  }

  async list(path: string): Promise<Array<string>> {
    const targetPath = this.resolvePath(path);
    if (!this.existsResolvedPath(targetPath)) {
      return new Array<string>();
    }
    return this.listResolvedPath(targetPath).sort();
  }

  private async ensureParentDirectory(path: string): Promise<void> {
    const normalized = this.normalizeRelativePath(path);
    const lastSlash = normalized.lastIndexOf('/');
    if (lastSlash < 0) {
      return;
    }
    await this.ensureDirectory(normalized.substring(0, lastSlash));
  }

  private writeFile(path: string, content: string, append: boolean): void {
    const mode = append
      ? fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.APPEND
      : fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC;
    const file = this.openResolvedFile(path, mode);
    try {
      this.writeResolvedFile(file, content);
    } finally {
      this.closeResolvedFile(file);
    }
  }

  private deleteResolvedPath(path: string): void {
    if (this.isResolvedDirectory(path)) {
      const children = this.listResolvedPath(path);
      for (let index = 0; index < children.length; index += 1) {
        this.deleteResolvedPath(`${path}/${children[index]}`);
      }
      this.removeResolvedDirectory(path);
      return;
    }
    this.unlinkResolvedPath(path);
  }

  private ensureDirectoryResolved(path: string): void {
    try {
      fileIo.mkdirSync(path, true);
    } catch (error) {
      throw new Error('创建 Tavern 目录失败: ' + path + ': ' + String(error));
    }
  }

  private existsResolvedPath(path: string): boolean {
    try {
      return fileIo.accessSync(path);
    } catch (error) {
      return false;
    }
  }

  private readResolvedText(path: string): string {
    try {
      return fileIo.readTextSync(path, { encoding: 'utf-8' });
    } catch (error) {
      throw new Error('读取 Tavern 文件失败: ' + path + ': ' + String(error));
    }
  }

  private copyResolvedFile(sourcePath: string, targetPath: string): void {
    try {
      fileIo.copyFileSync(sourcePath, targetPath);
    } catch (error) {
      throw new Error('备份 Tavern 文件失败: ' + sourcePath + ': ' + String(error));
    }
  }

  private openResolvedFile(path: string, mode: number): fileIo.File {
    try {
      return fileIo.openSync(path, mode);
    } catch (error) {
      throw new Error('打开 Tavern 文件失败: ' + path + ': ' + String(error));
    }
  }

  private writeResolvedFile(file: fileIo.File, content: string): void {
    try {
      fileIo.writeSync(file.fd, content, { encoding: 'utf-8' });
    } catch (error) {
      throw new Error('写入 Tavern 文件失败: ' + String(error));
    }
  }

  private closeResolvedFile(file: fileIo.File): void {
    try {
      fileIo.closeSync(file);
    } catch (error) {
      throw new Error('关闭 Tavern 文件失败: ' + String(error));
    }
  }

  private moveResolvedFile(sourcePath: string, targetPath: string): void {
    try {
      fileIo.moveFileSync(sourcePath, targetPath);
    } catch (error) {
      throw new Error('移动 Tavern 文件失败: ' + sourcePath + ': ' + String(error));
    }
  }

  private unlinkResolvedPath(path: string): void {
    try {
      fileIo.unlinkSync(path);
    } catch (error) {
      throw new Error('删除 Tavern 文件失败: ' + path + ': ' + String(error));
    }
  }

  private listResolvedPath(path: string): Array<string> {
    try {
      return fileIo.listFileSync(path, { recursion: false });
    } catch (error) {
      throw new Error('枚举 Tavern 目录失败: ' + path + ': ' + String(error));
    }
  }

  private isResolvedDirectory(path: string): boolean {
    try {
      return fileIo.statSync(path).isDirectory();
    } catch (error) {
      throw new Error('读取 Tavern 文件状态失败: ' + path + ': ' + String(error));
    }
  }

  private removeResolvedDirectory(path: string): void {
    try {
      fileIo.rmdirSync(path);
    } catch (error) {
      throw new Error('删除 Tavern 目录失败: ' + path + ': ' + String(error));
    }
  }

  private resolvePath(path: string): string {
    const normalized = this.normalizeRelativePath(path);
    if (normalized.length === 0) {
      return this.basePath;
    }
    return `${this.basePath}/${normalized}`;
  }

  private normalizeBasePath(path: string): string {
    let normalized = path.replace(/\\/g, '/');
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.length === 0) {
      throw new Error('Tavern 文件根目录不能为空');
    }
    return normalized;
  }

  private normalizeRelativePath(path: string): string {
    const value = path.replace(/\\/g, '/');
    if (value.startsWith('/') || value.indexOf(':') >= 0) {
      throw new Error('Tavern 路径必须是相对路径: ' + path);
    }

    const rawParts = value.split('/');
    const parts = new Array<string>();
    for (let index = 0; index < rawParts.length; index += 1) {
      const part = rawParts[index];
      if (part.length === 0 || part === '.') {
        continue;
      }
      if (part === '..') {
        throw new Error('Tavern 路径不能包含上级目录: ' + path);
      }
      parts.push(part);
    }
    return parts.join('/');
  }

  private buildTavernDirectories(root: string): Array<string> {
    return [
      root,
      `${root}/app`,
      `${root}/users`,
      `${root}/users/default`,
      `${root}/users/default/characters`,
      `${root}/users/default/personas`,
      `${root}/users/default/chats`,
      `${root}/users/default/groups`,
      `${root}/users/default/worldbooks`,
      `${root}/users/default/presets`,
      `${root}/users/default/presets/generation`,
      `${root}/users/default/presets/instruct`,
      `${root}/users/default/presets/context`,
      `${root}/users/default/presets/system`,
      `${root}/users/default/connection-profiles`,
      `${root}/users/default/quick-replies`,
      `${root}/users/default/quick-replies/sets`,
      `${root}/users/default/regex`,
      `${root}/users/default/regex/scripts`,
      `${root}/users/default/plugins`,
      `${root}/users/default/plugins/settings`,
      `${root}/users/default/plugins/data`,
      `${root}/users/default/databank`,
      `${root}/users/default/databank/documents`,
      `${root}/users/default/databank/chunks`,
      `${root}/users/default/vectors`,
      `${root}/users/default/vectors/collections`,
      `${root}/users/default/assets`,
      `${root}/users/default/assets/images`,
      `${root}/users/default/assets/audio`,
      `${root}/users/default/assets/backgrounds`,
      `${root}/users/default/assets/themes`,
      `${root}/users/default/assets/thumbnails`,
      `${root}/users/default/tasks`,
      `${root}/users/default/backups`,
      `${root}/users/default/logs`,
      `${root}/users/default/diagnostics`,
      `${root}/users/default/migrations`,
    ];
  }

  private buildTavernFiles(root: string): Array<Array<string>> {
    return [
      [`${root}/app/manifest.json`, '{"schemaVersion":1,"runtime":"tavern_ohos"}'],
      [`${root}/app/settings.json`, '{}'],
      [`${root}/app/runtime-state.json`, '{}'],
      [`${root}/users/default/profile.json`, '{"schemaVersion":1,"userId":"default"}'],
      [`${root}/users/default/settings.json`, '{}'],
    ];
  }
}
