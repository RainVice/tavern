import type { TavernFileStore } from './TavernFileStore';

export class JsonStore<T extends Object> {
  private files: TavernFileStore;
  private path: string;

  constructor(files: TavernFileStore, path: string) {
    this.files = files;
    this.path = path;
  }

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

  async write(value: T): Promise<void> {
    const content = JSON.stringify(value);
    await this.files.writeText(this.path, content, true);
    const saved = await this.files.readText(this.path);
    if (saved !== content) {
      throw new Error(`JSON write verification failed: ${this.path}`);
    }
  }
}
