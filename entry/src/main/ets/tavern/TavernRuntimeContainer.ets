import {
  CharacterRuntime,
  ChatRuntime,
  EventBus,
  PromptRuntime,
  ProviderRuntime,
  StreamingRuntime,
  WorldInfoRuntime,
  type MessageRuntime,
  type TavernFileStore,
} from 'tavern_ohos';
import { HarmonyTavernFileStore } from './HarmonyTavernFileStore';

export class TavernRuntimeContainer {
  static readonly ROOT_PATH: string = 'tavern-data';
  static readonly USER_ID: string = 'default';

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

  private initPromise: Promise<void> | undefined = undefined;

  private constructor(files: TavernFileStore) {
    this.events = new EventBus();
    this.files = files;
    this.rootPath = TavernRuntimeContainer.ROOT_PATH;
    this.userId = TavernRuntimeContainer.USER_ID;
    this.characters = new CharacterRuntime(this.files, this.events, this.rootPath, this.userId);
    this.chats = new ChatRuntime(this.files, this.events, this.rootPath, this.userId);
    this.worldInfo = new WorldInfoRuntime(this.files, this.events, this.rootPath, this.userId);
    this.prompt = new PromptRuntime(this.events);
    this.streaming = new StreamingRuntime(this.events);
    this.provider = new ProviderRuntime(this.events, this.streaming);
  }

  static configure(filesBasePath: string): TavernRuntimeContainer {
    if (TavernRuntimeContainer.instance === undefined) {
      TavernRuntimeContainer.instance = new TavernRuntimeContainer(new HarmonyTavernFileStore(filesBasePath));
    }
    return TavernRuntimeContainer.instance;
  }

  static getInstance(): TavernRuntimeContainer {
    if (TavernRuntimeContainer.instance === undefined) {
      throw new Error('TavernRuntimeContainer 尚未初始化');
    }
    return TavernRuntimeContainer.instance;
  }

  init(): Promise<void> {
    let promise = this.initPromise;
    if (promise === undefined) {
      promise = this.files.ensureTavernDataLayout(this.rootPath);
      this.initPromise = promise;
    }
    return promise;
  }

  messages(chatId: string): MessageRuntime {
    const messages: MessageRuntime = this.chats.messages(chatId);
    this.streaming.attachMessageRuntime(messages);
    return messages;
  }
}
