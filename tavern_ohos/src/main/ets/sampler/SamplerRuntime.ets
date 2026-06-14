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
   * 返回采样参数的默认值集合。
   * @returns 包含各采样参数默认值的 SamplerParams 对象。
   */
  defaultParams(): SamplerParams {
    return { temperature:1.0, top_p:0.9, top_k:40, repetition_penalty:1.1, frequency_penalty:0, presence_penalty:0, min_p:0.05, typical_p:1.0, cfg_scale:1.0, seed:-1 };
  }

  /**
   * 创建或更新采样参数预设。新预设写入内部 Map，并发布保存事件。
   * @param name 预设名称。
   * @param params 采样参数。
   * @param logitBias logit bias 列表。
   * @returns 已保存的 SamplerPreset 副本。
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
   * 根据 presetId 读取指定预设。
   * @param presetId 目标预设标识。
   * @returns 预设的副本，调用方可安全读取。
   */
  getPreset(presetId: string): SamplerPreset {
    const p=this.presets.get(presetId); if (p===undefined) throw new Error(`采样器预设未找到: ${presetId}`); return this.copyPreset(p);
  }

  /**
   * 返回所有已保存预设的副本列表。
   * @returns 预设副本数组，调用方修改返回值不会直接影响内部状态。
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
   * 删除指定预设。
   * @param presetId 目标预设标识。
   */
  deletePreset(presetId: string): void { this.getPreset(presetId); this.presets.delete(presetId); }

  /**
   * 根据 logit bias 列表构建 JSON 字符串，用于 API 请求载荷。
   * @param bias logit bias 条目列表。
   * @returns 格式化的 JSON 字符串，如 {"token1":-1.0,"token2":2.0}。
   */
  buildLogitBiasJson(bias: Array<LogitBiasEntry>): string {
    const parts=new Array<string>();
    for (let i=0;i<bias.length;i++) { parts.push(`"${this.escapeJsonString(bias[i].token)}":${bias[i].bias}`); }
    return `{${parts.join(',')}}`;
  }

  /**
   * 对采样参数应用 cfg_scale 值，返回新的 SamplerParams 对象。
   * @param params 原始采样参数。
   * @param scale cfg_scale 值（将被限制为 >= 1.0）。
   * @returns 应用 cfg_scale 后的新 SamplerParams。
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
   * 导出所有预设数据，用于备份、迁移或与 SillyTavern 数据互通。
   * @returns 包含全部预设的导出数据结构。
   */
  exportData(): SamplerExportData { return { presets: this.listPresets() }; }

  /**
   * 从外部数据结构导入预设，合并到当前运行时内部状态。
   * @param data 待导入的导出数据。
   */
  importData(data: SamplerExportData): void {
    for (let i=0;i<data.presets.length;i++) {
      const preset = this.copyPreset(data.presets[i]);
      this.presets.set(preset.presetId, preset);
      this.counter = Math.max(this.counter, this.parseCounter(preset.presetId));
    }
  }

  /**
   * 深拷贝 SamplerPreset 对象。
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
   * 深拷贝 SamplerParams 对象。
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
   * 深拷贝 LogitBiasEntry 数组。
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
   * 从预设标识中解析计数器数值，用于生成下一个预设 ID。
   * @param presetId 预设标识字符串，格式为 "sampler-{数字}"。
   * @returns 解析出的数值，非法格式返回 0。
   */
  private parseCounter(presetId: string): number {
    if (!presetId.startsWith('sampler-')) {
      return 0;
    }
    const parsed = Number(presetId.substring(8));
    return parsed > 0 ? parsed : 0;
  }

  /**
   * 对字符串中的特殊字符进行 JSON 转义处理。
   * @param value 原始字符串。
   * @returns 转义后的安全 JSON 字符串片段。
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
