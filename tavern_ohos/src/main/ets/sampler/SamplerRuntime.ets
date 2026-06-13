import { EventBus } from '../runtime/EventBus';
import type { LogitBiasEntry, SamplerExportData, SamplerParams, SamplerPreset, SamplerPresetSavedPayload } from './SamplerModels';

/**
 * 提供采样参数相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class SamplerRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus; private presets: Map<string,SamplerPreset>=new Map(); private counter=0;
  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) { this.events=events; }

  /**
   * 执行 defaultParams 的内部处理步骤，供当前模块复用。
   */
  defaultParams(): SamplerParams {
    return { temperature:1.0, top_p:0.9, top_k:40, repetition_penalty:1.1, frequency_penalty:0, presence_penalty:0, min_p:0.05, typical_p:1.0, cfg_scale:1.0, seed:-1 };
  }

  /**
   * 创建或写入预设，完成持久化后返回可供调用方使用的结果。
   * @param name 显示名称或注册名称。
   * @param params 创建、更新或执行操作所需的参数对象。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 读取指定预设，不存在时抛出错误。
   * @param presetId 目标预设标识。
   * @returns 更新或读取后的记录副本。
   */
  getPreset(presetId: string): SamplerPreset {
    const p=this.presets.get(presetId); if (p===undefined) throw new Error(`采样器预设未找到: ${presetId}`); return this.copyPreset(p);
  }

  /**
   * 读取Presets列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listPresets(): Array<SamplerPreset> {
    const result = new Array<SamplerPreset>();
    const values = Array.from(this.presets.values());
    for (let index = 0; index < values.length; index += 1) {
      result.push(this.copyPreset(values[index]));
    }
    return result;
  }

  /**
   * 删除指定预设，并清理相关索引或资源引用。
   * @param presetId 目标预设标识。
   */
  deletePreset(presetId: string): void { this.getPreset(presetId); this.presets.delete(presetId); }

  /**
   * 根据入参构建Logit Bias JSON 字符串，仅生成数据结构，不直接执行外部请求。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  buildLogitBiasJson(bias: Array<LogitBiasEntry>): string {
    const parts=new Array<string>();
    for (let i=0;i<bias.length;i++) { parts.push(`"${this.escapeJsonString(bias[i].token)}":${bias[i].bias}`); }
    return `{${parts.join(',')}}`;
  }

  /**
   * 执行 applyCfgScale 的内部处理步骤，供当前模块复用。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
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

  /**
   * 导出数据，用于备份、迁移或与 SillyTavern 数据互通。
   * @returns 可持久化或可传输的导出内容。
   */
  exportData(): SamplerExportData { return { presets: this.listPresets() }; }

  /**
   * 从外部数据导入Data 值，转换为当前运行时的数据结构。
   * @param data 导入或恢复使用的序列化数据。
   */
  importData(data: SamplerExportData): void {
    for (let i=0;i<data.presets.length;i++) {
      const preset = this.copyPreset(data.presets[i]);
      this.presets.set(preset.presetId, preset);
      this.counter = Math.max(this.counter, this.parseCounter(preset.presetId));
    }
  }

  /**
   * 复制Preset 值，避免外部修改内部状态。
   */
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

  /**
   * 复制Params 列表，避免外部修改内部状态。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
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

  /**
   * 复制Logit Bias 列表，避免外部修改内部状态。

   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
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

  /**
   * 解析Counter，非法输入会返回失败标记或空结果。
   * @param presetId 目标预设标识。
   */
  private parseCounter(presetId: string): number {
    if (!presetId.startsWith('sampler-')) {
      return 0;
    }
    const parsed = Number(presetId.substring(8));
    return parsed > 0 ? parsed : 0;
  }

  /**
   * 规范化JSONString，确保后续存储、比较或展示行为稳定。
   * @param value 要保存或比较的字段值。
   */
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
