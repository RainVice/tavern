import { ErrorEvent, MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import {
  OpenAI,
  type ChatCompletionChunk,
  type ChatCompletionMessageParam,
  type ChatCompletionStreamHandlers,
  type OpenAIStream,
} from 'openai_ohos';
import {
  ChatRequest,
  ChatRequestType,
  ChatResponse,
  ChatResponseType,
  ChatWorkerProviderConfig,
} from './ChatWorkerTypes';

const workerPort: ThreadWorkerGlobalScope = worker.workerPort;
let cachedClient: OpenAI | undefined = undefined;
let cachedApiKey: string = '';
let cachedBaseUrl: string = '';
let currentStream: OpenAIStream | undefined = undefined;

/** 接收主线程发来的聊天请求，并分发到具体处理流程。 */
workerPort.onmessage = (event: MessageEvents) => {
  const chatRequest = event.data as ChatRequest;
  if (chatRequest.type === ChatRequestType.Request) {
    // 分支：主线程发来聊天请求，开始执行发送流程。
    sendMessage(chatRequest);
  }
};

workerPort.onmessageerror = () => {
  // 分支：主线程消息无法反序列化，回传协议错误。
  postError('', '消息无法反序列化');
};

workerPort.onerror = (event: ErrorEvent) => {
  // 分支：worker 运行时异常，回传错误信息给主线程。
  postError('', event.message);
};

/** 标记请求开始，然后发起流式模型请求并把增量文本回传给主线程。 */
function sendMessage(request: ChatRequest): void {
  // 分支前置：先通知主线程请求已开始，页面保持发送中状态。
  postResponse({
    type: ChatResponseType.Started,
    requestId: request.requestId,
  });
  try {
    const provider = request.provider;
    if (provider === undefined || !isValidProvider(provider)) {
      // 分支：没有可用 provider 或配置不完整，终止本次请求。
      throw new Error('请先在设置中添加模型提供商和模型');
    }
    // 分支：provider 可用，先关闭上一次未结束的流，避免新旧响应交错。
    closeCurrentStream();
    // 分支：复用或创建当前 provider 对应的 OpenAI client。
    const client = getOpenAIClient(provider);
    // 分支：把页面历史消息转换成 Chat Completions 的 messages。
    const messages = request.history.map((message) => ({
      role: message.role,
      content: message.content,
    }) as ChatCompletionMessageParam)
    // 分支：创建流式回调，把 SDK chunk 转成 worker response。
    const handlers = new WorkerChatCompletionStreamHandlers(request.requestId);
    // 分支：发起真正的流式请求，后续输出由 handlers 持续回传。
    currentStream = client.chat.completions.createStream({
      model: provider.model,
      messages: messages,
    }, handlers);
  } catch (error) {
    // 分支：校验、建连或发起请求失败，通知主线程展示错误。
    postError(request.requestId, '发送失败');
  }
}

/** 将 SDK 流式回调转成 worker response。 */
class WorkerChatCompletionStreamHandlers implements ChatCompletionStreamHandlers {
  private requestId: string = '';

  constructor(requestId: string) {
    this.requestId = requestId;
  }

  onChunk(chunk: ChatCompletionChunk): void {
    postChunk(this.requestId, chunk);
  }

  onError(message: string): void {
    currentStream = undefined;
    postError(this.requestId, message);
  }

  onDone(): void {
    currentStream = undefined;
    postResponse({
      type: ChatResponseType.Completed,
      requestId: this.requestId,
    });
  }
}

/** 在 worker 生命周期内复用 OpenAI client，provider 变更时再重建。 */
function getOpenAIClient(provider: ChatWorkerProviderConfig): OpenAI {
  if (cachedClient !== undefined && cachedApiKey === provider.apiKey && cachedBaseUrl === provider.baseUrl) {
    // 分支：provider 未变化，直接复用 worker 生命周期内缓存的 client。
    return cachedClient;
  }
  // 分支：provider 首次使用或配置已变化，重建 client 并更新缓存键。
  cachedApiKey = provider.apiKey;
  cachedBaseUrl = provider.baseUrl;
  cachedClient = new OpenAI({
    apiKey: provider.apiKey,
    baseURL: provider.baseUrl,
  });
  return cachedClient;
}

/** 校验主线程传入的 provider 是否足够完成一次请求。 */
function isValidProvider(provider: ChatWorkerProviderConfig): boolean {
  return provider.apiKey.trim().length > 0 &&
    provider.baseUrl.trim().length > 0 &&
    provider.model.trim().length > 0;
}

/** 关闭上一次未结束的流，避免多个请求在同一个 worker 里交错回包。 */
function closeCurrentStream(): void {
  if (currentStream === undefined) {
    // 分支：当前没有进行中的流式请求，无需关闭。
    return;
  }
  try {
    // 分支：存在未结束的流式请求，主动关闭底层连接。
    currentStream.close();
  } catch (error) {
    // 分支：关闭失败时忽略异常，下面仍会清空本地句柄。
  }
  currentStream = undefined;
}

/** 提取并回传一个流式 chunk 中的文本增量。 */
function postChunk(requestId: string, chunk: ChatCompletionChunk): void {
  if (chunk.choices.length === 0) {
    // 分支：chunk 没有候选内容，不回传空响应。
    return;
  }
  const content = chunk.choices[0].delta.content;
  if (!content) {
    // 分支：chunk 不包含文本增量，忽略角色或结束类信息。
    return;
  }
  // 分支：chunk 包含文本增量，转成 Response 发给主线程追加显示。
  postResponse({
    type: ChatResponseType.Response,
    requestId: requestId,
    content: content,
  });
}

/** 统一把 worker 内部错误包装成主线程可识别的 Error 响应。 */
function postError(requestId: string, message: string): void {
  postResponse({
    type: ChatResponseType.Error,
    requestId: requestId,
    error: message,
  });
}

/** worker 回包入口；postMessage 本身可能抛错，因此在这里集中兜底。 */
function postResponse(response: ChatResponse): void {
  try {
    // 分支：正常把 worker response 发回主线程。
    workerPort.postMessage(response);
  } catch (error) {
    // 分支：回包失败时无法继续通知主线程，只能吞掉异常避免 worker 崩溃。
  }
}
