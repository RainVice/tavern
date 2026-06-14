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
   * 重复惩罚系数，抑制已生成 token 的再次出现，值越大惩罚越强。
   */
  repetition_penalty: number;
  /**
   * 频率惩罚系数，根据 token 出现频率降低其再次生成的权重。
   */
  frequency_penalty: number;
  /**
   * 存在惩罚系数，对已出现的 token 施加固定惩罚，促进话题多样性。
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
   * 分类器自由引导（CFG）尺度，控制模型对给定提示的遵从程度。
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
 * 描述采样参数预设的完整数据结构，包含标识、参数和创建/更新时间。
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
   * 预设的创建时间戳（毫秒），由创建流程自动记录。
   */
  createdAt: number;
  /**
   * 预设的最后更新时间戳（毫秒），由更新流程自动记录。
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
 * 描述采样参数导出时携带的数据结构，用于备份、迁移或数据互通。
 */
export interface SamplerExportData {
  /**
   * 预设列表。
   */
  presets: Array<SamplerPreset>;
}
