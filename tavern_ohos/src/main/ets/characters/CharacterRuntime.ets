import { EventBus } from '../runtime/EventBus';
import { safePathSegment } from '../shared/PathSafety';
import { JsonStore } from '../storage/JsonStore';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  CharacterCardV2,
  CharacterCreateParams,
  CharacterDeletedPayload,
  CharacterEventPayload,
  CharacterIndex,
  CharacterIndexEntry,
  CharacterRecord,
  CharacterUpdateParams,
} from './CharacterModels';

/**
 * 提供角色卡相关的无 UI 运行时能力，负责角色记录的新增、查询、更新、删除和事件发布，
 * 供角色列表页、角色编辑页、角色导入导出流程等 UI 层调用。
 */
export class CharacterRuntime {
  /**
   * 文件存储适配器，用于读写角色数据和索引文件。
   */
  private files: TavernFileStore;
  /**
   * 事件总线，用于发布角色创建、更新、删除等事件。
   */
  private events: EventBus;
  /**
   * 角色数据存储的根路径。
   */
  private rootPath: string;
  /**
   * 当前操作用户的标识。
   */
  private userId: string;

  /**
   * 初始化当前运行时实例，在应用启动或进入角色管理模块时调用。
   * @param files 文件存储适配器，负责角色数据和索引文件的实际读写操作。
   * @param events 事件总线，用于在角色创建、更新、删除后发布事件通知其他模块。
   * @param rootPath 数据存储的根路径，用于构建角色文件的存储目录结构。
   * @param userId 当前操作用户的标识，用于隔离不同用户的角色数据。
   */
  constructor(files: TavernFileStore, events: EventBus, rootPath: string, userId: string) {
    this.files = files;
    this.events = events;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  /**
   * 创建新的角色记录，在用户通过角色创建表单提交时调用。
   * 流程：分配自增唯一标识 -> 组装完整角色记录 -> 写入文件存储 -> 更新索引 -> 发布 character.created 事件。
   * @param params 包含角色名称、描述、性格、场景、开场消息、对话示例等字段的创建参数，由角色创建表单提供。
   * @returns 创建后的角色记录副本，用于 UI 跳转到新角色详情页或列表刷新。
   */
  async createCharacter(params: CharacterCreateParams): Promise<CharacterRecord> {
    const index = await this.readIndex();
    const id = `char-${index.nextId}`;
    index.nextId += 1;
    const now = Date.now();
    const character: CharacterRecord = {
      schemaVersion: 1,
      id: id,
      name: params.name,
      description: params.description,
      personality: params.personality,
      scenario: params.scenario,
      firstMessage: params.firstMessage,
      exampleDialogue: params.exampleDialogue,
      creatorNotes: '',
      systemPrompt: '',
      postHistoryInstructions: '',
      creator: '',
      characterVersion: '',
      avatarPath: `${id}/avatar.png`,
      tags: params.tags.slice(),
      alternateGreetings: new Array<string>(),
      favorite: params.favorite === undefined ? false : params.favorite,
      talkativeness: params.talkativeness === undefined ? 0.5 : params.talkativeness,
      world: params.world === undefined ? '' : params.world,
      sourceFormat: 'runtime_json',
      sourceJson: '',
      createdAt: now,
      updatedAt: now,
    };

    await this.writeCharacter(character);
    index.items.push(this.toIndexEntry(character));
    await this.writeIndex(index);
    this.publishCharacterEvent('character.created', character);
    return this.copyCharacter(character);
  }

  /**
   * 导入 SillyTavern V2 角色卡 JSON，在用户从外部选择角色卡文件导入时调用。
   * 流程：解析 V2 JSON -> 分配新角色标识 -> 保存为内部角色记录 -> 更新索引 -> 发布 character.imported 事件。
   * @param cardJson 外部 SillyTavern V2 角色卡的 JSON 字符串，由文件选择器或拖拽导入提供。
   * @returns 导入后的角色记录副本，用于 UI 跳转到新角色详情页。
   */
  async importCharacterJson(cardJson: string): Promise<CharacterRecord> {
    const card = JSON.parse(cardJson) as CharacterCardV2;
    const index = await this.readIndex();
    const id = `char-${index.nextId}`;
    index.nextId += 1;
    const now = Date.now();
    const extensions = card.data.extensions;
    const character: CharacterRecord = {
      schemaVersion: 1,
      id: id,
      name: card.data.name,
      description: card.data.description,
      personality: card.data.personality,
      scenario: card.data.scenario,
      firstMessage: card.data.first_mes,
      exampleDialogue: card.data.mes_example,
      creatorNotes: card.data.creator_notes === undefined ? '' : card.data.creator_notes,
      systemPrompt: card.data.system_prompt === undefined ? '' : card.data.system_prompt,
      postHistoryInstructions: card.data.post_history_instructions === undefined ? '' : card.data.post_history_instructions,
      creator: card.data.creator === undefined ? '' : card.data.creator,
      characterVersion: card.data.character_version === undefined ? '' : card.data.character_version,
      avatarPath: `${id}/avatar.png`,
      tags: card.data.tags === undefined ? new Array<string>() : card.data.tags.slice(),
      alternateGreetings: card.data.alternate_greetings === undefined ? new Array<string>() : card.data.alternate_greetings.slice(),
      favorite: extensions === undefined || extensions.fav === undefined ? false : extensions.fav,
      talkativeness: extensions === undefined || extensions.talkativeness === undefined ? 0.5 : extensions.talkativeness,
      world: extensions === undefined || extensions.world === undefined ? '' : extensions.world,
      sourceFormat: 'character_card_v2_json',
      sourceJson: cardJson,
      createdAt: now,
      updatedAt: now,
    };

    await this.writeCharacter(character);
    index.items.push(this.toIndexEntry(character));
    await this.writeIndex(index);
    this.publishCharacterEvent('character.imported', character);
    return this.copyCharacter(character);
  }

  /**
   * 导出角色卡 JSON，在用户点击角色详情页的导出按钮时调用。
   * 流程：如果角色来自外部导入（sourceJson 非空），优先返回原始 JSON 以保留原格式；
   * 否则构建 SillyTavern V2 格式 JSON 返回。
   * @param characterId 要导出的角色标识，由角色详情或列表页传入。
   * @returns 角色卡的 JSON 字符串，可用于保存为文件或分享。
   */
  async exportCharacterJson(characterId: string): Promise<string> {
    const character = await this.getCharacter(characterId);
    if (character.sourceJson.length > 0) {
      return character.sourceJson;
    }
    const card = this.toCardV2(character);
    return JSON.stringify(card);
  }

  /**
   * 根据角色标识读取角色记录，在角色详情页或编辑页加载时调用。
   * 文件不存在时抛出错误，由调用方处理。
   * @param characterId 要读取的角色标识，由路由参数或列表选择传入。
   * @returns 角色记录的副本，用于 UI 展示或编辑表单初始化。
   */
  async getCharacter(characterId: string): Promise<CharacterRecord> {
    const exists = await this.files.exists(this.characterPath(characterId));
    if (!exists) {
      throw new Error(`Character not found: ${characterId}`);
    }
    const store = new JsonStore<CharacterRecord>(this.files, this.characterPath(characterId));
    return this.copyCharacter(await store.read(this.defaultCharacter(characterId)));
  }

  /**
   * 读取角色索引列表，在角色列表页加载时调用。
   * 仅返回摘要信息（名称、头像、标签等），避免加载完整角色记录以提高列表性能。
   * @returns 角色索引条目的副本列表，用于角色列表页的网格或列表展示。
   */
  async listCharacters(): Promise<Array<CharacterIndexEntry>> {
    const index = await this.readIndex();
    return index.items.slice();
  }

  /**
   * 更新指定角色的所有字段，在用户通过角色编辑页提交修改时调用。
   * 流程：读取当前记录 -> 逐字段替换 -> 写回文件存储 -> 刷新索引 -> 发布 character.updated 事件。
   * @param characterId 要更新的角色标识，由编辑页路由参数传入。
   * @param params 包含更新后角色信息的参数，由编辑表单提交数据生成。
   * @returns 更新后的角色记录副本，用于 UI 刷新详情页。
   */
  async updateCharacter(characterId: string, params: CharacterUpdateParams): Promise<CharacterRecord> {
    const character = await this.getCharacter(characterId);
    character.name = params.name;
    character.description = params.description;
    character.personality = params.personality;
    character.scenario = params.scenario;
    character.firstMessage = params.firstMessage;
    character.exampleDialogue = params.exampleDialogue;
    character.tags = params.tags.slice();
    character.favorite = params.favorite;
    character.sourceJson = '';
    character.updatedAt = Date.now();

    await this.writeCharacter(character);
    await this.replaceIndexEntry(character);
    this.publishCharacterEvent('character.updated', character);
    return this.copyCharacter(character);
  }

  /**
   * 复制指定角色（生成新标识、新头像路径和新创建时间），在用户点击角色列表或详情页的"复制"按钮时调用。
   * 流程：读取原角色 -> 分配新 ID -> 复制所有字段 -> 写入存储 -> 更新索引 -> 发布 character.created 事件。
   * @param characterId 要复制的原角色标识，由当前选中的角色传入。
   * @param newName 复制后的新角色名称，由用户输入的副本名称确定。
   * @returns 复制后的角色记录副本，用于 UI 跳转到新角色。
   */
  async duplicateCharacter(characterId: string, newName: string): Promise<CharacterRecord> {
    const original = await this.getCharacter(characterId);
    const index = await this.readIndex();
    const id = `char-${index.nextId}`;
    index.nextId += 1;
    const now = Date.now();
    const duplicate: CharacterRecord = {
      schemaVersion: original.schemaVersion,
      id: id,
      name: newName,
      description: original.description,
      personality: original.personality,
      scenario: original.scenario,
      firstMessage: original.firstMessage,
      exampleDialogue: original.exampleDialogue,
      creatorNotes: original.creatorNotes,
      systemPrompt: original.systemPrompt,
      postHistoryInstructions: original.postHistoryInstructions,
      creator: original.creator,
      characterVersion: original.characterVersion,
      avatarPath: `${id}/avatar.png`,
      tags: original.tags.slice(),
      alternateGreetings: original.alternateGreetings.slice(),
      favorite: original.favorite,
      talkativeness: original.talkativeness,
      world: original.world,
      sourceFormat: 'runtime_json',
      sourceJson: '',
      createdAt: now,
      updatedAt: now,
    };

    await this.writeCharacter(duplicate);
    index.items.push(this.toIndexEntry(duplicate));
    await this.writeIndex(index);
    this.publishCharacterEvent('character.created', duplicate);
    return this.copyCharacter(duplicate);
  }

  /**
   * 删除指定角色及其关联的所有文件，在用户确认删除角色时调用。
   * 流程：读取角色记录 -> 递归删除角色目录（含头像等文件）-> 从索引移除 -> 发布 character.deleted 和 character.deleted.id 事件。
   * @param characterId 要删除的角色标识，由角色列表或详情页的删除操作传入。
   */
  async deleteCharacter(characterId: string): Promise<void> {
    const character = await this.getCharacter(characterId);
    await this.deleteDirectoryTree(this.characterDirectory(characterId));
    const index = await this.readIndex();
    const remaining = new Array<CharacterIndexEntry>();
    for (let itemIndex = 0; itemIndex < index.items.length; itemIndex += 1) {
      const item = index.items[itemIndex];
      if (item.id !== characterId) {
        remaining.push(item);
      }
    }
    index.items = remaining;
    await this.writeIndex(index);
    this.publishCharacterEvent('character.deleted', character);
    const payload: CharacterDeletedPayload = {
      characterId: characterId,
    };
    this.events.publish<CharacterDeletedPayload>('character.deleted.id', payload);
  }
  private async replaceIndexEntry(character: CharacterRecord): Promise<void> {
    const index = await this.readIndex();
    const entry = this.toIndexEntry(character);
    let replaced = false;
    for (let itemIndex = 0; itemIndex < index.items.length; itemIndex += 1) {
      if (index.items[itemIndex].id === character.id) {
        index.items[itemIndex] = entry;
        replaced = true;
      }
    }
    if (!replaced) {
      index.items.push(entry);
    }
    await this.writeIndex(index);
  }

  /**
   * 从索引 JSON 文件中读取角色索引数据。
   * @returns 读取到的角色索引，文件不存在时返回默认索引。
   */
  private async readIndex(): Promise<CharacterIndex> {
    const store = new JsonStore<CharacterIndex>(this.files, this.indexPath());
    return store.read(this.defaultIndex());
  }

  /**
   * 将角色索引数据写入索引 JSON 文件。
   * @param index 要持久化的角色索引数据。
   */
  private async writeIndex(index: CharacterIndex): Promise<void> {
    const store = new JsonStore<CharacterIndex>(this.files, this.indexPath());
    await store.write(index);
  }

  /**
   * 将角色记录写入文件存储。
   * @param character 要写入的角色记录。
   */
  private async writeCharacter(character: CharacterRecord): Promise<void> {
    await this.files.ensureDirectory(this.characterDirectory(character.id));
    const store = new JsonStore<CharacterRecord>(this.files, this.characterPath(character.id));
    await store.write(character);
  }

  /**
   * 把角色完整记录转换为列表索引项（摘要数据）。
   * @param character 角色记录。
   * @returns 角色索引条目。
   */
  private toIndexEntry(character: CharacterRecord): CharacterIndexEntry {
    return {
      id: character.id,
      name: character.name,
      avatarPath: character.avatarPath,
      tags: character.tags.slice(),
      favorite: character.favorite,
      createdAt: character.createdAt,
      updatedAt: character.updatedAt,
    };
  }

  /**
   * 把 SDK 内部角色记录转换为 SillyTavern 角色卡 V2 结构，用于导出。
   * @param character 内部角色记录。
   * @returns 符合 CharacterCardV2 格式的导出结构。
   */
  private toCardV2(character: CharacterRecord): CharacterCardV2 {
    return {
      spec: 'chara_card_v2',
      spec_version: '2.0',
      data: {
        name: character.name,
        description: character.description,
        personality: character.personality,
        scenario: character.scenario,
        first_mes: character.firstMessage,
        mes_example: character.exampleDialogue,
        creator_notes: character.creatorNotes,
        system_prompt: character.systemPrompt,
        post_history_instructions: character.postHistoryInstructions,
        creator: character.creator,
        character_version: character.characterVersion,
        tags: character.tags.slice(),
        alternate_greetings: character.alternateGreetings.slice(),
        extensions: {
          fav: character.favorite,
          talkativeness: character.talkativeness,
          world: character.world,
        },
      },
    };
  }

  /**
   * 通过事件总线发布角色卡事件，将状态变更通知给其他运行时或 UI 组件。
   * @param eventName 发布的事件名称。
   * @param character 关联的角色记录。
   */
  private publishCharacterEvent(eventName: string, character: CharacterRecord): void {
    const payload: CharacterEventPayload = {
      character: this.copyCharacter(character),
    };
    this.events.publish<CharacterEventPayload>(eventName, payload);
  }

  /**
   * 递归删除指定路径及其所有子文件和子目录。
   * @param path 要删除的目录路径。
   */
  private async deleteDirectoryTree(path: string): Promise<void> {
    const children = await this.files.list(path);
    for (let index = 0; index < children.length; index += 1) {
      await this.deleteDirectoryTree(`${path}/${children[index]}`);
    }
    await this.files.delete(path);
  }

  /**
   * 复制角色记录的所有字段，避免外部代码持有内部可变引用。
   * @param character 原角色记录。
   * @returns 角色记录的副本。
   */
  private copyCharacter(character: CharacterRecord): CharacterRecord {
    return {
      schemaVersion: character.schemaVersion,
      id: character.id,
      name: character.name,
      description: character.description,
      personality: character.personality,
      scenario: character.scenario,
      firstMessage: character.firstMessage,
      exampleDialogue: character.exampleDialogue,
      creatorNotes: character.creatorNotes,
      systemPrompt: character.systemPrompt,
      postHistoryInstructions: character.postHistoryInstructions,
      creator: character.creator,
      characterVersion: character.characterVersion,
      avatarPath: character.avatarPath,
      tags: character.tags.slice(),
      alternateGreetings: character.alternateGreetings.slice(),
      favorite: character.favorite,
      talkativeness: character.talkativeness,
      world: character.world,
      sourceFormat: character.sourceFormat,
      sourceJson: character.sourceJson,
      createdAt: character.createdAt,
      updatedAt: character.updatedAt,
    };
  }
  private defaultIndex(): CharacterIndex {
    return {
      schemaVersion: 1,
      nextId: 1,
      items: new Array<CharacterIndexEntry>(),
    };
  }
  private defaultCharacter(characterId: string): CharacterRecord {
    return {
      schemaVersion: 1,
      id: characterId,
      name: '',
      description: '',
      personality: '',
      scenario: '',
      firstMessage: '',
      exampleDialogue: '',
      creatorNotes: '',
      systemPrompt: '',
      postHistoryInstructions: '',
      creator: '',
      characterVersion: '',
      avatarPath: `${characterId}/avatar.png`,
      tags: new Array<string>(),
      alternateGreetings: new Array<string>(),
      favorite: false,
      talkativeness: 0.5,
      world: '',
      sourceFormat: '',
      sourceJson: '',
      createdAt: 0,
      updatedAt: 0,
    };
  }
  private indexPath(): string {
    return `${this.charactersRoot()}/index.json`;
  }
  private characterDirectory(characterId: string): string {
    return `${this.charactersRoot()}/${safePathSegment(characterId, 'character')}`;
  }
  private characterPath(characterId: string): string {
    return `${this.characterDirectory(characterId)}/character.json`;
  }
  private charactersRoot(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/characters`;
  }
}
