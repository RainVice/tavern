import { EventBus } from '../runtime/EventBus';
import type { LogitBiasEntry, SamplerExportData, SamplerParams, SamplerPreset, SamplerPresetSavedPayload } from './SamplerModels';

/**
 * 提供采样参数相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 在对话生成流程中由 ProviderRuntime 调用以获取采样参数，由 UI 层调用以管理预设。
 */
export class SamplerRuntime {
  private events: EventBus; private presets: Map<string,SamplerPreset>=new Map(); private counter=0;
  /**
   * 初始化当前运行时实例，绑定事件总线以支持预设保存事件的发布。
   * @param events 事件总线实例，用于在预设被保存或更新时发布 "sampler.preset.saved" 事件。
   */
  constructor(events: EventBus) { this.events=events; }

  /**
   * 返回一组默认的采样参数，适用于未自定义调参时的起始配置。
   * 在用户从未保存过预设的情况下，由 UI 层或 ProviderRuntime 首次调用以获取初始参数集。
   */
  defaultParams(): SamplerParams {
    return { temperature:1.0, top_p:0.9, top_k:40, repetition_penalty:1.1, frequency_penalty:0, presence_penalty:0, min_p:0.05, typical_p:1.0, cfg_scale:1.0, seed:-1 };
  }

  /**
   * 保存一个新的采样参数预设，写入内部索引并发布保存事件。
   * 当用户在 UI 中创建或保存预设时调用此方法，宿主可监听 "sampler.preset.saved" 事件同步状态。
   * @param name 预设的名称标识，由用户在 UI 中输入，用于在预设列表中展示区分。
   * @param params 采样参数集合，包含 temperature、top_p 等核心调参项，由 UI 中采样参数调整控件收集。
   * @param logitBias logit 偏置条目列表，用于微调特定 token 的生成概率，由 UI 中 logit bias 编辑器提供。
   * @returns 新创建的预设对象副本，外部修改不会影响内部状态。宿主可将其用于 UI 展示或持久化。
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
   * 按预设 ID 查找已有的采样预设，若不存在则抛出异常。
   * 由 UI 或 ProviderRuntime 调用以获取特定预设的详细参数，用于恢复上次选择或发送 API 请求前获取参数。
   * @param presetId 要查找的预设唯一标识，由 savePreset 或从持久化存储恢复时生成。
   * @returns 匹配到的预设对象副本。
   */
  getPreset(presetId: string): SamplerPreset {
    const p=this.presets.get(presetId); if (p===undefined) throw new Error(`采样器预设未找到: ${presetId}`); return this.copyPreset(p);
  }

  /**
   * 返回所有已保存的采样参数预设列表。
   * 由 UI 层在初始化预设选择器或刷新列表时调用，展示用户可选的预设参数组合。
   * @returns 预设对象数组副本，外部修改不影响内部索引。
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
   * 删除指定的采样参数预设，并清理内部索引。
   * 当用户在 UI 中删除预设时调用，调用前应由 caller 确认该预设未被其他模块引用。
   * @param presetId 要删除的预设唯一标识。
   */
  deletePreset(presetId: string): void { this.getPreset(presetId); this.presets.delete(presetId); }

  /**
   * 将 logit bias 条目列表序列化为 JSON 字符串格式，供 API 请求使用。
   * 由 ProviderRuntime 在构建 LLM API 请求体时调用，将内部 LogitBiasEntry 列表转换为目标 API 可识别的 logit_bias 参数格式。
   * @param bias logit bias 条目数组，每个条目包含 token 文本及其偏置值，来源于预设中保存的 logitBias 列表。
   * @returns 格式化的 JSON 字符串，如 {"token1":-1.0,"token2":2.0}，直接嵌入 API 请求体。
   */
  buildLogitBiasJson(bias: Array<LogitBiasEntry>): string {
    const parts=new Array<string>();
    for (let i=0;i<bias.length;i++) { parts.push(`"${this.escapeJsonString(bias[i].token)}":${bias[i].bias}`); }
    return `{${parts.join(',')}}`;
  }

  /**
   * 将指定的 CFG 缩放系数应用到采样参数副本中，确保 scale 值不低于 1.0。
   * 由 ProviderRuntime 在发送特定需要 CFG 能力的 API 请求（如 instruct 模式）前调用，
   * 返回一个新的 SamplerParams 副本以避免修改原始预设。
   * @param params 原始采样参数，该方法不会修改此对象，用于从中复制除 cfg_scale 外的其他采样值。
   * @param scale 要应用的 CFG 缩放系数，将使用 Math.max(1.0, scale) 截断以确保值有效。
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
   * 由宿主在触发导出操作时调用（如用户点击导出按钮），收集所有预设为可持久化格式。
   * @returns 可持久化或可传输的导出内容，包含所有预设的副本列表。
   */
  exportData(): SamplerExportData { return { presets: this.listPresets() }; }

  /**
   * 从外部数据导入采样参数预设列表，替换或合并到当前运行时。
   * 由宿主在触发导入操作时调用（如用户选择导入文件），data 来自 exportData() 的输出。
   * 导入后内部 counter 会根据已存在的预设 ID 自动推进，避免新预设 ID 冲突。
   * @param data 包含预设列表的导出数据对象，通常来自 exportData() 的输出。
   */
  importData(data: SamplerExportData): void {
    for (let i=0;i<data.presets.length;i++) {
      const preset = this.copyPreset(data.presets[i]);
      this.presets.set(preset.presetId, preset);
      this.counter = Math.max(this.counter, this.parseCounter(preset.presetId));
    }
  }

  /**
   * 深拷贝一个预设对象，防止外部代码意外修改内部状态。
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
   * 深拷贝采样参数对象，防止外部修改影响内部状态。
   * @param params 要拷贝的原始采样参数对象。
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
   * 深拷贝 logit bias 条目数组，防止外部修改影响内部状态。
   * @param logitBias 要拷贝的原始 logit bias 条目数组。
   * @returns 新的 logit bias 条目数组副本。
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
   * 从预设 ID 中解析出自增计数器的数值，用于恢复正确的计数状态。
   * @param presetId 预设 ID 字符串，格式为 "sampler-{数字}"。
   * @returns 解析出的数值；若格式不符则返回 0。
   */
  private parseCounter(presetId: string): number {
    if (!presetId.startsWith('sampler-')) {
      return 0;
    }
    const parsed = Number(presetId.substring(8));
    return parsed > 0 ? parsed : 0;
  }

  /**
   * 对字符串中的特殊字符（反斜杠、引号、换行符等）进行 JSON 转义。
   * @param value 需要转义的原始字符串。
   * @returns 转义后的安全 JSON 字符串。
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
