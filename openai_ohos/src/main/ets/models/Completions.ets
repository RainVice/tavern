import type { CompletionUsage, JsonObject, Metadata, OpenAIModel } from './Common';

/**
 * 旧式 Completions 模型 ID。
 *
 * API：`POST /v1/completions`。
 * 说明：这是 legacy 文本补全接口；新文本生成优先使用 Responses API 或 Chat Completions。
 */
export type CompletionModel = OpenAIModel | 'gpt-3.5-turbo-instruct' | 'davinci-002' | 'babbage-002';

/**
 * 创建 Completion 请求。
 *
 * API：`POST /v1/completions`。
 * 说明：保留旧式 prompt -> text completion 的输入输出模型，便于 batch 和旧项目兼容。
 */
export interface CompletionCreateParams {
  /**
   * 模型 ID。
   *
   * API：Completions。
   * 说明：旧式 completion 模型，例如 `gpt-3.5-turbo-instruct`。
   */
  model: CompletionModel;

  /**
   * prompt。
   *
   * API：Completions。
   * 说明：可传单条 prompt、多条 prompt、token 数组或多条 token 数组。
   */
  prompt?: string | Array<string> | Array<number> | Array<Array<number>> | null;

  /**
   * 最佳候选数量。
   *
   * API：Completions。
   * 说明：服务端生成多个候选后返回分数最高的若干个，成本会增加。
   */
  best_of?: number | null;

  /**
   * echo prompt。
   *
   * API：Completions。
   * 说明：开启后响应文本会包含输入 prompt。
   */
  echo?: boolean | null;

  /**
   * 频率惩罚。
   *
   * API：Completions。
   * 说明：降低重复 token 出现概率。
   */
  frequency_penalty?: number | null;

  /**
   * logit bias。
   *
   * API：Completions。
   * 说明：按 token ID 调整生成概率。
   */
  logit_bias?: Record<string, number> | null;

  /**
   * 是否返回 logprobs。
   *
   * API：Completions。
   * 说明：返回 token 对数概率信息。
   */
  logprobs?: number | null;

  /**
   * 最大生成 token。
   *
   * API：Completions。
   * 说明：限制输出长度。
   */
  max_tokens?: number | null;

  /**
   * 元数据。
   *
   * API：Completions。
   * 说明：用于业务侧跟踪。
   */
  metadata?: Metadata | null;

  /**
   * 返回候选数量。
   *
   * API：Completions。
   * 说明：每条 prompt 返回几个 completion。
   */
  n?: number | null;

  /**
   * 存在惩罚。
   *
   * API：Completions。
   * 说明：鼓励模型引入未出现过的主题。
   */
  presence_penalty?: number | null;

  /**
   * 随机种子。
   *
   * API：Completions。
   * 说明：用于尽量复现实验输出。
   */
  seed?: number | null;

  /**
   * 停止序列。
   *
   * API：Completions。
   * 说明：模型遇到这些字符串时停止生成。
   */
  stop?: string | Array<string> | null;

  /**
   * 是否流式返回。
   *
   * API：Completions。
   * 说明：开启后返回 completion chunk 流。
   */
  stream?: boolean | null;

  /**
   * 采样温度。
   *
   * API：Completions。
   * 说明：值越高越随机。
   */
  temperature?: number | null;

  /**
   * nucleus sampling 参数。
   *
   * API：Completions。
   * 说明：通常不要与 `temperature` 同时大幅调整。
   */
  top_p?: number | null;

  /**
   * 终端用户标识。
   *
   * API：Completions。
   * 说明：用于滥用检测。
   */
  user?: string;
}

/**
 * Completion 候选。
 *
 * API：Completions 响应。
 * 说明：表示一个生成结果。
 */
export interface CompletionChoice {
  /**
   * 生成文本。
   *
   * API：Completions 响应。
   * 说明：模型补全出的文本。
   */
  text: string;

  /**
   * 候选索引。
   *
   * API：Completions 响应。
   * 说明：从 0 开始。
   */
  index: number;

  /**
   * 停止原因。
   *
   * API：Completions 响应。
   * 说明：例如 `stop`、`length`、`content_filter`。
   */
  finish_reason: 'stop' | 'length' | 'content_filter';

  /**
   * logprob 信息。
   *
   * API：Completions 响应。
   * 说明：请求 `logprobs` 时返回；核心层用 JSON object 保留。
   */
  logprobs?: JsonObject | null;
}

/**
 * Completion 响应。
 *
 * API：`POST /v1/completions`。
 * 说明：旧式文本补全响应。
 */
export interface Completion {
  /**
   * Completion ID。
   *
   * API：Completions 响应。
   * 说明：本次 completion 的唯一标识。
   */
  id: string;

  /**
   * 对象类型。
   *
   * API：Completions 响应。
   * 说明：固定为 `text_completion`。
   */
  object: 'text_completion';

  /**
   * 创建时间。
   *
   * API：Completions 响应。
   * 说明：Unix 秒级时间戳。
   */
  created: number;

  /**
   * 模型 ID。
   *
   * API：Completions 响应。
   * 说明：实际使用的模型。
   */
  model: string;

  /**
   * 候选列表。
   *
   * API：Completions 响应。
   * 说明：由请求参数 `n` 和 prompt 数量决定。
   */
  choices: Array<CompletionChoice>;

  /**
   * token 用量。
   *
   * API：Completions 响应。
   * 说明：用于成本统计。
   */
  usage?: CompletionUsage;
}
