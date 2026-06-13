import type {
  FineTuningCheckpointPermissionCreateParams,
  FineTuningCheckpointPermissionDeleted,
  FineTuningCheckpointPermissionListParams,
  FineTuningCheckpointPermissionListResponse,
  FineTuningGraderRunParams,
  FineTuningGraderRunResponse,
  FineTuningGraderValidateParams,
  FineTuningGraderValidateResponse,
  FineTuningJob,
  FineTuningJobCheckpointListParams,
  FineTuningJobCheckpointListResponse,
  FineTuningJobCreateParams,
  FineTuningJobEventListParams,
  FineTuningJobEventListResponse,
  FineTuningJobListParams,
  FineTuningJobListResponse,
} from '../../models/FineTuning';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import { appendCursorQuery, appendStringQuery, buildCursorListPath, buildPathWithQuery, encodePathParam } from '../core/RequestUtils';

interface EmptyRequestBody {
}

/**
 * Fine-tuning 资源入口。
 *
 * API：`/v1/fine_tuning`。
 * 说明：当前挂载 `jobs` 子资源，保持 `client.fineTuning.jobs.*` 使用方式。
 */
export interface OpenAIFineTuningResource {
  /** Jobs 子资源。API：Fine-tuning Jobs。说明：创建、查询、取消和观察微调任务。 */
  jobs: OpenAIFineTuningJobsResource;
  /** Alpha 子资源。API：Fine-tuning alpha。说明：当前包含 graders validate/run。 */
  alpha: OpenAIFineTuningAlphaResource;
  /** Checkpoint permissions 子资源。API：Fine-tuning checkpoint permissions。说明：用 admin key 管理 checkpoint 跨项目访问。 */
  checkpointPermissions: OpenAIFineTuningCheckpointPermissionsResource;
}

/** Fine-tuning Alpha 子资源。API：`/v1/fine_tuning/alpha`。说明：实验性微调辅助接口。 */
export interface OpenAIFineTuningAlphaResource {
  /** Graders 子资源。API：Fine-tuning alpha graders。说明：校验或运行 grader。 */
  graders: OpenAIFineTuningAlphaGradersResource;
}

/** Fine-tuning Alpha Graders 子资源。API：`/v1/fine_tuning/alpha/graders`。说明：测试 RFT/Evals grader。 */
export interface OpenAIFineTuningAlphaGradersResource {
  /** 运行 grader。API：`POST /v1/fine_tuning/alpha/graders/run`。说明：对单条样本执行评分。 */
  run(params: FineTuningGraderRunParams): Promise<FineTuningGraderRunResponse>;
  /** 校验 grader。API：`POST /v1/fine_tuning/alpha/graders/validate`。说明：检查 grader 配置是否合法。 */
  validate(params: FineTuningGraderValidateParams): Promise<FineTuningGraderValidateResponse>;
}

/**
 * Fine-tuning Jobs 子资源。
 *
 * API：`/v1/fine_tuning/jobs`。
 * 说明：管理微调任务。
 */
export interface OpenAIFineTuningJobsResource {
  /** 创建 job。API：`POST /v1/fine_tuning/jobs`。说明：提交训练文件并开始微调。 */
  create(params: FineTuningJobCreateParams): Promise<FineTuningJob>;
  /** 列出 jobs。API：`GET /v1/fine_tuning/jobs`。说明：分页读取微调任务。 */
  list(params?: FineTuningJobListParams): Promise<FineTuningJobListResponse>;
  /** 获取 job。API：`GET /v1/fine_tuning/jobs/{fine_tuning_job_id}`。说明：读取单个任务状态。 */
  retrieve(fineTuningJobID: string): Promise<FineTuningJob>;
  /** 取消 job。API：`POST /v1/fine_tuning/jobs/{fine_tuning_job_id}/cancel`。说明：取消排队或运行中的任务。 */
  cancel(fineTuningJobID: string): Promise<FineTuningJob>;
  /** 暂停 job。API：`POST /v1/fine_tuning/jobs/{fine_tuning_job_id}/pause`。说明：暂停可暂停的微调任务并生成 checkpoint。 */
  pause(fineTuningJobID: string): Promise<FineTuningJob>;
  /** 恢复 job。API：`POST /v1/fine_tuning/jobs/{fine_tuning_job_id}/resume`。说明：从最近 checkpoint 继续训练。 */
  resume(fineTuningJobID: string): Promise<FineTuningJob>;
  /** 列出事件。API：`GET /v1/fine_tuning/jobs/{fine_tuning_job_id}/events`。说明：读取任务日志。 */
  listEvents(fineTuningJobID: string, params?: FineTuningJobEventListParams): Promise<FineTuningJobEventListResponse>;
  /** 列出 checkpoints。API：`GET /v1/fine_tuning/jobs/{fine_tuning_job_id}/checkpoints`。说明：读取可用 checkpoint。 */
  listCheckpoints(fineTuningJobID: string, params?: FineTuningJobCheckpointListParams): Promise<FineTuningJobCheckpointListResponse>;
}

/**
 * Fine-tuning checkpoint permissions 子资源。
 *
 * API：`/v1/fine_tuning/checkpoints/{fine_tuned_model_checkpoint}/permissions`。
 * 说明：需要 admin API key，用于把 fine-tuned checkpoint 授权给组织内项目。
 */
export interface OpenAIFineTuningCheckpointPermissionsResource {
  /** 列出权限。API：List checkpoint permissions。说明：读取 checkpoint 已授权项目。 */
  list(fineTunedModelCheckpoint: string, params?: FineTuningCheckpointPermissionListParams): Promise<FineTuningCheckpointPermissionListResponse>;
  /** 创建权限。API：Create checkpoint permissions。说明：把 checkpoint 授权给项目列表。 */
  create(fineTunedModelCheckpoint: string, params: FineTuningCheckpointPermissionCreateParams): Promise<FineTuningCheckpointPermissionListResponse>;
  /** 删除权限。API：Delete checkpoint permission。说明：移除某个项目权限。 */
  delete(fineTunedModelCheckpoint: string, permissionID: string): Promise<FineTuningCheckpointPermissionDeleted>;
}

export class FineTuningResource implements OpenAIFineTuningResource {
  jobs: OpenAIFineTuningJobsResource;
  alpha: OpenAIFineTuningAlphaResource;
  checkpointPermissions: OpenAIFineTuningCheckpointPermissionsResource;

  constructor(client: OpenAIRequestClient) {
    this.jobs = new FineTuningJobsResource(client);
    this.alpha = new FineTuningAlphaResource(client);
    this.checkpointPermissions = new FineTuningCheckpointPermissionsResource(client);
  }
}

class FineTuningAlphaResource implements OpenAIFineTuningAlphaResource {
  graders: OpenAIFineTuningAlphaGradersResource;

  constructor(client: OpenAIRequestClient) {
    this.graders = new FineTuningAlphaGradersResource(client);
  }
}

class FineTuningAlphaGradersResource implements OpenAIFineTuningAlphaGradersResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async run(params: FineTuningGraderRunParams): Promise<FineTuningGraderRunResponse> {
    const body = await this.client.post('/fine_tuning/alpha/graders/run', params);
    return JSON.parse(body) as FineTuningGraderRunResponse;
  }

  async validate(params: FineTuningGraderValidateParams): Promise<FineTuningGraderValidateResponse> {
    const body = await this.client.post('/fine_tuning/alpha/graders/validate', params);
    return JSON.parse(body) as FineTuningGraderValidateResponse;
  }
}

class FineTuningJobsResource implements OpenAIFineTuningJobsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: FineTuningJobCreateParams): Promise<FineTuningJob> {
    const body = await this.client.post('/fine_tuning/jobs', params);
    return JSON.parse(body) as FineTuningJob;
  }

  async list(params?: FineTuningJobListParams): Promise<FineTuningJobListResponse> {
    const body = await this.client.get(buildCursorListPath('/fine_tuning/jobs', params));
    return JSON.parse(body) as FineTuningJobListResponse;
  }

  async retrieve(fineTuningJobID: string): Promise<FineTuningJob> {
    const body = await this.client.get('/fine_tuning/jobs/' + encodePathParam(fineTuningJobID));
    return JSON.parse(body) as FineTuningJob;
  }

  async cancel(fineTuningJobID: string): Promise<FineTuningJob> {
    const requestBody: EmptyRequestBody = {};
    const body = await this.client.post('/fine_tuning/jobs/' + encodePathParam(fineTuningJobID) + '/cancel', requestBody);
    return JSON.parse(body) as FineTuningJob;
  }

  async pause(fineTuningJobID: string): Promise<FineTuningJob> {
    const requestBody: EmptyRequestBody = {};
    const body = await this.client.post('/fine_tuning/jobs/' + encodePathParam(fineTuningJobID) + '/pause', requestBody);
    return JSON.parse(body) as FineTuningJob;
  }

  async resume(fineTuningJobID: string): Promise<FineTuningJob> {
    const requestBody: EmptyRequestBody = {};
    const body = await this.client.post('/fine_tuning/jobs/' + encodePathParam(fineTuningJobID) + '/resume', requestBody);
    return JSON.parse(body) as FineTuningJob;
  }

  async listEvents(fineTuningJobID: string, params?: FineTuningJobEventListParams): Promise<FineTuningJobEventListResponse> {
    const body = await this.client.get(buildCursorListPath('/fine_tuning/jobs/' + encodePathParam(fineTuningJobID) + '/events', params));
    return JSON.parse(body) as FineTuningJobEventListResponse;
  }

  async listCheckpoints(fineTuningJobID: string, params?: FineTuningJobCheckpointListParams): Promise<FineTuningJobCheckpointListResponse> {
    const body = await this.client.get(buildCursorListPath('/fine_tuning/jobs/' + encodePathParam(fineTuningJobID) + '/checkpoints', params));
    return JSON.parse(body) as FineTuningJobCheckpointListResponse;
  }
}

class FineTuningCheckpointPermissionsResource implements OpenAIFineTuningCheckpointPermissionsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(fineTunedModelCheckpoint: string, params?: FineTuningCheckpointPermissionListParams): Promise<FineTuningCheckpointPermissionListResponse> {
    const body = await this.client.get(this.buildListPath(fineTunedModelCheckpoint, params));
    return JSON.parse(body) as FineTuningCheckpointPermissionListResponse;
  }

  async create(fineTunedModelCheckpoint: string, params: FineTuningCheckpointPermissionCreateParams): Promise<FineTuningCheckpointPermissionListResponse> {
    const body = await this.client.post(this.buildBasePath(fineTunedModelCheckpoint), params);
    return JSON.parse(body) as FineTuningCheckpointPermissionListResponse;
  }

  async delete(fineTunedModelCheckpoint: string, permissionID: string): Promise<FineTuningCheckpointPermissionDeleted> {
    const body = await this.client.delete(this.buildBasePath(fineTunedModelCheckpoint) + '/' + encodePathParam(permissionID));
    return JSON.parse(body) as FineTuningCheckpointPermissionDeleted;
  }

  private buildListPath(fineTunedModelCheckpoint: string, params?: FineTuningCheckpointPermissionListParams): string {
    const basePath = this.buildBasePath(fineTunedModelCheckpoint);
    if (params === undefined) {
      return basePath;
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'project_id', params.project_id);
    appendCursorQuery(query, params);
    return buildPathWithQuery(basePath, query);
  }

  private buildBasePath(fineTunedModelCheckpoint: string): string {
    return '/fine_tuning/checkpoints/' + encodePathParam(fineTunedModelCheckpoint) + '/permissions';
  }
}
