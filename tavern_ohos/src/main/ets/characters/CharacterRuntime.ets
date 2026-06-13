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

export class CharacterRuntime {
  private files: TavernFileStore;
  private events: EventBus;
  private rootPath: string;
  private userId: string;

  constructor(files: TavernFileStore, events: EventBus, rootPath: string, userId: string) {
    this.files = files;
    this.events = events;
    this.rootPath = rootPath;
    this.userId = userId;
  }

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

  async exportCharacterJson(characterId: string): Promise<string> {
    const character = await this.getCharacter(characterId);
    if (character.sourceJson.length > 0) {
      return character.sourceJson;
    }

    const card = this.toCardV2(character);
    return JSON.stringify(card);
  }

  async getCharacter(characterId: string): Promise<CharacterRecord> {
    const exists = await this.files.exists(this.characterPath(characterId));
    if (!exists) {
      throw new Error(`Character not found: ${characterId}`);
    }
    const store = new JsonStore<CharacterRecord>(this.files, this.characterPath(characterId));
    return this.copyCharacter(await store.read(this.defaultCharacter(characterId)));
  }

  async listCharacters(): Promise<Array<CharacterIndexEntry>> {
    const index = await this.readIndex();
    return index.items.slice();
  }

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

  private async readIndex(): Promise<CharacterIndex> {
    const store = new JsonStore<CharacterIndex>(this.files, this.indexPath());
    return store.read(this.defaultIndex());
  }

  private async writeIndex(index: CharacterIndex): Promise<void> {
    const store = new JsonStore<CharacterIndex>(this.files, this.indexPath());
    await store.write(index);
  }

  private async writeCharacter(character: CharacterRecord): Promise<void> {
    await this.files.ensureDirectory(this.characterDirectory(character.id));
    const store = new JsonStore<CharacterRecord>(this.files, this.characterPath(character.id));
    await store.write(character);
  }

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

  private publishCharacterEvent(eventName: string, character: CharacterRecord): void {
    const payload: CharacterEventPayload = {
      character: this.copyCharacter(character),
    };
    this.events.publish<CharacterEventPayload>(eventName, payload);
  }

  private async deleteDirectoryTree(path: string): Promise<void> {
    const children = await this.files.list(path);
    for (let index = 0; index < children.length; index += 1) {
      await this.deleteDirectoryTree(`${path}/${children[index]}`);
    }
    await this.files.delete(path);
  }

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
