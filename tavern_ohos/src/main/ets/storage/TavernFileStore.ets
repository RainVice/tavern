export interface TavernFileStore {
  ensureDirectory(path: string): Promise<void>;

  ensureTavernDataLayout(rootPath: string): Promise<void>;

  exists(path: string): Promise<boolean>;

  readText(path: string): Promise<string>;

  writeText(path: string, content: string, createBackup: boolean): Promise<void>;

  appendText(path: string, content: string): Promise<void>;

  delete(path: string): Promise<void>;

  list(path: string): Promise<Array<string>>;
}

export class InMemoryFileStore implements TavernFileStore {
  private files: Map<string, string> = new Map<string, string>();
  private directories: Set<string> = new Set<string>();

  constructor() {
    this.directories.add('');
  }

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

  async ensureTavernDataLayout(rootPath: string): Promise<void> {
    const root = this.normalize(rootPath);
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
    const normalized = this.normalize(path);
    return this.files.has(normalized) || this.directories.has(normalized);
  }

  async readText(path: string): Promise<string> {
    const normalized = this.normalize(path);
    const content = this.files.get(normalized);
    if (content === undefined) {
      throw new Error(`File not found: ${normalized}`);
    }
    return content;
  }

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

  async appendText(path: string, content: string): Promise<void> {
    const normalized = this.normalize(path);
    await this.ensureParentDirectory(normalized);
    const previous = this.files.get(normalized);
    this.files.set(normalized, previous === undefined ? content : previous + content);
  }

  async delete(path: string): Promise<void> {
    const normalized = this.normalize(path);
    this.files.delete(normalized);
    this.directories.delete(normalized);
  }

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

  private async ensureParentDirectory(path: string): Promise<void> {
    const lastSlash = path.lastIndexOf('/');
    if (lastSlash < 0) {
      return;
    }
    await this.ensureDirectory(path.substring(0, lastSlash));
  }

  private collectChild(results: Set<string>, prefix: string, candidate: string): void {
    if (candidate.length === 0 || !candidate.startsWith(prefix) || candidate === prefix) {
      return;
    }

    const rest = candidate.substring(prefix.length);
    const slashIndex = rest.indexOf('/');
    results.add(slashIndex < 0 ? rest : rest.substring(0, slashIndex));
  }

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
