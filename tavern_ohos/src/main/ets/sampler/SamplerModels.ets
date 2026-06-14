/**
 * 描述调用采样参数能力时需要传入的参数。
 */
export interface SamplerParams {
  /**
   * 温度采样值。
   */
  temperature: number;
  /**
   * top_p 采样值。
   */
  top_p: number;
  /**
   * top_k 采样值。
   */
  top_k: number;
  /**
   * repetition penalty 值，由当前实例内部维护。
   */
  repetition_penalty: number;
  /**
   * frequency penalty 值，由当前实例内部维护。
   */
  frequency_penalty: number;
  /**
   * presence penalty 值，由当前实例内部维护。
   */
  presence_penalty: number;
  /**
   * min_p 采样值。
   */
  min_p: number;
  /**
   * typical_p 采样值。
   */
  typical_p: number;
  /**
   * cfg scale 值，由当前实例内部维护。
   */
  cfg_scale: number;
  /**
   * 随机种子。
   */
  seed: number;
}
/**
 * 描述采样参数持久化或内存索引中的一条记录。
 */
export interface LogitBiasEntry {
  /**
   * token 文本。
   */
  token: string;
  /**
   * 偏置值。
   */
  bias: number;
}
/**
 * 描述采样参数模块在运行时交换的数据结构。
 */
export interface SamplerPreset {
  /**
   * 预设标识。
   */
  presetId: string;
  /**
   * 名称。
   */
  name: string;
  /**
   * 采样参数。
   */
  params: SamplerParams;
  /**
   * logit bias 列表。
   */
  logitBias: Array<LogitBiasEntry>;
  /**
   * created At 值，由当前实例内部维护。
   */
  createdAt: number;
  /**
   * updated At 值，由当前实例内部维护。
   */
  updatedAt: number;
}
/**
 * 描述采样参数事件发布时携带的数据结构。
 */
export interface SamplerPresetSavedPayload {
  /**
   * 预设数据。
   */
  preset: SamplerPreset;
}
/**
 * 描述采样参数模块在运行时交换的数据结构。
 */
export interface SamplerExportData {
  /**
   * 预设列表。
   */
  presets: Array<SamplerPreset>;
}
