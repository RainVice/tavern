import { EventBus } from '../runtime/EventBus';
import type { LogitBiasEntry, SamplerExportData, SamplerParams, SamplerPreset, SamplerPresetSavedPayload } from './SamplerModels';

export class SamplerRuntime {
  private events: EventBus; private presets: Map<string,SamplerPreset>=new Map(); private counter=0;
  constructor(events: EventBus) { this.events=events; }

  defaultParams(): SamplerParams {
    return { temperature:1.0, top_p:0.9, top_k:40, repetition_penalty:1.1, frequency_penalty:0, presence_penalty:0, min_p:0.05, typical_p:1.0, cfg_scale:1.0, seed:-1 };
  }

  savePreset(name: string, params: SamplerParams, logitBias: Array<LogitBiasEntry>): SamplerPreset {
    this.counter+=1; const presetId=`sampler-${this.counter}`; const now=Date.now();
    const preset: SamplerPreset = {
      presetId: presetId,
      name: name,
      params: this.copyParams(params),
      logitBias: this.copyLogitBias(logitBias),
      createdAt: now,
      updatedAt: now,
    };
    this.presets.set(presetId, this.copyPreset(preset));
    this.events.publish<SamplerPresetSavedPayload>('sampler.preset.saved', { preset: this.copyPreset(preset) });
    return this.copyPreset(preset);
  }

  getPreset(presetId: string): SamplerPreset {
    const p=this.presets.get(presetId); if (p===undefined) throw new Error(`采样器预设未找到: ${presetId}`); return this.copyPreset(p);
  }

  listPresets(): Array<SamplerPreset> {
    const result = new Array<SamplerPreset>();
    const values = Array.from(this.presets.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyPreset(values[index]));
    }
    return result;
  }

  deletePreset(presetId: string): void { this.getPreset(presetId); this.presets.delete(presetId); }

  buildLogitBiasJson(bias: Array<LogitBiasEntry>): string {
    const parts=new Array<string>();
    for (let i=0;i<bias.length;i++) { parts.push(`"${this.escapeJsonString(bias[i].token)}":${bias[i].bias}`); }
    return `{${parts.join(',')}}`;
  }

  applyCfgScale(params: SamplerParams, scale: number): SamplerParams {
    const p: SamplerParams = {
      temperature: params.temperature,
      top_p: params.top_p,
      top_k: params.top_k,
      repetition_penalty: params.repetition_penalty,
      frequency_penalty: params.frequency_penalty,
      presence_penalty: params.presence_penalty,
      min_p: params.min_p,
      typical_p: params.typical_p,
      cfg_scale: Math.max(1.0, scale),
      seed: params.seed,
    };
    return p;
  }

  exportData(): SamplerExportData { return { presets: this.listPresets() }; }

  importData(data: SamplerExportData): void {
    for (let i=0;i<data.presets.length;i++) {
      const preset = this.copyPreset(data.presets[i]);
      this.presets.set(preset.presetId, preset);
      this.counter = Math.max(this.counter, this.parseCounter(preset.presetId));
    }
  }

  private copyPreset(preset: SamplerPreset): SamplerPreset {
    return {
      presetId: preset.presetId,
      name: preset.name,
      params: this.copyParams(preset.params),
      logitBias: this.copyLogitBias(preset.logitBias),
      createdAt: preset.createdAt,
      updatedAt: preset.updatedAt,
    };
  }

  private copyParams(params: SamplerParams): SamplerParams {
    return {
      temperature: params.temperature,
      top_p: params.top_p,
      top_k: params.top_k,
      repetition_penalty: params.repetition_penalty,
      frequency_penalty: params.frequency_penalty,
      presence_penalty: params.presence_penalty,
      min_p: params.min_p,
      typical_p: params.typical_p,
      cfg_scale: params.cfg_scale,
      seed: params.seed,
    };
  }

  private copyLogitBias(logitBias: Array<LogitBiasEntry>): Array<LogitBiasEntry> {
    const result = new Array<LogitBiasEntry>();
    for (let index = 0; index < logitBias.length; index += 1) {
      result.push({
        token: logitBias[index].token,
        bias: logitBias[index].bias,
      });
    }
    return result;
  }

  private parseCounter(presetId: string): number {
    if (!presetId.startsWith('sampler-')) {
      return 0;
    }
    const parsed = Number(presetId.substring(8));
    return parsed > 0 ? parsed : 0;
  }

  private escapeJsonString(value: string): string {
    let output = '';
    for (let index = 0; index < value.length; index += 1) {
      const ch = value.substring(index, index + 1);
      if (ch === '\\') {
        output += '\\\\';
      } else if (ch === '"') {
        output += '\\"';
      } else if (ch === '\n') {
        output += '\\n';
      } else if (ch === '\r') {
        output += '\\r';
      } else if (ch === '\t') {
        output += '\\t';
      } else {
        output += ch;
      }
    }
    return output;
  }
}
