import { EventBus } from '../runtime/EventBus';
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

export class PersonaRuntime {
  private events: EventBus;
  private personas: Map<string, PersonaRecord> = new Map<string, PersonaRecord>();
  private bindings: Map<string, PersonaBindingRecord> = new Map<string, PersonaBindingRecord>();
  private selectedPersonaId: string = '';

  constructor(events: EventBus) {
    this.events = events;
  }

  createPersona(params: PersonaCreateParams): PersonaRecord {
    const persona = this.toRecord(params, Date.now());
    this.personas.set(persona.id, this.clonePersona(persona));
    this.publishUpdated('persona.created', persona);
    return this.clonePersona(persona);
  }

  updatePersona(personaId: string, params: PersonaCreateParams): PersonaRecord {
    this.requirePersona(personaId);
    const persona = this.toRecord(params, Date.now());
    persona.id = personaId;
    this.personas.set(persona.id, this.clonePersona(persona));
    this.publishUpdated('persona.updated', persona);
    return this.clonePersona(persona);
  }

  getPersona(personaId: string): PersonaRecord {
    return this.clonePersona(this.requirePersona(personaId));
  }

  listPersonas(): Array<PersonaRecord> {
    const result = new Array<PersonaRecord>();
    const values = Array.from(this.personas.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.clonePersona(values[index]));
    }
    return result;
  }

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

  selectPersona(personaId: string): PersonaRecord {
    const persona = this.requirePersona(personaId);
    const previous = this.selectedPersonaId;
    this.selectedPersonaId = personaId;
    const payload: PersonaChangedPayload = {
      persona: this.clonePersona(persona),
      previousPersonaId: previous,
    };
    this.events.publish<PersonaChangedPayload>('persona.changed', payload);
    return this.clonePersona(persona);
  }

  getSelectedPersona(): PersonaRecord {
    return this.clonePersona(this.requirePersona(this.selectedPersonaId));
  }

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

  getBoundPersona(scope: string, scopeId: string): PersonaRecord {
    const binding = this.bindings.get(this.bindingKey(scope, scopeId));
    if (binding === undefined) {
      throw new Error(`Persona binding not found: ${scope}/${scopeId}`);
    }
    return this.clonePersona(this.requirePersona(binding.personaId));
  }

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

  exportPersona(personaId: string): PersonaExportData {
    const data: PersonaExportData = {
      persona: this.clonePersona(this.requirePersona(personaId)),
    };
    return data;
  }

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

  private requirePersona(personaId: string): PersonaRecord {
    const persona = this.personas.get(personaId);
    if (persona === undefined) {
      throw new Error(`Persona not found: ${personaId}`);
    }
    return persona;
  }

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

  private cloneBinding(binding: PersonaBindingRecord): PersonaBindingRecord {
    return {
      scope: binding.scope,
      scopeId: binding.scopeId,
      personaId: binding.personaId,
      updatedAt: binding.updatedAt,
    };
  }

  private removeBindingsForPersona(personaId: string): void {
    const keys = Array.from(this.bindings.keys());
    for (let index = 0; index < keys.length; index += 1) {
      const binding = this.bindings.get(keys[index]);
      if (binding !== undefined && binding.personaId === personaId) {
        this.bindings.delete(keys[index]);
      }
    }
  }

  private bindingKey(scope: string, scopeId: string): string {
    return `${scope}:${scopeId}`;
  }

  private publishUpdated(eventName: string, persona: PersonaRecord): void {
    const payload: PersonaUpdatedPayload = {
      persona: this.clonePersona(persona),
    };
    this.events.publish<PersonaUpdatedPayload>(eventName, payload);
  }
}
