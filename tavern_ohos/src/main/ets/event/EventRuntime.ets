import { EventBus } from '../runtime/EventBus';
import type { RuntimeEvent } from '../runtime/EventBus';
import type {
  EventCatalogEntry,
  EventCatalogPayload,
  RuntimeSignalPayload,
  ServerStartedPayload,
} from './EventModels';

export class EventRuntime {
  private events: EventBus;
  private catalog: Map<string, EventCatalogEntry> = new Map<string, EventCatalogEntry>();
  private upstreamMap: Map<string, string> = new Map<string, string>();

  constructor(events: EventBus) {
    this.events = events;
    this.registerDefaultCatalog();
  }

  emitServerStarted(source: string): RuntimeEvent<ServerStartedPayload> {
    const payload: ServerStartedPayload = {
      source: source,
    };
    return this.events.publish<ServerStartedPayload>('server-started', payload);
  }

  emitRuntimeSignal(signal: string, detail: string): RuntimeEvent<RuntimeSignalPayload> {
    const payload: RuntimeSignalPayload = {
      signal: signal,
      detail: detail,
    };
    return this.events.publish<RuntimeSignalPayload>('runtime.signal', payload);
  }

  listCatalog(): Array<EventCatalogEntry> {
    const entries = Array.from(this.catalog.values());
    const result = new Array<EventCatalogEntry>();
    for (let index = 0; index < entries.length; index += 1) {
      result.push(this.cloneCatalogEntry(entries[index]));
    }
    result.sort((left: EventCatalogEntry, right: EventCatalogEntry) => left.name.localeCompare(right.name));
    return result;
  }

  requireCatalogEntry(name: string): EventCatalogEntry {
    const entry = this.catalog.get(name);
    if (entry === undefined) {
      throw new Error(`Runtime event not registered: ${name}`);
    }
    return this.cloneCatalogEntry(entry);
  }

  mapUpstreamEventName(upstreamName: string): string {
    const mapped = this.upstreamMap.get(upstreamName);
    if (mapped === undefined) {
      return upstreamName;
    }
    return mapped;
  }

  publishCatalogEvent(name: string, detail: string): RuntimeEvent<EventCatalogPayload> {
    const payload: EventCatalogPayload = {
      entry: this.requireCatalogEntry(name),
      detail: detail,
    };
    return this.events.publish<EventCatalogPayload>('event.catalog.published', payload);
  }

  private registerDefaultCatalog(): void {
    this.registerCatalogEntry('app.ready', 'app_ready', 'app', ['runtimeVersion', 'userId'], true, true);
    this.registerCatalogEntry('app.initialized', 'app_initialized', 'app', ['runtimeVersion', 'userId'], true, true);
    this.registerCatalogEntry('chat.loaded', 'chatLoaded', 'chat', ['chatId'], true, true);
    this.registerCatalogEntry('chat.changed', 'chat_id_changed', 'chat', ['chatId'], true, true);
    this.registerCatalogEntry('message.added', 'message_received', 'message', ['chatId', 'messageId'], true, true);
    this.registerCatalogEntry('message.sent', 'message_sent', 'message', ['chatId', 'messageId'], true, true);
    this.registerCatalogEntry('message.updated', 'message_updated', 'message', ['chatId', 'messageId'], true, true);
    this.registerCatalogEntry('character.updated', 'character_edited', 'character', ['characterId', 'changes'], true, true);
    this.registerCatalogEntry('generation.started', 'generation_started', 'generation', ['taskId', 'chatId'], true, true);
    this.registerCatalogEntry('generation.ended', 'generation_ended', 'generation', ['taskId', 'chatId'], true, true);
    this.registerCatalogEntry('stream.delta', 'stream_token_received', 'stream', ['taskId', 'messageId', 'delta', 'snapshot'], true, true);
    this.registerCatalogEntry('settings.changed', 'settings_updated', 'settings', ['scope', 'key', 'oldValue', 'newValue'], true, true);
    this.registerCatalogEntry('secret.rotated', 'secret_rotated', 'secret', ['secretRef', 'providerId'], true, false);
    this.registerCatalogEntry('worldinfo.activated', 'world_info_activated', 'worldinfo', ['entries', 'matches'], true, true);
  }

  private registerCatalogEntry(
    name: string,
    upstreamName: string,
    domain: string,
    payloadFields: Array<string>,
    pluginVisible: boolean,
    uiVisible: boolean,
  ): void {
    const entry: EventCatalogEntry = {
      name: name,
      upstreamName: upstreamName,
      domain: domain,
      payloadFields: payloadFields.slice(),
      pluginVisible: pluginVisible,
      uiVisible: uiVisible,
    };
    this.catalog.set(name, entry);
    this.upstreamMap.set(upstreamName, name);
  }

  private cloneCatalogEntry(entry: EventCatalogEntry): EventCatalogEntry {
    return {
      name: entry.name,
      upstreamName: entry.upstreamName,
      domain: entry.domain,
      payloadFields: entry.payloadFields.slice(),
      pluginVisible: entry.pluginVisible,
      uiVisible: entry.uiVisible,
    };
  }
}
