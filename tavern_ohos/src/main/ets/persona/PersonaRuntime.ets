import { EventBus } from '../runtime/EventBus';
import type { TavernScope } from '../contracts/PublicContracts';
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
 */
export class PersonaRuntime {
  /**
   * 事件总线实例，用于发布人格变更、切换、删除等事件。
   */
  private events: EventBus;
  /**
   * 文件存储适配器。未传入时仅维持内存状态，loadFromStore/saveToStore 调用会抛出错误。
   */
  private files: TavernFileStore | undefined = undefined;
  /**
   * 数据根路径。
   */
  private rootPath: string = 'tavern-data';
  /**
   * 用户标识。
   */
  private userId: string = 'default';
  /**
   * 人格记录映射表，以 personaId 为键维护所有已注册人格的内存索引。
   */
  private personas: Map<string, PersonaRecord> = new Map<string, PersonaRecord>();
  /**
   * 人格绑定关系映射表，键为 "scope:scopeId"，维护人格与作用域的绑定索引。
   */
  private bindings: Map<string, PersonaBindingRecord> = new Map<string, PersonaBindingRecord>();
  /**
   * selected Persona 标识。
   */
  private selectedPersonaId: string = '';

  /**
   * 初始化运行时实例，包括事件总线、文件存储和路径配置。
   * @param events 事件总线实例，用于发布人格变更、切换、删除等事件。
   * @param files 可选的文件存储适配器；未传入时仅维持内存状态。
   * @param rootPath 数据在文件存储中的根路径。
   * @param userId 当前用户标识，用于隔离不同用户的数据文件。
   */
  constructor(events: EventBus, files?: TavernFileStore, rootPath: string = 'tavern-data', userId: string = 'default') {
    this.events = events;
    this.files = files;
    this.rootPath = rootPath;
    this.userId = userId;
  }

  /**
   * 从 SDK 内部文件存储恢复用户人格、选中状态和绑定关系。
   */
  async loadFromStore(): Promise<void> {
    const store = new JsonStore<PersonaStorageSnapshot>(this.requireFiles(), this.storagePath());
    const snapshot = await store.read(this.defaultStorageSnapshot());
    this.personas.clear();
    this.bindings.clear();
    for (let index = 0; index < snapshot.personas.length; index += 1) {
      const persona = this.clonePersona(snapshot.personas[index]);
      this.personas.set(persona.id, persona);
    }
    for (let index = 0; index < snapshot.bindings.length; index += 1) {
      const binding = this.cloneBinding(snapshot.bindings[index]);
      this.bindings.set(this.bindingKey(binding.scope, binding.scopeId), binding);
    }
    this.selectedPersonaId = snapshot.selectedPersonaId;
  }

  /**
   * 把当前用户人格、选中状态和绑定关系写入 SDK 内部文件存储。
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
    await new JsonStore<PersonaStorageSnapshot>(this.requireFiles(), this.storagePath()).write(snapshot);
  }

  /**
   * 创建新的用户人格记录，并入内存索引并发布 persona.created 事件。
   * 注意：该方法不自动写入文件存储，需调用方自行调用 saveToStore 持久化。
   * @param params 创建用户人格所需的参数。
   * @returns 新建记录的一份不可变副本。
   */
  createPersona(params: PersonaCreateParams): PersonaRecord {
    const persona = this.toRecord(params, Date.now());
    this.personas.set(persona.id, this.clonePersona(persona));
    this.publishUpdated('persona.created', persona);
    return this.clonePersona(persona);
  }

  /**
   * 更新指定用户人格的全部字段，并入内存索引并发布 persona.updated 事件。
   * 注意：该方法不自动写入文件存储，需调用方自行调用 saveToStore 持久化。
   * @param personaId 目标用户人格标识。
   * @param params 新的用户人格参数，会整体替换原有字段。
   * @returns 更新后记录的一份不可变副本。
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
   * 读取指定用户人格记录。记录不存在时抛出错误。
   * @param personaId 目标用户人格标识。
   * @returns 记录的一份不可变副本。
   */
  getPersona(personaId: string): PersonaRecord {
    return this.clonePersona(this.requirePersona(personaId));
  }

  /**
   * 读取全部用户人格记录列表。返回全量副本，调用方修改返回值不会影响内部状态。
   * @returns 全部用户人格记录的不可变副本列表。
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
   * 删除指定用户人格记录，同时清理相关的绑定关系和选中状态，并发布 persona.deleted 事件。
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
   * 将指定用户人格设为当前选中状态，并发布 persona.changed 事件。
   * 选中状态存储在内存中，持久化需调用 saveToStore。
   * @param personaId 目标用户人格标识。
   * @returns 选中记录的一份不可变副本。
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
   * 读取当前选中的用户人格记录。未选中时抛出错误。
   * @returns 当前选中记录的一份不可变副本。
   */
  getSelectedPersona(): PersonaRecord {
    return this.clonePersona(this.requirePersona(this.selectedPersonaId));
  }

  /**
   * 将用户人格绑定到指定作用域。绑定关系存储在内存中，持久化需调用 saveToStore。
   * 同一 (scope, scopeId) 的旧绑定会被覆盖。
   * @param scope 作用域类型。
   * @param scopeId 作用域下的具体对象标识。
   * @param personaId 要绑定的用户人格标识。
   * @returns 新建绑定记录的一份不可变副本。
   */
  bindPersona(scope: TavernScope, scopeId: string, personaId: string): PersonaBindingRecord {
    this.requirePersona(personaId);
    const binding: PersonaBindingRecord = {
      scope: scope,
      scopeId: scopeId,
      personaId: personaId,
      updatedAt: Date.now(),
    };
    this.bindings.set(this.bindingKey(scope, scopeId), this.cloneBinding(binding));
    return this.cloneBinding(binding);
  }

  /**
   * 读取指定作用域绑定的用户人格记录。未找到绑定时抛出错误。
   * @param scope 作用域类型。
   * @param scopeId 作用域下的具体对象标识。
   * @returns 绑定人格记录的一份不可变副本。
   */
  getBoundPersona(scope: TavernScope, scopeId: string): PersonaRecord {
    const binding = this.bindings.get(this.bindingKey(scope, scopeId));
    if (binding === undefined) {
      throw new Error(`Persona binding not found: ${scope}/${scopeId}`);
    }
    return this.clonePersona(this.requirePersona(binding.personaId));
  }

  /**
   * 根据用户人格标识构建 Prompt 数据。仅组装数据结构，不涉及网络或外部请求。
   * @param personaId 目标用户人格标识。
   * @returns 用于拼入 Prompt 的用户人格数据。
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
   * 根据作用域构建 Prompt 数据。优先使用绑定的人格，无绑定时回退到当前选中人格。
   * 两者均不存在时抛出错误。
   * @param scope 作用域类型。
   * @param scopeId 作用域下的具体对象标识。
   * @returns 用于拼入 Prompt 的用户人格数据。
   */
  buildPromptDataForScope(scope: TavernScope, scopeId: string): PersonaPromptData {
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
   * 导出指定用户人格的全部数据，用于备份或跨实例迁移。
   * @param personaId 目标用户人格标识。
   * @returns 包含完整人格记录的可序列化数据。
   */
  exportPersona(personaId: string): PersonaExportData {
    const persona = this.clonePersona(this.requirePersona(personaId));
    const data: PersonaExportData = {
      persona: persona,
    };
    return data;
  }

  /**
   * 从导出数据导入用户人格记录。目标标识已存在时抛出错误。
   * 导入操作会更新时间戳并发布 persona.imported 事件。
   * @param data 用户人格导出数据。
   * @param newId 导入后使用的新标识。
   * @returns 导入后记录的一份不可变副本。
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
   * 将 PersonaCreateParams 规范化为 PersonaRecord，补充更新时间戳。
   * @param params 创建用户人格所需的参数。
   * @param updatedAt 记录更新时间戳（毫秒）。
   * @returns 规范化后的人格记录。
   */
  private toRecord(params: PersonaCreateParams, updatedAt: number): PersonaRecord {
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
   * 按标识查找用户人格记录，记录不存在时抛出错误。
   * @param personaId 目标用户人格标识。
   * @returns 内存中的原引用（非副本）。
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
   * 深拷贝 PersonaRecord，防止调用方通过返回值修改内部状态。
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

  private clonePersonas(personas: Array<PersonaRecord>): Array<PersonaRecord> {
    const cloned = new Array<PersonaRecord>();
    for (let index = 0; index < personas.length; index += 1) {
      cloned.push(this.clonePersona(personas[index]));
    }
    return cloned;
  }

  /**
   * 深拷贝 PersonaBindingRecord，防止调用方通过返回值修改内部状态。
   */
  private cloneBinding(binding: PersonaBindingRecord): PersonaBindingRecord {
    return {
      scope: binding.scope,
      scopeId: binding.scopeId,
      personaId: binding.personaId,
      updatedAt: binding.updatedAt,
    };
  }

  private cloneBindings(bindings: Array<PersonaBindingRecord>): Array<PersonaBindingRecord> {
    const cloned = new Array<PersonaBindingRecord>();
    for (let index = 0; index < bindings.length; index += 1) {
      cloned.push(this.cloneBinding(bindings[index]));
    }
    return cloned;
  }

  /**
   * 移除所有关联到指定用户人格的绑定。
   * 在删除人格时内部调用，用于清理绑定索引。
   * @param personaId 目标用户人格标识。
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
   * 生成绑定的内部缓存键。格式为 "scope:scopeId"。
   * @param scope 作用域类型。
   * @param scopeId 作用域下的具体对象标识。
   */
  private bindingKey(scope: TavernScope, scopeId: string): string {
    return `${scope}:${scopeId}`;
  }

  /**
   * 发布 PersonaUpdatedPayload 事件，将人格变更通知给宿主或其他 Runtime。
   * @param eventName 事件名称（如 persona.created、persona.updated、persona.imported）。
   */
  private publishUpdated(eventName: string, persona: PersonaRecord): void {
    const payloadPersona = this.clonePersona(persona);
    const payload: PersonaUpdatedPayload = {
      persona: payloadPersona,
    };
    this.events.publish<PersonaUpdatedPayload>(eventName, payload);
  }
}
