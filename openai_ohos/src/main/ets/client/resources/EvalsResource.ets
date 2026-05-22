import type {
  EvalCreateParams,
  EvalDeleted,
  EvalListParams,
  EvalListResponse,
  EvalObject,
  EvalRun,
  EvalRunCreateParams,
  EvalRunDeleted,
  EvalRunListParams,
  EvalRunListResponse,
  EvalRunOutputItem,
  EvalRunOutputItemListParams,
  EvalRunOutputItemListResponse,
  EvalUpdateParams,
} from '../../models/Evals';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import { appendCursorQuery, appendStringQuery, buildPathWithQuery } from '../core/RequestUtils';

/**
 * Evals 资源入口。
 *
 * API：`/v1/evals`。
 * 说明：管理评测定义、运行和输出项。
 */
export interface OpenAIEvalsResource {
  /** Runs 子资源。API：Eval Runs。说明：启动和读取 eval runs。 */
  runs: OpenAIEvalRunsResource;
  /** 创建 eval。API：Create Eval。说明：创建评测结构。 */
  create(params: EvalCreateParams): Promise<EvalObject>;
  /** 列出 evals。API：List Evals。说明：分页读取项目内评测。 */
  list(params?: EvalListParams): Promise<EvalListResponse>;
  /** 获取 eval。API：Retrieve Eval。说明：读取单个评测。 */
  retrieve(evalID: string): Promise<EvalObject>;
  /** 更新 eval。API：Update Eval。说明：更新名称或 metadata。 */
  update(evalID: string, params: EvalUpdateParams): Promise<EvalObject>;
  /** 删除 eval。API：Delete Eval。说明：删除评测定义。 */
  delete(evalID: string): Promise<EvalDeleted>;
}

/** Eval Runs 子资源。API：`/v1/evals/{eval_id}/runs`。说明：管理评测运行。 */
export interface OpenAIEvalRunsResource {
  /** Output items 子资源。API：Eval Run Output Items。说明：读取运行输出。 */
  outputItems: OpenAIEvalRunOutputItemsResource;
  /** 创建 run。API：Create Eval Run。说明：启动一次评测。 */
  create(evalID: string, params: EvalRunCreateParams): Promise<EvalRun>;
  /** 列出 runs。API：List Eval Runs。说明：分页读取评测运行。 */
  list(evalID: string, params?: EvalRunListParams): Promise<EvalRunListResponse>;
  /** 获取 run。API：Retrieve Eval Run。说明：读取单个 run。 */
  retrieve(evalID: string, runID: string): Promise<EvalRun>;
  /** 删除 run。API：Delete Eval Run。说明：删除一次运行记录。 */
  delete(evalID: string, runID: string): Promise<EvalRunDeleted>;
}

/** Eval Run Output Items 子资源。API：`/v1/evals/{eval_id}/runs/{run_id}/output_items`。说明：读取样本级结果。 */
export interface OpenAIEvalRunOutputItemsResource {
  /** 列出 output items。API：List output items。说明：分页读取样本级结果。 */
  list(evalID: string, runID: string, params?: EvalRunOutputItemListParams): Promise<EvalRunOutputItemListResponse>;
  /** 获取 output item。API：Retrieve output item。说明：读取单条样本级结果。 */
  retrieve(evalID: string, runID: string, outputItemID: string): Promise<EvalRunOutputItem>;
}

export class EvalsResource implements OpenAIEvalsResource {
  runs: OpenAIEvalRunsResource;
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
    this.runs = new EvalRunsResource(client);
  }

  async create(params: EvalCreateParams): Promise<EvalObject> {
    const body = await this.client.post('/evals', params);
    return JSON.parse(body) as EvalObject;
  }

  async list(params?: EvalListParams): Promise<EvalListResponse> {
    const body = await this.client.get(buildEvalListPath('/evals', params));
    return JSON.parse(body) as EvalListResponse;
  }

  async retrieve(evalID: string): Promise<EvalObject> {
    const body = await this.client.get('/evals/' + evalID);
    return JSON.parse(body) as EvalObject;
  }

  async update(evalID: string, params: EvalUpdateParams): Promise<EvalObject> {
    const body = await this.client.post('/evals/' + evalID, params);
    return JSON.parse(body) as EvalObject;
  }

  async delete(evalID: string): Promise<EvalDeleted> {
    const body = await this.client.delete('/evals/' + evalID);
    return JSON.parse(body) as EvalDeleted;
  }
}

class EvalRunsResource implements OpenAIEvalRunsResource {
  outputItems: OpenAIEvalRunOutputItemsResource;
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
    this.outputItems = new EvalRunOutputItemsResource(client);
  }

  async create(evalID: string, params: EvalRunCreateParams): Promise<EvalRun> {
    const body = await this.client.post('/evals/' + evalID + '/runs', params);
    return JSON.parse(body) as EvalRun;
  }

  async list(evalID: string, params?: EvalRunListParams): Promise<EvalRunListResponse> {
    const body = await this.client.get(buildEvalRunListPath('/evals/' + evalID + '/runs', params));
    return JSON.parse(body) as EvalRunListResponse;
  }

  async retrieve(evalID: string, runID: string): Promise<EvalRun> {
    const body = await this.client.get('/evals/' + evalID + '/runs/' + runID);
    return JSON.parse(body) as EvalRun;
  }

  async delete(evalID: string, runID: string): Promise<EvalRunDeleted> {
    const body = await this.client.delete('/evals/' + evalID + '/runs/' + runID);
    return JSON.parse(body) as EvalRunDeleted;
  }
}

class EvalRunOutputItemsResource implements OpenAIEvalRunOutputItemsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(evalID: string, runID: string, params?: EvalRunOutputItemListParams): Promise<EvalRunOutputItemListResponse> {
    const path = '/evals/' + evalID + '/runs/' + runID + '/output_items';
    const body = await this.client.get(buildEvalOutputItemListPath(path, params));
    return JSON.parse(body) as EvalRunOutputItemListResponse;
  }

  async retrieve(evalID: string, runID: string, outputItemID: string): Promise<EvalRunOutputItem> {
    const body = await this.client.get('/evals/' + evalID + '/runs/' + runID + '/output_items/' + outputItemID);
    return JSON.parse(body) as EvalRunOutputItem;
  }
}

function buildEvalListPath(path: string, params?: EvalListParams): string {
  if (params === undefined) {
    return path;
  }
  const query: Array<string> = [];
  if (params.order_by !== undefined) {
    query.push('order_by=' + params.order_by);
  }
  appendCursorQuery(query, params);
  return buildPathWithQuery(path, query);
}

function buildEvalRunListPath(path: string, params?: EvalRunListParams): string {
  if (params === undefined) {
    return path;
  }
  const query: Array<string> = [];
  appendStringQuery(query, 'status', params.status);
  appendCursorQuery(query, params);
  return buildPathWithQuery(path, query);
}

function buildEvalOutputItemListPath(path: string, params?: EvalRunOutputItemListParams): string {
  if (params === undefined) {
    return path;
  }
  const query: Array<string> = [];
  appendStringQuery(query, 'status', params.status);
  appendCursorQuery(query, params);
  return buildPathWithQuery(path, query);
}
