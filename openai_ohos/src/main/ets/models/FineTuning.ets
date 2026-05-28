import type { CursorPageParams, JsonObject, Metadata, OpenAIListResponse, OpenAIModel } from './Common';
import type { EvalGrader } from './Evals';

/**
 * Fine-tuning API model。
 *
 * API：`/v1/fine_tuning/jobs`。
 * 说明：管理微调任务、事件和 checkpoint。
 */

/** Fine-tuning job 状态。API：Fine-tuning Jobs。说明：表示微调任务生命周期。 */
export type FineTuningJobStatus =
  'validating_files' | 'queued' | 'running' | 'succeeded' | 'failed' | 'cancelled' | 'paused';

/** Fine-tuning 方法类型。API：Create Fine-tuning Job。说明：当前常见为监督微调，也预留偏好优化等方法。 */
export type FineTuningMethodType = 'supervised' | 'dpo' | 'reinforcement';

/** Fine-tuning 自动超参数。API：Create Fine-tuning Job。说明：官方支持 `auto` 让平台自动选择。 */
export type FineTuningAutoValue = 'auto';

/**
 * Fine-tuning 错误。
 *
 * API：Fine-tuning Job object。
 * 说明：任务失败时返回，用于定位训练文件、模型或额度问题。
 */
export interface FineTuningJobError {
  /** 错误代码。API：Fine-tuning Jobs。说明：机器可读错误类型。 */
  code: string;
  /** 错误消息。API：Fine-tuning Jobs。说明：开发者可读错误描述。 */
  message: string;
  /** 错误参数。API：Fine-tuning Jobs。说明：通常是 `training_file` 或 `validation_file`，也可能为空。 */
  param?: string | null;
}

/**
 * Fine-tuning 超参数。
 *
 * API：Create Fine-tuning Job、Fine-tuning Job object。
 * 说明：不同微调方法支持的字段会不同，这里覆盖常见监督微调字段。
 */
export interface FineTuningHyperparameters {
  /** epoch 数。API：Create Fine-tuning Job。说明：可传数字或 `auto`。 */
  n_epochs?: number | FineTuningAutoValue;
  /** batch size。API：Create Fine-tuning Job。说明：可传数字或 `auto`。 */
  batch_size?: number | FineTuningAutoValue;
  /** 学习率倍率。API：Create Fine-tuning Job。说明：可传数字或 `auto`。 */
  learning_rate_multiplier?: number | FineTuningAutoValue;
}

/**
 * Fine-tuning 方法配置。
 *
 * API：Create Fine-tuning Job。
 * 说明：用于声明微调方法及其专属配置。
 */
export interface FineTuningMethod {
  /** 方法类型。API：Create Fine-tuning Job。说明：例如 `supervised`。 */
  type: FineTuningMethodType;
  /** 强化微调配置。API：Create Fine-tuning Job。说明：RFT 使用 grader 对模型样本打分。 */
  reinforcement?: FineTuningReinforcementConfig;
  /** 方法配置。API：Create Fine-tuning Job。说明：按官方方法 schema 传入扩展字段。 */
  config?: JsonObject;
}

/** 强化微调配置。API：Create Fine-tuning Job。说明：配置 RFT 使用的奖励 grader。 */
export interface FineTuningReinforcementConfig {
  /** Grader。API：Create Fine-tuning Job。说明：用于给训练样本生成的模型输出打分。 */
  grader: EvalGrader;
}

/** Grader validate 参数。API：`POST /v1/fine_tuning/alpha/graders/validate`。说明：校验 grader 配置。 */
export interface FineTuningGraderValidateParams {
  /** Grader。API：Validate grader。说明：要校验的 grader 配置。 */
  grader: EvalGrader;
}

/** Grader validate 响应。API：Validate grader。说明：返回服务端规范化后的 grader。 */
export interface FineTuningGraderValidateResponse {
  /** Grader。API：Validate grader。说明：校验通过后的 grader 配置。 */
  grader: EvalGrader;
}

/** Grader run 参数。API：`POST /v1/fine_tuning/alpha/graders/run`。说明：用单条样本运行 grader。 */
export interface FineTuningGraderRunParams {
  /** Grader。API：Run grader。说明：要执行的 grader 配置。 */
  grader: EvalGrader;
  /** 模型样本。API：Run grader。说明：填充 `sample` 命名空间的模型输出文本。 */
  model_sample: string;
  /** 数据集样本。API：Run grader。说明：填充 `item` 命名空间的原始样本字段。 */
  item?: JsonObject;
}

/** Grader run 响应。API：Run grader。说明：返回分数、子分数和调试信息。 */
export interface FineTuningGraderRunResponse {
  /** 分数。API：Run grader。说明：该 grader 给出的最终 reward 或评分。 */
  reward?: number;
  /** 通过状态。API：Run grader。说明：当 grader 可判定 pass/fail 时返回。 */
  passed?: boolean;
  /** 子分数。API：Run grader。说明：multi grader 可返回每个子 grader 的分数。 */
  sub_rewards?: JsonObject;
  /** 元数据。API：Run grader。说明：服务端返回的调试或执行信息。 */
  metadata?: JsonObject;
}

/**
 * 创建 Fine-tuning Job 参数。
 *
 * API：`POST /v1/fine_tuning/jobs`。
 * 说明：提交训练文件并创建微调任务。
 */
export interface FineTuningJobCreateParams {
  /** 基础模型。API：Create Fine-tuning Job。说明：要被微调的模型 ID。 */
  model: OpenAIModel;
  /** 训练文件 ID。API：Create Fine-tuning Job。说明：必须是 purpose 为 `fine-tune` 的 JSONL 文件。 */
  training_file: string;
  /** 验证文件 ID。API：Create Fine-tuning Job。说明：可选验证集文件。 */
  validation_file?: string | null;
  /** 后缀。API：Create Fine-tuning Job。说明：用于生成更易识别的微调模型名。 */
  suffix?: string | null;
  /** seed。API：Create Fine-tuning Job。说明：控制训练可复现性。 */
  seed?: number | null;
  /** 超参数。API：Create Fine-tuning Job。说明：训练轮次、batch size、学习率等。 */
  hyperparameters?: FineTuningHyperparameters;
  /** 微调方法。API：Create Fine-tuning Job。说明：例如监督微调或偏好优化。 */
  method?: FineTuningMethod;
  /** 元数据。API：Create Fine-tuning Job。说明：开发者自定义键值对。 */
  metadata?: Metadata;
}

/**
 * Fine-tuning Job 对象。
 *
 * API：Create/Retrieve/List/Cancel Fine-tuning Job。
 * 说明：表示一个微调任务。
 */
export interface FineTuningJob {
  /** Job ID。API：Fine-tuning Jobs。说明：用于查询、取消、列出事件或 checkpoint。 */
  id: string;
  /** 对象类型。API：Fine-tuning Jobs。说明：固定为 `fine_tuning.job`。 */
  object: 'fine_tuning.job';
  /** 基础模型。API：Fine-tuning Jobs。说明：被微调的模型 ID。 */
  model: string;
  /** 创建时间。API：Fine-tuning Jobs。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 完成时间。API：Fine-tuning Jobs。说明：未完成时可能为空。 */
  finished_at?: number | null;
  /** 预计完成时间。API：Fine-tuning Jobs。说明：未运行时可能为空。 */
  estimated_finish?: number | null;
  /** 微调后模型。API：Fine-tuning Jobs。说明：任务成功后返回可调用的模型名。 */
  fine_tuned_model: string | null;
  /** 组织 ID。API：Fine-tuning Jobs。说明：创建任务的组织。 */
  organization_id: string;
  /** 结果文件。API：Fine-tuning Jobs。说明：训练结果文件 ID 列表。 */
  result_files: Array<string>;
  /** 状态。API：Fine-tuning Jobs。说明：任务当前生命周期状态。 */
  status: FineTuningJobStatus;
  /** 验证文件 ID。API：Fine-tuning Jobs。说明：未设置时为空。 */
  validation_file: string | null;
  /** 训练文件 ID。API：Fine-tuning Jobs。说明：训练数据文件。 */
  training_file: string;
  /** 超参数。API：Fine-tuning Jobs。说明：实际使用的训练参数。 */
  hyperparameters: FineTuningHyperparameters;
  /** 已训练 token 数。API：Fine-tuning Jobs。说明：任务运行后返回，未统计时为空。 */
  trained_tokens?: number | null;
  /** 错误信息。API：Fine-tuning Jobs。说明：失败时包含错误原因。 */
  error?: FineTuningJobError | null;
  /** 元数据。API：Fine-tuning Jobs。说明：开发者自定义键值对。 */
  metadata?: Metadata | null;
}

/** Fine-tuning Job 列表参数。API：List Fine-tuning Jobs。说明：支持 after、limit 和 metadata 过滤。 */
export interface FineTuningJobListParams extends CursorPageParams {
  /** 元数据过滤。API：List Fine-tuning Jobs。说明：按 metadata 查询；复杂语法由服务端解释。 */
  metadata?: Metadata | null;
}

/** Fine-tuning Job 列表响应。API：List Fine-tuning Jobs。说明：列表元素为 `FineTuningJob`。 */
export type FineTuningJobListResponse = OpenAIListResponse<FineTuningJob>;

/** Fine-tuning Job Event 日志级别。API：List Fine-tuning Events。说明：用于区分普通信息和告警。 */
export type FineTuningJobEventLevel = 'info' | 'warn' | 'error';

/** Fine-tuning Job Event。API：List Fine-tuning Events。说明：表示微调任务状态更新日志。 */
export interface FineTuningJobEvent {
  /** Event ID。API：Fine-tuning Events。说明：事件唯一标识。 */
  id: string;
  /** 对象类型。API：Fine-tuning Events。说明：固定为 `fine_tuning.job.event`。 */
  object: 'fine_tuning.job.event';
  /** 创建时间。API：Fine-tuning Events。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 日志级别。API：Fine-tuning Events。说明：`info`、`warn` 或 `error`。 */
  level: FineTuningJobEventLevel;
  /** 消息。API：Fine-tuning Events。说明：开发者可读状态文本。 */
  message: string;
  /** 事件数据。API：Fine-tuning Events。说明：附加结构化数据，可能为空。 */
  data: JsonObject | null;
  /** 事件类型。API：Fine-tuning Events。说明：例如 `message` 或平台扩展类型。 */
  type: string;
}

/** Fine-tuning Job Event 列表参数。API：List Fine-tuning Events。说明：支持 after 和 limit。 */
export interface FineTuningJobEventListParams extends CursorPageParams {
}

/** Fine-tuning Job Event 列表响应。API：List Fine-tuning Events。说明：列表元素为事件对象。 */
export type FineTuningJobEventListResponse = OpenAIListResponse<FineTuningJobEvent>;

/**
 * Fine-tuning checkpoint 指标。
 *
 * API：List Fine-tuning Checkpoints。
 * 说明：不同训练方法可能返回不同指标，字段均为可选。
 */
export interface FineTuningJobCheckpointMetrics {
  /** step。API：Fine-tuning Checkpoints。说明：指标对应训练 step。 */
  step?: number;
  /** 训练 loss。API：Fine-tuning Checkpoints。说明：训练集损失。 */
  train_loss?: number;
  /** 训练 token 准确率。API：Fine-tuning Checkpoints。说明：训练集平均 token accuracy。 */
  train_mean_token_accuracy?: number;
  /** 验证 loss。API：Fine-tuning Checkpoints。说明：验证集损失。 */
  valid_loss?: number;
  /** 验证 token 准确率。API：Fine-tuning Checkpoints。说明：验证集平均 token accuracy。 */
  valid_mean_token_accuracy?: number;
  /** 完整验证 loss。API：Fine-tuning Checkpoints。说明：完整验证集损失。 */
  full_valid_loss?: number;
  /** 完整验证 token 准确率。API：Fine-tuning Checkpoints。说明：完整验证集平均 token accuracy。 */
  full_valid_mean_token_accuracy?: number;
}

/** Fine-tuning Job Checkpoint。API：List Fine-tuning Checkpoints。说明：表示可直接调用的模型 checkpoint。 */
export interface FineTuningJobCheckpoint {
  /** Checkpoint ID。API：Fine-tuning Checkpoints。说明：checkpoint 对象 ID。 */
  id: string;
  /** 对象类型。API：Fine-tuning Checkpoints。说明：固定为 `fine_tuning.job.checkpoint`。 */
  object: 'fine_tuning.job.checkpoint';
  /** 创建时间。API：Fine-tuning Checkpoints。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** checkpoint 模型名。API：Fine-tuning Checkpoints。说明：可以作为模型 ID 调用。 */
  fine_tuned_model_checkpoint: string;
  /** 所属 Job ID。API：Fine-tuning Checkpoints。说明：产生该 checkpoint 的微调任务。 */
  fine_tuning_job_id: string;
  /** 指标。API：Fine-tuning Checkpoints。说明：该 step 的训练/验证指标。 */
  metrics: FineTuningJobCheckpointMetrics;
  /** step 数。API：Fine-tuning Checkpoints。说明：checkpoint 所在训练步数。 */
  step_number: number;
}

/** Fine-tuning checkpoint 列表参数。API：List Fine-tuning Checkpoints。说明：支持 after 和 limit。 */
export interface FineTuningJobCheckpointListParams extends CursorPageParams {
}

/** Fine-tuning checkpoint 列表响应。API：List Fine-tuning Checkpoints。说明：列表元素为 checkpoint。 */
export type FineTuningJobCheckpointListResponse = OpenAIListResponse<FineTuningJobCheckpoint>;

/**
 * Fine-tuning checkpoint permission 对象。
 *
 * API：`/v1/fine_tuning/checkpoints/{fine_tuned_model_checkpoint}/permissions`。
 * 说明：组织 owner 使用 admin API key 管理 fine-tuned checkpoint 对项目的访问权限。
 */
export interface FineTuningCheckpointPermission {
  /**
   * 对象类型。
   *
   * API：Fine-tuning checkpoint permissions。
   * 说明：固定为 `checkpoint.permission`。
   */
  object: 'checkpoint.permission';

  /**
   * 权限 ID。
   *
   * API：Fine-tuning checkpoint permissions。
   * 说明：删除权限时作为 `permission_id` 使用。
   */
  id: string;

  /**
   * 创建时间。
   *
   * API：Fine-tuning checkpoint permissions。
   * 说明：Unix 秒级时间戳。
   */
  created_at?: number;

  /**
   * 项目 ID。
   *
   * API：Fine-tuning checkpoint permissions。
   * 说明：被授权使用该 checkpoint 的项目。
   */
  project_id?: string;
}

/**
 * 创建 checkpoint permission 参数。
 *
 * API：`POST /v1/fine_tuning/checkpoints/{fine_tuned_model_checkpoint}/permissions`。
 * 说明：一次可把 checkpoint 授权给一个或多个项目；需要 admin API key。
 */
export interface FineTuningCheckpointPermissionCreateParams {
  /**
   * 项目 ID 列表。
   *
   * API：Create checkpoint permissions。
   * 说明：要授予 checkpoint 访问权限的项目 ID。
   */
  project_ids: Array<string>;
}

/**
 * checkpoint permission 列表参数。
 *
 * API：`GET /v1/fine_tuning/checkpoints/{fine_tuned_model_checkpoint}/permissions`。
 * 说明：支持按项目过滤和游标分页；需要 admin API key。
 */
export interface FineTuningCheckpointPermissionListParams extends CursorPageParams {
  /**
   * 项目 ID。
   *
   * API：List checkpoint permissions。
   * 说明：只返回某个项目的 checkpoint 权限。
   */
  project_id?: string;
}

/**
 * checkpoint permission 列表响应。
 *
 * API：List/Create checkpoint permissions。
 * 说明：创建和列表接口都返回权限对象列表。
 */
export type FineTuningCheckpointPermissionListResponse = OpenAIListResponse<FineTuningCheckpointPermission>;

/**
 * checkpoint permission 删除响应。
 *
 * API：`DELETE /v1/fine_tuning/checkpoints/{fine_tuned_model_checkpoint}/permissions/{permission_id}`。
 * 说明：删除某个项目对 checkpoint 的访问权限。
 */
export interface FineTuningCheckpointPermissionDeleted {
  /**
   * 对象类型。
   *
   * API：Delete checkpoint permission。
   * 说明：通常为 `checkpoint.permission`。
   */
  object: 'checkpoint.permission';

  /**
   * 权限 ID。
   *
   * API：Delete checkpoint permission。
   * 说明：被删除的权限 ID。
   */
  id: string;

  /**
   * 删除状态。
   *
   * API：Delete checkpoint permission。
   * 说明：`true` 表示服务端已删除该权限。
   */
  deleted: boolean;
}
