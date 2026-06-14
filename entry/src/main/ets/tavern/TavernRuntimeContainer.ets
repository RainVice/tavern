import {
  CharacterRuntime,
  ChatRuntime,
  ConnectionProfileRuntime,
  EventBus,
  PromptRuntime,
  ProviderRuntime,
  SandboxTavernFileStore,
  StreamingRuntime,
  WorldInfoRuntime,
  type CharacterRecord,
  type MessageRuntime,
  type TavernFileStore,
} from 'tavern_ohos';

export class TavernRuntimeContainer {
  static readonly ROOT_PATH: string = 'tavern-data';
  static readonly USER_ID: string = 'default';
  static readonly DEFAULT_CONNECTION_SCOPE: string = 'global';
  static readonly DEFAULT_CONNECTION_SCOPE_ID: string = 'default-provider';

  private static instance: TavernRuntimeContainer | undefined = undefined;

  readonly events: EventBus;
  readonly files: TavernFileStore;
  readonly rootPath: string;
  readonly userId: string;
  readonly characters: CharacterRuntime;
  readonly chats: ChatRuntime;
  readonly worldInfo: WorldInfoRuntime;
  readonly prompt: PromptRuntime;
  readonly streaming: StreamingRuntime;
  readonly provider: ProviderRuntime;
  readonly connections: ConnectionProfileRuntime;
  private connectionLoadPromise: Promise<void> | undefined = undefined;

  private constructor(appFilesDir: string, files?: TavernFileStore) {
    this.events = new EventBus();
    this.files = files ?? new SandboxTavernFileStore(appFilesDir);
    this.rootPath = TavernRuntimeContainer.ROOT_PATH;
    this.userId = TavernRuntimeContainer.USER_ID;
    this.characters = new CharacterRuntime(this.files, this.events, this.rootPath, this.userId);
    this.chats = new ChatRuntime(this.files, this.events, this.rootPath, this.userId);
    this.worldInfo = new WorldInfoRuntime(this.files, this.events, this.rootPath, this.userId);
    this.prompt = new PromptRuntime(this.events);
    this.streaming = new StreamingRuntime(this.events);
    this.provider = new ProviderRuntime(this.events, this.streaming);
    this.connections = new ConnectionProfileRuntime(this.events, this.files, this.rootPath, this.userId);
  }

  static configure(appFilesDir: string, files?: TavernFileStore): TavernRuntimeContainer {
    if (TavernRuntimeContainer.instance === undefined) {
      TavernRuntimeContainer.instance = new TavernRuntimeContainer(appFilesDir, files);
    }
    return TavernRuntimeContainer.instance;
  }

  static getInstance(): TavernRuntimeContainer {
    if (TavernRuntimeContainer.instance === undefined) {
      throw new Error('TavernRuntimeContainer 尚未初始化');
    }
    return TavernRuntimeContainer.instance;
  }

  messages(chatId: string): MessageRuntime {
    const messages: MessageRuntime = this.chats.messages(chatId);
    this.streaming.attachMessageRuntime(messages);
    return messages;
  }

  loadConnections(): Promise<void> {
    if (this.connectionLoadPromise === undefined) {
      this.connectionLoadPromise = this.connections.loadFromStore();
    }
    return this.connectionLoadPromise;
  }

  async readCharacterAvatar(character: CharacterRecord): Promise<string> {
    const path = this.characterAvatarFilePath(character);
    if (!(await this.files.exists(path))) {
      return '';
    }
    return this.files.readText(path);
  }

  async writeCharacterAvatar(character: CharacterRecord, avatarContent: string): Promise<void> {
    const content = avatarContent.trim();
    if (content.length === 0) {
      return;
    }
    await this.files.writeText(this.characterAvatarFilePath(character), content, true);
  }

  private characterAvatarFilePath(character: CharacterRecord): string {
    return `${this.rootPath}/users/${this.userId}/characters/${character.avatarPath}`;
  }
}
