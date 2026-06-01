import { ErrorEvent, MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';


const workerPort: ThreadWorkerGlobalScope = worker.workerPort;
/** 接收主线程发来的聊天请求，并分发到具体处理流程。 */
workerPort.onmessage = (event: MessageEvents) => {
};

workerPort.onmessageerror = () => {
};

workerPort.onerror = (event: ErrorEvent) => {
};


/** 主线程发送给 ChatWorker 的请求类型。 */
export enum ChatRequestType {
  /** 请求模型生成回复。 */
  Request,
}

/** ChatWorker 回传给主线程的响应类型。 */
export enum ChatResponseType {
  /** worker 已收到请求，主线程可保持发送中状态。 */
  Started,
  /** 模型返回了一段增量文本。 */
  Response,
  /** 模型流式响应结束。 */
  Completed,
  /** 发送、请求或解析过程中出现错误。 */
  Error,
}
