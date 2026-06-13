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
 */
export class PersonaRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 文件存储适配器；未传入时仅使用内存态。
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
   * personas 列表，由当前实例内部维护。
   */
  private personas: Map<string, PersonaRecord> = new Map<string, PersonaRecord>();
  /**
   * bindings 列表，由当前实例内部维护。
   */
  private bindings: Map<string, PersonaBindingRecord> = new Map<string, PersonaBindingRecord>();
  /**
   * selected Persona 标识。
   */
  private selectedPersonaId: string = '';

  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
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
   * 创建新的用户人格记录，写入存储并返回副本。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
   */
  createPersona(params: PersonaCreateParams): PersonaRecord {
    const persona = this.toRecord(params, Date.now());
    this.personas.set(persona.id, this.clonePersona(persona));
    this.publishUpdated('persona.created', persona);
    return this.clonePersona(persona);
  }

  /**
   * 更新指定Persona，写回存储并按需发布变更事件。
   * @param personaId 目标用户人格标识。
   * @param params 创建、更新或执行操作所需的参数对象。
   * @returns 更新或读取后的记录副本。
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
   * 读取指定Persona，不存在时抛出错误。
   * @param personaId 目标用户人格标识。
   * @returns 更新或读取后的记录副本。
   */
  getPersona(personaId: string): PersonaRecord {
    return this.clonePersona(this.requirePersona(personaId));
  }

  /**
   * 读取Personas列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
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
   * 删除指定Persona，并清理相关索引或资源引用。
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
   * 读取或解析Persona，调用方应处理不存在或不匹配的情况。
   * @param personaId 目标用户人格标识。
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
   * 读取指定SelectedPersona，不存在时抛出错误。
   * @returns 更新或读取后的记录副本。
   */
  getSelectedPersona(): PersonaRecord {
    return this.clonePersona(this.requirePersona(this.selectedPersonaId));
  }

  /**
   * 把用户人格对象绑定到指定作用域，后续读取会按该绑定解析。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @param personaId 目标用户人格标识。
   */
  bindPersona(scope: string, scopeId: string, personaId: string): PersonaBindingRecord {
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
   * 读取指定BoundPersona，不存在时抛出错误。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @returns 更新或读取后的记录副本。
   */
  getBoundPersona(scope: string, scopeId: string): PersonaRecord {
    const binding = this.bindings.get(this.bindingKey(scope, scopeId));
    if (binding === undefined) {
      throw new Error(`Persona binding not found: ${scope}/${scopeId}`);
    }
    return this.clonePersona(this.requirePersona(binding.personaId));
  }

  /**
   * 根据入参构建Prompt Data 值，仅生成数据结构，不直接执行外部请求。
   * @param personaId 目标用户人格标识。
   * @returns 构建好的请求、Prompt 或中间数据。
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
   * 根据入参构建Prompt Data For Scope 值，仅生成数据结构，不直接执行外部请求。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   * @returns 构建好的请求、Prompt 或中间数据。
   */
  buildPromptDataForScope(scope: string, scopeId: string): PersonaPromptData {
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
   * 导出用户人格，用于备份、迁移或与 SillyTavern 数据互通。
   * @param personaId 目标用户人格标识。
   * @returns 可持久化或可传输的导出内容。
   */
  exportPersona(personaId: string): PersonaExportData {
    const persona = this.clonePersona(this.requirePersona(personaId));
    const data: PersonaExportData = {
      persona: persona,
    };
    return data;
  }

  /**
   * 从外部数据导入Persona 值，转换为当前运行时的数据结构。
   * @param data 导入或恢复使用的序列化数据。
   * @param newId 目标新记录标识。
   * @returns 更新或读取后的记录副本。
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
   * 把创建参数规范化为用户人格记录。
   * @param params 创建、更新或执行操作所需的参数对象。
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
   * 读取必须存在的Persona 值，缺失时抛出错误。
   * @param personaId 目标用户人格标识。
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
   * 复制Persona 值，避免外部修改内部状态。
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
   * 复制Binding 值，避免外部修改内部状态。
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
   * 移除用户人格绑定，用于解除注册、绑定或索引关系。
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
   * 把用户人格对象绑定到指定作用域，后续读取会按该绑定解析。
   * @param scope 绑定或查询使用的作用域。
   * @param scopeId 作用域下的具体对象标识。
   */
  private bindingKey(scope: string, scopeId: string): string {
    return `${scope}:${scopeId}`;
  }

  /**
   * 发布用户人格事件，把状态变化通知给宿主或其他 Runtime。
   * @param eventName 要订阅或发布的事件名。

   */
  private publishUpdated(eventName: string, persona: PersonaRecord): void {
    const payloadPersona = this.clonePersona(persona);
    const payload: PersonaUpdatedPayload = {
      persona: payloadPersona,
    };
    this.events.publish<PersonaUpdatedPayload>(eventName, payload);
  }
}
