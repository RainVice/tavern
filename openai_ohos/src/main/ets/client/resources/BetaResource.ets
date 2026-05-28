import type {
  AssistantCreateParams,
  AssistantDeleted,
  AssistantListParams,
  AssistantListResponse,
  AssistantObject,
  AssistantStreamEvent,
  AssistantThread,
  AssistantThreadDeleted,
  MessageCreateParams,
  MessageUpdateParams,
  RunCreateParams,
  RunStep,
  RunStepListParams,
  RunStepListResponse,
  RunSubmitToolOutputsParams,
  ThreadAndRunCreateParams,
  ThreadCreateParams,
  ThreadMessage,
  ThreadMessageDeleted,
  ThreadMessageListParams,
  ThreadMessageListResponse,
  ThreadRun,
  ThreadRunListParams,
  ThreadRunListResponse,
  ThreadUpdateParams,
  AssistantUpdateParams,
} from '../../models/Assistants';
import type { JsonObject } from '../../models/Common';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import type { OpenAISSEEvent } from '../core/OpenAISSEParser';
import { appendCursorQuery, appendStringQuery, buildCursorListPath, buildPathWithQuery } from '../core/RequestUtils';
import type { OpenAIRequestSettings, OpenAIStream } from '../core/Types';

interface EmptyRequestBody {
}

const ASSISTANTS_BETA_HEADERS: Record<string, string> = {
  'OpenAI-Beta': 'assistants=v2',
};

/** Assistants stream 回调。API：Assistants streaming。说明：接收 SSE 解析后的 AssistantStreamEvent。 */
export interface AssistantStreamHandlers {
  /** 收到事件。API：Assistants streaming。说明：每条完整 SSE 事件调用一次。 */
  onEvent(event: AssistantStreamEvent): void;
  /** 发生错误。API：Assistants streaming。说明：网络或解析错误时调用。 */
  onError?: (message: string) => void;
  /** 流结束。API：Assistants streaming。说明：底层连接结束时调用。 */
  onDone?: () => void;
}

export interface OpenAIBetaResource {
  assistants: OpenAIAssistantsResource;
  threads: OpenAIThreadsResource;
}

export interface OpenAIAssistantsResource {
  create(params: AssistantCreateParams): Promise<AssistantObject>;
  list(params?: AssistantListParams): Promise<AssistantListResponse>;
  retrieve(assistantID: string): Promise<AssistantObject>;
  update(assistantID: string, params: AssistantUpdateParams): Promise<AssistantObject>;
  delete(assistantID: string): Promise<AssistantDeleted>;
}

export interface OpenAIThreadsResource {
  messages: OpenAIThreadMessagesResource;
  runs: OpenAIThreadRunsResource;
  create(params?: ThreadCreateParams): Promise<AssistantThread>;
  retrieve(threadID: string): Promise<AssistantThread>;
  update(threadID: string, params: ThreadUpdateParams): Promise<AssistantThread>;
  delete(threadID: string): Promise<AssistantThreadDeleted>;
  createAndRun(params: ThreadAndRunCreateParams): Promise<ThreadRun>;
  createAndRunStream(params: ThreadAndRunCreateParams, handlers: AssistantStreamHandlers, options?: OpenAIRequestSettings): OpenAIStream;
}

export interface OpenAIThreadMessagesResource {
  create(threadID: string, params: MessageCreateParams): Promise<ThreadMessage>;
  list(threadID: string, params?: ThreadMessageListParams): Promise<ThreadMessageListResponse>;
  retrieve(threadID: string, messageID: string): Promise<ThreadMessage>;
  update(threadID: string, messageID: string, params: MessageUpdateParams): Promise<ThreadMessage>;
  delete(threadID: string, messageID: string): Promise<ThreadMessageDeleted>;
}

export interface OpenAIThreadRunsResource {
  steps: OpenAIRunStepsResource;
  create(threadID: string, params: RunCreateParams): Promise<ThreadRun>;
  list(threadID: string, params?: ThreadRunListParams): Promise<ThreadRunListResponse>;
  retrieve(threadID: string, runID: string): Promise<ThreadRun>;
  update(threadID: string, runID: string, params: ThreadUpdateParams): Promise<ThreadRun>;
  cancel(threadID: string, runID: string): Promise<ThreadRun>;
  submitToolOutputs(threadID: string, runID: string, params: RunSubmitToolOutputsParams): Promise<ThreadRun>;
  createStream(threadID: string, params: RunCreateParams, handlers: AssistantStreamHandlers, options?: OpenAIRequestSettings): OpenAIStream;
  submitToolOutputsStream(threadID: string, runID: string, params: RunSubmitToolOutputsParams, handlers: AssistantStreamHandlers, options?: OpenAIRequestSettings): OpenAIStream;
}

export interface OpenAIRunStepsResource {
  list(threadID: string, runID: string, params?: RunStepListParams): Promise<RunStepListResponse>;
  retrieve(threadID: string, runID: string, stepID: string): Promise<RunStep>;
}

export class BetaResource implements OpenAIBetaResource {
  assistants: OpenAIAssistantsResource;
  threads: OpenAIThreadsResource;

  constructor(client: OpenAIRequestClient) {
    this.assistants = new AssistantsResource(client);
    this.threads = new ThreadsResource(client);
  }
}

class AssistantsResource implements OpenAIAssistantsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: AssistantCreateParams): Promise<AssistantObject> {
    const body = await this.client.post('/assistants', params, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as AssistantObject;
  }

  async list(params?: AssistantListParams): Promise<AssistantListResponse> {
    const body = await this.client.get(buildCursorListPath('/assistants', params), ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as AssistantListResponse;
  }

  async retrieve(assistantID: string): Promise<AssistantObject> {
    const body = await this.client.get('/assistants/' + assistantID, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as AssistantObject;
  }

  async update(assistantID: string, params: AssistantUpdateParams): Promise<AssistantObject> {
    const body = await this.client.post('/assistants/' + assistantID, params, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as AssistantObject;
  }

  async delete(assistantID: string): Promise<AssistantDeleted> {
    const body = await this.client.delete('/assistants/' + assistantID, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as AssistantDeleted;
  }
}

class ThreadsResource implements OpenAIThreadsResource {
  messages: OpenAIThreadMessagesResource;
  runs: OpenAIThreadRunsResource;
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
    this.messages = new ThreadMessagesResource(client);
    this.runs = new ThreadRunsResource(client);
  }

  async create(params?: ThreadCreateParams): Promise<AssistantThread> {
    const requestBody: ThreadCreateParams = params === undefined ? {} : params;
    const body = await this.client.post('/threads', requestBody, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as AssistantThread;
  }

  async retrieve(threadID: string): Promise<AssistantThread> {
    const body = await this.client.get('/threads/' + threadID, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as AssistantThread;
  }

  async update(threadID: string, params: ThreadUpdateParams): Promise<AssistantThread> {
    const body = await this.client.post('/threads/' + threadID, params, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as AssistantThread;
  }

  async delete(threadID: string): Promise<AssistantThreadDeleted> {
    const body = await this.client.delete('/threads/' + threadID, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as AssistantThreadDeleted;
  }

  async createAndRun(params: ThreadAndRunCreateParams): Promise<ThreadRun> {
    const body = await this.client.post('/threads/runs', params, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as ThreadRun;
  }

  createAndRunStream(params: ThreadAndRunCreateParams, handlers: AssistantStreamHandlers, options?: OpenAIRequestSettings): OpenAIStream {
    const streamParams = { ...params, stream: true };
    return this.client.streamPost('/threads/runs', streamParams, ASSISTANTS_BETA_HEADERS, (event: OpenAISSEEvent) => {
      this.forwardAssistantStreamEvent(event, handlers);
    }, handlers.onError, handlers.onDone, options);
  }

  private forwardAssistantStreamEvent(event: OpenAISSEEvent, handlers: AssistantStreamHandlers): void {
    const assistantEvent = buildAssistantStreamEvent(event);
    handlers.onEvent(assistantEvent);
  }
}

class ThreadMessagesResource implements OpenAIThreadMessagesResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(threadID: string, params: MessageCreateParams): Promise<ThreadMessage> {
    const body = await this.client.post('/threads/' + threadID + '/messages', params, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as ThreadMessage;
  }

  async list(threadID: string, params?: ThreadMessageListParams): Promise<ThreadMessageListResponse> {
    const body = await this.client.get(this.buildListPath(threadID, params), ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as ThreadMessageListResponse;
  }

  async retrieve(threadID: string, messageID: string): Promise<ThreadMessage> {
    const body = await this.client.get('/threads/' + threadID + '/messages/' + messageID, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as ThreadMessage;
  }

  async update(threadID: string, messageID: string, params: MessageUpdateParams): Promise<ThreadMessage> {
    const body = await this.client.post('/threads/' + threadID + '/messages/' + messageID, params, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as ThreadMessage;
  }

  async delete(threadID: string, messageID: string): Promise<ThreadMessageDeleted> {
    const body = await this.client.delete('/threads/' + threadID + '/messages/' + messageID, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as ThreadMessageDeleted;
  }

  private buildListPath(threadID: string, params?: ThreadMessageListParams): string {
    if (params === undefined) {
      return '/threads/' + threadID + '/messages';
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'run_id', params.run_id);
    appendCursorQuery(query, params);
    return buildPathWithQuery('/threads/' + threadID + '/messages', query);
  }
}

class ThreadRunsResource implements OpenAIThreadRunsResource {
  steps: OpenAIRunStepsResource;
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
    this.steps = new RunStepsResource(client);
  }

  async create(threadID: string, params: RunCreateParams): Promise<ThreadRun> {
    const body = await this.client.post('/threads/' + threadID + '/runs', params, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as ThreadRun;
  }

  async list(threadID: string, params?: ThreadRunListParams): Promise<ThreadRunListResponse> {
    const body = await this.client.get(buildCursorListPath('/threads/' + threadID + '/runs', params), ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as ThreadRunListResponse;
  }

  async retrieve(threadID: string, runID: string): Promise<ThreadRun> {
    const body = await this.client.get('/threads/' + threadID + '/runs/' + runID, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as ThreadRun;
  }

  async update(threadID: string, runID: string, params: ThreadUpdateParams): Promise<ThreadRun> {
    const body = await this.client.post('/threads/' + threadID + '/runs/' + runID, params, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as ThreadRun;
  }

  async cancel(threadID: string, runID: string): Promise<ThreadRun> {
    const requestBody: EmptyRequestBody = {};
    const body = await this.client.post('/threads/' + threadID + '/runs/' + runID + '/cancel', requestBody, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as ThreadRun;
  }

  async submitToolOutputs(threadID: string, runID: string, params: RunSubmitToolOutputsParams): Promise<ThreadRun> {
    const body = await this.client.post('/threads/' + threadID + '/runs/' + runID + '/submit_tool_outputs', params, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as ThreadRun;
  }

  createStream(threadID: string, params: RunCreateParams, handlers: AssistantStreamHandlers, options?: OpenAIRequestSettings): OpenAIStream {
    const streamParams = { ...params, stream: true };
    return this.client.streamPost('/threads/' + threadID + '/runs', streamParams, ASSISTANTS_BETA_HEADERS, (event: OpenAISSEEvent) => {
      handlers.onEvent(buildAssistantStreamEvent(event));
    }, handlers.onError, handlers.onDone, options);
  }

  submitToolOutputsStream(threadID: string, runID: string, params: RunSubmitToolOutputsParams, handlers: AssistantStreamHandlers, options?: OpenAIRequestSettings): OpenAIStream {
    const streamParams = { ...params, stream: true };
    return this.client.streamPost('/threads/' + threadID + '/runs/' + runID + '/submit_tool_outputs', streamParams, ASSISTANTS_BETA_HEADERS, (event: OpenAISSEEvent) => {
      handlers.onEvent(buildAssistantStreamEvent(event));
    }, handlers.onError, handlers.onDone, options);
  }
}

class RunStepsResource implements OpenAIRunStepsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(threadID: string, runID: string, params?: RunStepListParams): Promise<RunStepListResponse> {
    const path = '/threads/' + threadID + '/runs/' + runID + '/steps';
    const body = await this.client.get(buildCursorListPath(path, params), ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as RunStepListResponse;
  }

  async retrieve(threadID: string, runID: string, stepID: string): Promise<RunStep> {
    const body = await this.client.get('/threads/' + threadID + '/runs/' + runID + '/steps/' + stepID, ASSISTANTS_BETA_HEADERS);
    return JSON.parse(body) as RunStep;
  }
}

function buildAssistantStreamEvent(event: OpenAISSEEvent): AssistantStreamEvent {
  if (event.data === '[DONE]') {
    const doneData: JsonObject = {};
    return {
      event: 'done',
      data: doneData,
    };
  }
  return {
    event: event.event,
    data: JSON.parse(event.data) as JsonObject,
  };
}
