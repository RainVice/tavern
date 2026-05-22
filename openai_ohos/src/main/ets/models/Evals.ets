import type { CursorPageParams, JsonObject, Metadata, OpenAIListResponse } from './Common';

/**
 * Evals API model。
 *
 * API：`/v1/evals`。
 * 说明：创建、运行和读取评测任务。
 */

/** Eval run 状态。API：Eval Runs。说明：表示运行生命周期。 */
export type EvalRunStatus = 'queued' | 'in_progress' | 'failed' | 'completed' | 'canceled';

/** Eval output item 状态。API：Eval Run Output Items。说明：表示单条评测结果通过或失败。 */
export type EvalRunOutputItemStatus = 'pass' | 'failed' | string;

/** Eval 数据源配置。API：Create Eval。说明：定义评测数据 schema。 */
export interface EvalDataSourceConfig {
  /** 类型。API：Create Eval。说明：例如 `custom`。 */
  type: string;
  /** 其他配置。API：Create Eval。说明：保留官方扩展字段。 */
  schema?: JsonObject;
}

/** Grader 基础结构。API：Graders/Evals/Fine-tuning。说明：所有 grader 都包含名称和类型。 */
export interface EvalGraderBase {
  /** Grader 名称。API：Graders。说明：用于在结果和多 grader 公式里识别该 grader。 */
  name: string;
}

/** String check grader。API：Graders。说明：按字符串比较返回 0 或 1。 */
export interface EvalStringCheckGrader extends EvalGraderBase {
  /** 类型。API：Graders。说明：固定为 `string_check`。 */
  type: 'string_check';
  /** 输入文本。API：Graders。说明：可包含 `{{sample.output_text}}` 等模板变量。 */
  input: string;
  /** 参考文本。API：Graders。说明：可包含 `{{item.label}}` 等模板变量。 */
  reference: string;
  /** 比较操作。API：Graders。说明：`eq` 精确相等，`ne/neq` 不等，`like/ilike` 包含匹配。 */
  operation: 'eq' | 'ne' | 'neq' | 'like' | 'ilike';
}

/** Text similarity grader。API：Graders。说明：用文本相似度指标给输出打分。 */
export interface EvalTextSimilarityGrader extends EvalGraderBase {
  /** 类型。API：Graders。说明：固定为 `text_similarity`。 */
  type: 'text_similarity';
  /** 输入文本。API：Graders。说明：待评分的模型输出或模板文本。 */
  input: string;
  /** 参考文本。API：Graders。说明：用于对比的标准答案或模板文本。 */
  reference: string;
  /** 相似度指标。API：Graders。说明：例如 `fuzzy_match`、`bleu`、`rouge_l`。 */
  evaluation_metric: 'cosine' | 'fuzzy_match' | 'bleu' | 'gleu' | 'meteor' | 'rouge_1' | 'rouge_2' |
    'rouge_3' | 'rouge_4' | 'rouge_5' | 'rouge_l' | string;
}

/** Grader 内容项。API：Score/Label model grader。说明：模型 grader 的多模态输入块。 */
export interface EvalGraderContentItem {
  /** 内容类型。API：Graders。说明：文本、输出文本、图像或音频输入。 */
  type: 'input_text' | 'output_text' | 'input_image' | 'input_audio' | string;
  /** 文本内容。API：Graders。说明：用于 `input_text` 或 `output_text`。 */
  text?: string;
  /** 图片 URL。API：Graders。说明：用于 `input_image`。 */
  image_url?: string;
  /** 图像细节。API：Graders。说明：用于 `input_image`。 */
  detail?: 'low' | 'high' | 'auto';
  /** 音频输入。API：Graders。说明：用于 `input_audio`，包含 base64 数据和格式。 */
  input_audio?: JsonObject;
}

/** Grader message。API：Score/Label model grader。说明：传给评分模型的消息。 */
export interface EvalGraderMessage {
  /** 消息角色。API：Graders。说明：developer/system/user/assistant。 */
  role: 'user' | 'assistant' | 'system' | 'developer';
  /** 消息类型。API：Graders。说明：通常为 `message`。 */
  type?: 'message';
  /** 消息内容。API：Graders。说明：可传字符串或多模态内容数组。 */
  content: string | Array<EvalGraderContentItem>;
}

/** Score model grader。API：Graders。说明：用模型输出 0 到 1 或指定 range 内的分数。 */
export interface EvalScoreModelGrader extends EvalGraderBase {
  /** 类型。API：Graders。说明：固定为 `score_model`。 */
  type: 'score_model';
  /** 评分输入。API：Graders。说明：发给评分模型的消息列表。 */
  input: Array<EvalGraderMessage>;
  /** 评分模型。API：Graders。说明：用于打分的模型 ID。 */
  model: string;
  /** 分数范围。API：Graders。说明：默认通常为 `[0, 1]`。 */
  range?: Array<number>;
  /** 采样参数。API：Graders。说明：例如 temperature、top_p、seed、reasoning_effort。 */
  sampling_params?: JsonObject;
  /** 通过阈值。API：Graders。说明：高于该分数可视为通过。 */
  pass_threshold?: number;
}

/** Label model grader。API：Graders。说明：用模型从候选标签中选择结果。 */
export interface EvalLabelModelGrader extends EvalGraderBase {
  /** 类型。API：Graders。说明：固定为 `label_model`。 */
  type: 'label_model';
  /** 分类输入。API：Graders。说明：发给分类模型的消息列表。 */
  input: Array<EvalGraderMessage>;
  /** 分类模型。API：Graders。说明：必须支持结构化输出。 */
  model: string;
  /** 候选标签。API：Graders。说明：模型只能从这些标签中选择。 */
  labels: Array<string>;
  /** 通过标签。API：Graders。说明：这些标签表示样本通过。 */
  passing_labels: Array<string>;
}

/** Python grader。API：Graders。说明：运行 Python 脚本计算分数。 */
export interface EvalPythonGrader extends EvalGraderBase {
  /** 类型。API：Graders。说明：固定为 `python`。 */
  type: 'python';
  /** Python 源码。API：Graders。说明：定义评分函数或脚本。 */
  source: string;
  /** 镜像标签。API：Graders。说明：可选 Python 执行环境标签。 */
  image_tag?: string;
}

/** Multi grader。API：Graders。说明：组合多个 grader 并用表达式计算总分。 */
export interface EvalMultiGrader extends EvalGraderBase {
  /** 类型。API：Graders。说明：固定为 `multi`。 */
  type: 'multi';
  /** 子 grader 字典。API：Graders。说明：key 可在 `calculate_output` 中引用。 */
  graders: Record<string, JsonObject>;
  /** 总分表达式。API：Graders。说明：例如 `0.5 * a + 0.5 * b`。 */
  calculate_output: string;
}

/** Eval grader/criterion。API：Create Eval/Fine-tuning RFT。说明：定义评测标准或 RFT 奖励函数。 */
export type EvalGrader = EvalStringCheckGrader | EvalTextSimilarityGrader | EvalScoreModelGrader |
  EvalLabelModelGrader | EvalPythonGrader | EvalMultiGrader;

/** Eval grader/criterion。API：Create Eval。说明：兼容旧命名。 */
export type EvalTestingCriterion = EvalGrader;

/** 创建 Eval 参数。API：`POST /v1/evals`。说明：创建评测结构。 */
export interface EvalCreateParams {
  /** 名称。API：Create Eval。说明：评测名称。 */
  name: string;
  /** 数据源配置。API：Create Eval。说明：定义每条评测数据的结构。 */
  data_source_config: EvalDataSourceConfig;
  /** 评测标准。API：Create Eval。说明：一组 grader。 */
  testing_criteria: Array<EvalTestingCriterion>;
  /** 元数据。API：Create Eval。说明：开发者自定义键值对。 */
  metadata?: Metadata;
}

/** 更新 Eval 参数。API：`POST /v1/evals/{eval_id}`。说明：更新名称、metadata 等。 */
export interface EvalUpdateParams {
  /** 名称。API：Update Eval。说明：新的评测名称。 */
  name?: string;
  /** 元数据。API：Update Eval。说明：替换自定义键值对。 */
  metadata?: Metadata;
}

/** Eval 对象。API：Create/Retrieve/List Eval。说明：表示一个评测定义。 */
export interface EvalObject {
  /** Eval ID。API：Evals。说明：创建 run 时引用。 */
  id: string;
  /** 对象类型。API：Evals。说明：通常为 `eval`。 */
  object: string;
  /** 名称。API：Evals。说明：评测名称。 */
  name: string;
  /** 创建时间。API：Evals。说明：Unix 秒级时间戳。 */
  created_at?: number;
  /** 更新时间。API：Evals。说明：Unix 秒级时间戳。 */
  updated_at?: number;
  /** 数据源配置。API：Evals。说明：评测数据 schema。 */
  data_source_config: EvalDataSourceConfig;
  /** 评测标准。API：Evals。说明：grader 列表。 */
  testing_criteria: Array<EvalTestingCriterion>;
  /** 元数据。API：Evals。说明：开发者自定义键值对。 */
  metadata?: Metadata | null;
}

/** Eval 列表参数。API：List Evals。说明：支持分页和排序字段。 */
export interface EvalListParams extends CursorPageParams {
  /** 排序字段。API：List Evals。说明：created_at 或 updated_at。 */
  order_by?: 'created_at' | 'updated_at';
}

/** Eval 列表响应。API：List Evals。说明：列表元素为 EvalObject。 */
export type EvalListResponse = OpenAIListResponse<EvalObject>;

/** 删除 Eval 响应。API：Delete Eval。说明：表示删除结果。 */
export interface EvalDeleted {
  /** 对象类型。API：Delete Eval。说明：固定类似 `eval.deleted`。 */
  object: string;
  /** 删除结果。API：Delete Eval。说明：true 表示已删除。 */
  deleted: boolean;
  /** Eval ID。API：Delete Eval。说明：被删除的评测 ID。 */
  eval_id: string;
}

/** Eval JSONL file source。API：Create Eval Run。说明：从已上传 JSONL 文件读取评测数据。 */
export interface EvalJsonlFileIdSource {
  /** 类型。API：Create Eval Run。说明：固定 `file_id`。 */
  type: 'file_id';
  /** 文件 ID。API：Create Eval Run。说明：JSONL 文件 ID。 */
  id: string;
}

/** Eval run 数据源。API：Create Eval Run。说明：定义本次运行读取的数据。 */
export interface EvalRunDataSource {
  /** 类型。API：Create Eval Run。说明：例如 `jsonl`、`completions`。 */
  type: string;
  /** 来源。API：Create Eval Run。说明：例如 file_id source。 */
  source?: EvalJsonlFileIdSource;
  /** 模型。API：Create Eval Run。说明：completions 数据源可按模型过滤。 */
  model?: string;
  /** 其他配置。API：Create Eval Run。说明：保留官方扩展字段。 */
  config?: JsonObject;
}

/** 创建 Eval Run 参数。API：`POST /v1/evals/{eval_id}/runs`。说明：启动一次评测运行。 */
export interface EvalRunCreateParams {
  /** 名称。API：Create Eval Run。说明：本次运行名称。 */
  name?: string;
  /** 数据源。API：Create Eval Run。说明：本次运行输入数据。 */
  data_source: EvalRunDataSource;
  /** 元数据。API：Create Eval Run。说明：开发者自定义键值对。 */
  metadata?: Metadata;
}

/** Eval Run 对象。API：Create/Retrieve/List Eval Run。说明：表示一次评测执行。 */
export interface EvalRun {
  /** Run ID。API：Eval Runs。说明：读取 output items 时引用。 */
  id: string;
  /** 对象类型。API：Eval Runs。说明：固定类似 `eval.run`。 */
  object: string;
  /** Eval ID。API：Eval Runs。说明：所属评测 ID。 */
  eval_id: string;
  /** 名称。API：Eval Runs。说明：运行名称。 */
  name?: string;
  /** 状态。API：Eval Runs。说明：queued、completed 等。 */
  status: EvalRunStatus;
  /** 创建时间。API：Eval Runs。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 数据源。API：Eval Runs。说明：实际使用的数据源。 */
  data_source: EvalRunDataSource;
  /** 元数据。API：Eval Runs。说明：开发者自定义键值对。 */
  metadata?: Metadata | null;
}

/** Eval Run 列表参数。API：List Eval Runs。说明：支持状态过滤和分页。 */
export interface EvalRunListParams extends CursorPageParams {
  /** 状态过滤。API：List Eval Runs。说明：只返回指定状态的 run。 */
  status?: EvalRunStatus;
}

/** Eval Run 列表响应。API：List Eval Runs。说明：列表元素为 EvalRun。 */
export type EvalRunListResponse = OpenAIListResponse<EvalRun>;

/** 删除 Eval Run 响应。API：Delete Eval Run。说明：表示删除结果。 */
export interface EvalRunDeleted {
  /** 对象类型。API：Delete Eval Run。说明：固定类似 `eval.run.deleted`。 */
  object: string;
  /** 删除结果。API：Delete Eval Run。说明：true 表示已删除。 */
  deleted: boolean;
  /** Run ID。API：Delete Eval Run。说明：被删除的 run ID。 */
  run_id: string;
}

/** Eval output item grader result。API：Eval Run Output Items。说明：单个 grader 的结果。 */
export interface EvalRunOutputItemResult {
  /** 名称。API：Eval Run Output Items。说明：grader 名称。 */
  name: string;
  /** 是否通过。API：Eval Run Output Items。说明：grader 判断结果。 */
  passed?: boolean;
  /** 分数。API：Eval Run Output Items。说明：grader 数值分。 */
  score?: number;
  /** 类型。API：Eval Run Output Items。说明：grader 类型。 */
  type?: string;
}

/** Eval Run Output Item。API：Eval Run Output Items。说明：一次 run 中单条样本输出和评分。 */
export interface EvalRunOutputItem {
  /** Output item ID。API：Eval Run Output Items。说明：输出项 ID。 */
  id: string;
  /** 对象类型。API：Eval Run Output Items。说明：固定 `eval.run.output_item`。 */
  object: 'eval.run.output_item';
  /** Run ID。API：Eval Run Output Items。说明：所属 run ID。 */
  run_id: string;
  /** Eval ID。API：Eval Run Output Items。说明：所属 eval ID。 */
  eval_id: string;
  /** 创建时间。API：Eval Run Output Items。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 状态。API：Eval Run Output Items。说明：pass 或 failed。 */
  status: EvalRunOutputItemStatus;
  /** 数据项 ID。API：Eval Run Output Items。说明：数据源中的 item 序号。 */
  datasource_item_id: number;
  /** Grader 结果。API：Eval Run Output Items。说明：每个 grader 的评分。 */
  results: Array<EvalRunOutputItemResult>;
  /** 样本。API：Eval Run Output Items。说明：模型输入输出摘要。 */
  sample?: JsonObject;
  /** 数据源项。API：Eval Run Output Items。说明：原始输入数据。 */
  datasource_item?: JsonObject;
}

/** Eval Run Output Item 列表参数。API：List output items。说明：支持状态过滤和分页。 */
export interface EvalRunOutputItemListParams extends CursorPageParams {
  /** 状态过滤。API：List output items。说明：pass 或 failed。 */
  status?: EvalRunOutputItemStatus;
}

/** Eval Run Output Item 列表响应。API：List output items。说明：列表元素为 output item。 */
export type EvalRunOutputItemListResponse = OpenAIListResponse<EvalRunOutputItem>;
