import { EventBus } from '../runtime/EventBus';
import { safePathSegment } from '../shared/PathSafety';
import { JsonStore } from '../storage/JsonStore';
import type { TavernFileStore } from '../storage/TavernFileStore';
import type {
  PersonaBindingRecord,
  PersonaChangedPayload,
  PersonaCreateParams,
  PersonaDeletedPayload,
  PersonaExportData,
  PersonaPromptData,
  PersonaRecord,
  PersonaUpdatedPayload,
} from './PersonaModels';

interface PersonaStorageSnapshot {
  schemaVersion: number;
  personas: Array<PersonaRecord>;
  bindings: Array<PersonaBindingRecord>;
  selectedPersonaId: string;
}

/**
 * 提供用户人格相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 调用方（如聊天系统、Prompt 组装器）通过此运行时管理用户身份的选择、绑定和 Prompt 数据提供。
 */
export class PersonaRuntime {
  /**
   * 事件总线，用于在用户人格创建、更新、删除、切换时发布事件，通知监听方（如 UI 层）刷新显示。
   */
  private events: EventBus;
  /**
   * 文件存储适配器；未传入时仅使用内存态，不进行持久化。
   */
  private files: TavernFileStore | undefined = undefined;
  /**
   * 数据持久化的根路径，决定了人格数据在文件系统中的存储位置。
   */
  private rootPath: string = 'tavern-data';
  /**
   * 当前用户的标识，用于在文件系统中隔离不同用户的人格数据。
   */
  private userId: string = 'default';
  /**
   * 用户人格记录的内存索引，键为人格 ID。
   * 用于所有人格 CRUD 操作和 Prompt 数据构建。
   */
  private personas: Map<string, PersonaRecord> = new Map<string, PersonaRecord>();
  /**
   * 用户人格与作用域的绑定索引，键为 scope:scopeId。
   * 用于 bindPersona 和 buildPromptDataForScope 中的作用域解析。
   */
  private bindings: Map<string, PersonaBindingRecord> = new Map<string, PersonaBindingRecord>();
  /**
   * 当前选中的用户人格标识，用于 getSelectedPersona 和 selectPersona 切换。
   */
  private selectedPersonaId: string = '';

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线实例，用于发送用户人格变更事件。
   * @param files 可选的文件存储适配器，提供后将支持持久化。未传入时仅使用内存态。
   * @param rootPath 数据持久化根路径，用于构建存储文件路径。
   * @param userId 当前用户标识，用于隔离不同用户的人格数据。
   */
  constructor(
    events: EventBus,
    files?: TavernFileStore,
    rootPath: string = 'tavern-data',
    userId: string = 'default',
  ) {
    this.events = events;
    this.files = files;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  /**
   * 从文件存储中恢复用户人格记录、绑定关系和选中状态。
   * 调用方在应用启动时调用，确保运行时状态与持久化数据一致。
   */
  async loadFromStore(): Promise<void> {
    const store = new JsonStore<PersonaStorageSnapshot>(
      this.requireFiles(),
      this.storagePath(),
    );
    const snapshot = await store.read(this.defaultStorageSnapshot());
    this.personas.clear();
    this.bindings.clear();
    for (let index = 0; index < snapshot.personas.length; index += 1) {
      const persona = this.clonePersona(snapshot.personas[index]);
      this.personas.set(persona.id, persona);
    }
    for (let index = 0; index < snapshot.bindings.length; index += 1) {
      const binding = this.cloneBinding(snapshot.bindings[index]);
      this.bindings.set(
        this.bindingKey(binding.scope, binding.scopeId),
        binding,
      );
    }
    this.selectedPersonaId = snapshot.selectedPersonaId;
  }

  /**
   * 将当前内存中的用户人格记录、绑定关系和选中状态写入文件存储。
   * 调用方在人格管理操作（创建、更新、删除、绑定、切换）完成后调用，确保数据持久化。
   */
  async saveToStore(): Promise<void> {
    const personas = this.clonePersonas(Array.from(this.personas.values()));
    const bindings = this.cloneBindings(Array.from(this.bindings.values()));
    const selectedPersonaId = this.selectedPersonaId;
    const snapshot: PersonaStorageSnapshot = {
      schemaVersion: 1,
      personas: personas,
      bindings: bindings,
      selectedPersonaId: selectedPersonaId,
    };
    await new JsonStore<PersonaStorageSnapshot>(
      this.requireFiles(),
      this.storagePath(),
    ).write(snapshot);
  }

  /**
   * 创建新的用户人格记录，存入内存并发布创建事件。
   * 调用方（如 UI 界面）在用户添加新人格时调用。
   * @param params 创建用户人格的参数。
   * @returns 创建的用户人格记录副本。
   */
  createPersona(params: PersonaCreateParams): PersonaRecord {
    const persona = this.toRecord(params, Date.now());
    this.personas.set(persona.id, this.clonePersona(persona));
    this.publishUpdated('persona.created', persona);
    return this.clonePersona(persona);
  }

  /**
   * 更新指定用户人格的字段，存入内存并发布更新事件。
   * 调用方（如 UI 界面）在用户编辑人格信息时调用。
   * @param personaId 目标用户人格标识。
   * @param params 更新后的参数字段，将替换目标人格的完整数据。
   * @returns 更新后的用户人格记录副本。
   */
  updatePersona(personaId: string, params: PersonaCreateParams): PersonaRecord {
    this.requirePersona(personaId);
    const persona = this.toRecord(params, Date.now());
    persona.id = personaId;
    this.personas.set(persona.id, this.clonePersona(persona));
    this.publishUpdated('persona.updated', persona);
    return this.clonePersona(persona);
  }

  /**
   * 按 ID 读取用户人格记录，不存在时抛出异常。
   * 调用方在获取某人格详情时使用。
   * @param personaId 目标用户人格标识。
   * @returns 用户人格记录副本。
   */
  getPersona(personaId: string): PersonaRecord {
    return this.clonePersona(this.requirePersona(personaId));
  }

  /**
   * 返回当前所有用户人格记录的副本列表。
   * 调用方（如 UI 列表界面）在展示所有人格时使用。
   * @returns 用户人格记录列表副本。
   */
  listPersonas(): Array<PersonaRecord> {
    const result = new Array<PersonaRecord>();
    const values = Array.from(this.personas.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.clonePersona(values[index]));
    }
    return result;
  }

  /**
   * 删除指定用户人格，清理相关绑定，若为当前选中则清空选中状态。
   * 调用方（如 UI 界面）在用户删除人格时调用。
   * @param personaId 目标用户人格标识。
   */
  deletePersona(personaId: string): void {
    this.requirePersona(personaId);
    this.personas.delete(personaId);
    this.removeBindingsForPersona(personaId);
    if (this.selectedPersonaId === personaId) {
      this.selectedPersonaId = '';
    }
    const payload: PersonaDeletedPayload = {
      personaId: personaId,
    };
    this.events.publish<PersonaDeletedPayload>('persona.deleted', payload);
  }

  /**
   * 切换当前选中的用户人格，发布变更事件。
   * 调用方（如聊天界面）在用户切换发送者身份时调用。
   * @param personaId 要选中的用户人格标识。
   * @returns 选中的用户人格记录副本。
   */
  selectPersona(personaId: string): PersonaRecord {
    const persona = this.requirePersona(personaId);
    const previous = this.selectedPersonaId;
    this.selectedPersonaId = personaId;
    const payloadPersona = this.clonePersona(persona);
    const payload: PersonaChangedPayload = {
      persona: payloadPersona,
      previousPersonaId: previous,
    };
    this.events.publish<PersonaChangedPayload>('persona.changed', payload);
    return this.clonePersona(persona);
  }

  /**
   * 读取当前选中的用户人格记录，未选中时抛出异常。
   * 调用方（如 Prompt 组装器）在获取当前用户身份以构建系统提示时使用。
   * @returns 当前选中的用户人格记录副本。
   */
  getSelectedPersona(): PersonaRecord {
    return this.clonePersona(this.requirePersona(this.selectedPersonaId));
  }

  /**
   * 将用户人格绑定到指定作用域，后续可通过作用域解析出对应的人格。
   * 调用方（如聊天管理器）在特定聊天或角色需要固定使用某人格时调用。
   * @param scope 绑定作用域（如 chat、character）。
   * @param scopeId 作用域下的具体对象标识。
   * @param personaId 要绑定的用户人格标识。
   * @returns 创建的绑定记录副本。
   */
  bindPersona(
    scope: string,
    scopeId: string,
    personaId: string,
  ): PersonaBindingRecord {
    this.requirePersona(personaId);
    const binding: PersonaBindingRecord = {
      scope: scope,
      scopeId: scopeId,
      personaId: personaId,
      updatedAt: Date.now(),
    };
    this.bindings.set(
      this.bindingKey(scope, scopeId),
      this.cloneBinding(binding),
    );
    return this.cloneBinding(binding);
  }

  /**
   * 按作用域读取绑定的用户人格记录，未找到绑定时抛出异常。
   * 调用方在需要获取特定作用域下关联的用户人格时使用。
   * @param scope 绑定作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @returns 绑定的用户人格记录副本。
   */
  getBoundPersona(scope: string, scopeId: string): PersonaRecord {
    const binding = this.bindings.get(this.bindingKey(scope, scopeId));
    if (binding === undefined) {
      throw new Error(`Persona binding not found: ${scope}/${scopeId}`);
    }
    return this.clonePersona(this.requirePersona(binding.personaId));
  }

  /**
   * 根据用户人格构建 Prompt 所需的摘要数据。
   * 调用方（如 PromptRuntime 的 buildPrompt）在组装系统提示时调用，
   * 用于将用户人格信息注入到 Prompt 中。
   * @param personaId 目标用户人格标识。
   * @returns 用户人格 Prompt 摘要数据。
   */
  buildPromptData(personaId: string): PersonaPromptData {
    const persona = this.requirePersona(personaId);
    const data: PersonaPromptData = {
      personaId: persona.id,
      name: persona.name,
      description: persona.description,
      avatarRef: persona.avatarRef,
      lorebookId: persona.lorebookId,
      promptInjectionStrategy: persona.promptInjectionStrategy,
      userMacroValue: persona.userMacroValue,
      tags: persona.tags.slice(),
    };
    return data;
  }

  /**
   * 按作用域构建 Prompt 所需的用户人格摘要数据，无绑定时回退到当前选中人格。
   * 调用方（如 PromptRuntime）在按聊天/角色获取用户人格时调用，优先使用绑定，无绑定则使用全局选中。
   * @param scope 绑定作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @returns 用户人格 Prompt 摘要数据。
   */
  buildPromptDataForScope(
    scope: string,
    scopeId: string,
  ): PersonaPromptData {
    const binding = this.bindings.get(this.bindingKey(scope, scopeId));
    if (binding !== undefined) {
      return this.buildPromptData(binding.personaId);
    }
    if (this.selectedPersonaId.length > 0) {
      return this.buildPromptData(this.selectedPersonaId);
    }
    throw new Error(`Persona not selected or bound: ${scope}/${scopeId}`);
  }

  /**
   * 导出指定用户人格，用于备份或与外部工具互通。
   * @param personaId 目标用户人格标识。
   * @returns 用户人格导出数据。
   */
  exportPersona(personaId: string): PersonaExportData {
    const persona = this.clonePersona(this.requirePersona(personaId));
    const data: PersonaExportData = {
      persona: persona,
    };
    return data;
  }

  /**
   * 从外部数据导入用户人格，分配新的 ID 并写入内存。
   * 调用方在从备份恢复或迁移人格时使用。
   * @param data 导入的用户人格数据。
   * @param newId 导入后使用的新标识，避免与现有人格 ID 冲突。
   * @returns 导入后的用户人格记录副本。
   */
  importPersona(data: PersonaExportData, newId: string): PersonaRecord {
    if (this.personas.has(newId)) {
      throw new Error(`Persona already exists: ${newId}`);
    }
    const persona = this.clonePersona(data.persona);
    persona.id = newId;
    persona.updatedAt = Date.now();
    this.personas.set(persona.id, this.clonePersona(persona));
    this.publishUpdated('persona.imported', persona);
    return this.clonePersona(persona);
  }

  /**
   * 将创建参数转换为用户人格持久化记录，补充 updatedAt 时间戳。
   * @param params 创建参数。
   * @param updatedAt 更新时间戳。
   */
  private toRecord(
    params: PersonaCreateParams,
    updatedAt: number,
  ): PersonaRecord {
    const persona: PersonaRecord = {
      id: params.id,
      name: params.name,
      description: params.description,
      avatarRef: params.avatarRef,
      tags: params.tags.slice(),
      lorebookId: params.lorebookId,
      promptInjectionStrategy: params.promptInjectionStrategy,
      userMacroValue: params.userMacroValue,
      enabled: params.enabled,
      updatedAt: updatedAt,
    };
    return persona;
  }

  /**
   * 按 ID 查找用户人格，不存在时抛出异常。
   * 由 getPersona、updatePersona、deletePersona、selectPersona、bindPersona、buildPromptData 等内部调用。
   * @param personaId 目标用户人格标识。
   * @returns 匹配的用户人格记录引用。
   */
  private requirePersona(personaId: string): PersonaRecord {
    const persona = this.personas.get(personaId);
    if (persona === undefined) {
      throw new Error(`Persona not found: ${personaId}`);
    }
    return persona;
  }

  private requireFiles(): TavernFileStore {
    if (this.files === undefined) {
      throw new Error('PersonaRuntime storage is not configured.');
    }
    return this.files;
  }

  private storagePath(): string {
    return `${this.rootPath}/users/${safePathSegment(this.userId, 'default')}/personas/index.json`;
  }

  private defaultStorageSnapshot(): PersonaStorageSnapshot {
    return {
      schemaVersion: 1,
      personas: new Array<PersonaRecord>(),
      bindings: new Array<PersonaBindingRecord>(),
      selectedPersonaId: '',
    };
  }

  /**
   * 深拷贝 PersonaRecord。
   */
  private clonePersona(persona: PersonaRecord): PersonaRecord {
    const cloned: PersonaRecord = {
      id: persona.id,
      name: persona.name,
      description: persona.description,
      avatarRef: persona.avatarRef,
      tags: persona.tags.slice(),
      lorebookId: persona.lorebookId,
      promptInjectionStrategy: persona.promptInjectionStrategy,
      userMacroValue: persona.userMacroValue,
      enabled: persona.enabled,
      updatedAt: persona.updatedAt,
    };
    return cloned;
  }

  private clonePersonas(
    personas: Array<PersonaRecord>,
  ): Array<PersonaRecord> {
    const cloned = new Array<PersonaRecord>();
    for (let index = 0; index < personas.length; index += 1) {
      cloned.push(this.clonePersona(personas[index]));
    }
    return cloned;
  }

  /**
   * 深拷贝 PersonaBindingRecord。
   */
  private cloneBinding(binding: PersonaBindingRecord): PersonaBindingRecord {
    return {
      scope: binding.scope,
      scopeId: binding.scopeId,
      personaId: binding.personaId,
      updatedAt: binding.updatedAt,
    };
  }

  private cloneBindings(
    bindings: Array<PersonaBindingRecord>,
  ): Array<PersonaBindingRecord> {
    const cloned = new Array<PersonaBindingRecord>();
    for (let index = 0; index < bindings.length; index += 1) {
      cloned.push(this.cloneBinding(bindings[index]));
    }
    return cloned;
  }

  /**
   * 删除与指定用户人格相关的所有绑定记录。
   * 在 deletePersona 中调用，确保人格删除后其绑定关系也被清理。
   * @param personaId 用户人格标识。
   */
  private removeBindingsForPersona(personaId: string): void {
    const keys = Array.from(this.bindings.keys());
    for (let index = 0; index < keys.length; index += 1) {
      const binding = this.bindings.get(keys[index]);
      if (binding !== undefined && binding.personaId === personaId) {
        this.bindings.delete(keys[index]);
      }
    }
  }

  /**
   * 生成绑定记录键：scope:scopeId。
   * 用于 bindings Map 的键生成。
   */
  private bindingKey(scope: string, scopeId: string): string {
    return `${scope}:${scopeId}`;
  }

  /**
   * 发布用户人格事件，携带人格记录副本。
   * 在 createPersona、updatePersona、importPersona 中调用。
   * @param eventName 事件名称。
   * @param persona 关联的用户人格记录。
   */
  private publishUpdated(eventName: string, persona: PersonaRecord): void {
    const payloadPersona = this.clonePersona(persona);
    const payload: PersonaUpdatedPayload = {
      persona: payloadPersona,
    };
    this.events.publish<PersonaUpdatedPayload>(eventName, payload);
  }
}
