/**
 * 描述调用采样参数能力时需要传入的参数。
 * 用于在模型生成对话回复时控制输出文本的随机性、多样性和重复抑制策略。
 */
export interface SamplerParams {
  /**
   * 温度采样值，控制生成文本的随机程度。值越低输出越确定且重复性高，值越高输出越多样但可能偏离主题。
   * 用于在 LLM API 调用中调整概率分布的 softmax 温度。
   */
  temperature: number;
  /**
   * top_p 采样值（核采样），按累计概率从高到低选择 token，直到概率总和超过该值。
   * 用于动态缩小采样范围，剔除尾部低概率 token，temperature 配合使用。
   */
  top_p: number;
  /**
   * top_k 采样值，仅保留概率最高的 k 个 token 供模型选择，其余全部过滤。
   * 用于进一步限制输出词汇表，提高生成内容的相关性和可控性。
   */
  top_k: number;
  /**
   * 重复惩罚系数，用于抑制已生成 token 的重复出现。值大于 1.0 时对已出现 token 的概率进行惩罚，
   * 值越高惩罚越强。用于在对话生成中减少重复语句、提升多样性。
   */
  repetition_penalty: number;
  /**
   * 频率惩罚系数，按 token 在已生成文本中出现的频次降低其权重，出现次数越多降权越重。
   * 用于在长文本生成中防止高频词汇过度重复。
   */
  frequency_penalty: number;
  /**
   * 存在惩罚系数，对所有已在生成文本中出现过的 token 整体降权，不区分出现频次。
   * 用于鼓励模型引入新词汇和话题，避免困在相同表达模式中。
   */
  presence_penalty: number;
  /**
   * min_p 采样值，动态保留概率不低于（最大概率 * min_p）的所有 token。
   * 用于在低 temperature 场景下提供更灵活的候选集，避免过度截断。
   */
  min_p: number;
  /**
   * typical_p 采样值（典型采样），根据 token 的信息量（负对数概率与熵的接近程度）筛选候选 token。
   * 用于保留最"典型"的 token，在自然度和创造性之间取得平衡。
   */
  typical_p: number;
  /**
   * CFG（Classifier-Free Guidance）缩放系数，控制模型对提示条件的遵从程度。
   * 用于在条件生成中放大或缩小条件信号的影响，值越大输出越紧密遵循条件提示。
   */
  cfg_scale: number;
  /**
   * 随机种子，用于控制生成过程的随机性。设置为固定值时每次生成结果可复现，
   * 为 -1 或默认值时使用随机种子。用于调试和需要可复现结果的场景。
   */
  seed: number;
}
/**
 * 描述采样参数持久化或内存索引中的一条记录。
 * 用于定义对特定 token 的生成概率正向或负向调整，在 API 请求中通过 logit_bias 参数传入。
 */
export interface LogitBiasEntry {
  /**
   * token 文本，表示要调整的 token 的具体字符串形式。
   * 在构建 API logit_bias 请求参数时作为 key 使用。
   */
  token: string;
  /**
   * 偏置值，正数增加该 token 出现的概率，负数降低。绝对值越大影响越显著。
   * 用于在 logit_bias 中为该 token 设置偏移量，影响模型在该位置选择该 token 的倾向。
   */
  bias: number;
}
/**
 * 描述采样参数模块在运行时交换的数据结构。
 * 用于在 UI 配置和 LLM API 调用之间传递完整的预设参数集合，包含采样参数和 logit bias 列表。
 */
export interface SamplerPreset {
  /**
   * 预设标识，格式如 "sampler-{数字}"，在内存索引中作为唯一键存储，用于后续的查找、更新和删除操作。
   */
  presetId: string;
  /**
   * 名称，由用户在 UI 中定义，用于在预设选择列表中区分不同参数组合。
   */
  name: string;
  /**
   * 采样参数集合，包含 temperature、top_p 等核心调参项。
   * 在发送 LLM API 请求时提取并映射为对应 API 的采样参数字段。
   */
  params: SamplerParams;
  /**
   * logit bias 列表，用于微调特定 token 的生成概率。
   * 在构建 API 请求时序列化为 JSON 格式的 logit_bias 参数发送给模型。
   */
  logitBias: Array<LogitBiasEntry>;
  /**
   * 预设创建时的时间戳（毫秒），用于在管理界面按创建时间排序或显示。
   */
  createdAt: number;
  /**
   * 预设最近一次更新的时间戳（毫秒），用于在管理界面标识最近修改的预设。
   */
  updatedAt: number;
}
/**
 * 描述采样参数事件发布时携带的数据结构。
 * 当用户保存或更新采样参数预设时，通过事件总线发送给宿主或其他 Runtime 模块。
 */
export interface SamplerPresetSavedPayload {
  /**
   * 被保存的预设对象副本，包含完整的采样参数和 logit bias 信息。
   * 宿主接收此事件后可触发 UI 刷新或持久化存储。
   */
  preset: SamplerPreset;
}
/**
 * 描述采样参数模块在运行时交换的数据结构。
 * 用于数据导出（备份/迁移/SillyTavern 互通），包含所有已保存的预设列表。
 */
export interface SamplerExportData {
  /**
   * 预设列表，包含所有已保存的 SamplerPreset 对象。
   * 在 exportData() 中收集并返回，供 importData() 恢复使用。
   */
  presets: Array<SamplerPreset>;
}
