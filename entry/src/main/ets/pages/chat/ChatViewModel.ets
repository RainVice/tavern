import { ErrorEvent, MessageEvents, worker } from '@kit.ArkTS'
import { systemDateTime } from '@kit.BasicServicesKit'
import { modelProviderStore } from '../../store/ModelProviderStore'
import {
  ChatRequest,
  ChatRequestType,
  ChatResponse,
  ChatResponseType,
  ChatWorkerMessage,
  ChatWorkerMessageRole,
  ChatWorkerProviderConfig,
} from '../../workers/ChatWorkerTypes'
import { ChatMessageItem, ChatRole, ChatState } from './ChatState'

export class ChatViewModel {
  private state: ChatState
  private chatWorker?: worker.ThreadWorker
  private requestSeed: number = 0
  /** 当前等待 worker 回填的助手消息 ID。 */
  private pendingAssistantMessageId: string = ''
  /** 当前助手消息已收到的流式文本。 */
  private pendingAssistantContent: string = ''

  constructor(state: ChatState) {
    this.state = state
  }

  onInputChange(value: string): void {
    this.state.inputText = value
  }

  /** 发送用户输入，先更新本地气泡，再把请求交给 worker。 */
  onSend(): void {
    const content = this.state.inputText.trim()
    if (content.length === 0 || this.state.isSending) {
      // 分支：输入为空或上一条消息仍在发送中，不重复发起请求。
      return
    }
    const requestId = this.createId('request')
    const userMessage = this.createMessage(ChatRole.User, content)
    const history = this.buildHistory(this.state.messages.concat([userMessage]))
    this.pendingAssistantMessageId = this.createId('assistant')
    this.pendingAssistantContent = ''
    const pendingMessage: ChatMessageItem = {
      id: this.pendingAssistantMessageId,
      role: ChatRole.Assistant,
      content: '...',
      time: this.formatTime(),
    }
    this.state.messages = this.state.messages.concat([userMessage, pendingMessage])
    this.state.inputText = ''
    this.state.isSending = true
    this.resolveProvider()
      .then((provider) => {
        // 分支：provider 读取完成，组装可序列化请求发给 worker。
        const request: ChatRequest = {
          type: ChatRequestType.Request,
          requestId: requestId,
          history: history,
          provider: provider,
        }
        this.postToWorker(request)
      })
      .catch((error: Error) => {
        // 分支：读取 provider 失败，用助手气泡展示错误。
        this.finishWithError(error.message)
      })
  }

  /** 页面退出时释放 worker，避免后台线程继续占用资源。 */
  dispose(): void {
    if (this.chatWorker) {
      // 分支：页面退出且 worker 已创建，主动终止后台线程。
      try {
        this.chatWorker.terminate()
      } catch (error) {
        // 分支：终止 worker 失败时忽略异常，继续清空本地引用。
      }
      this.chatWorker = undefined
    }
  }

  /** 懒创建并复用聊天 worker，避免每条消息都创建线程。 */
  private getWorker(): worker.ThreadWorker {
    if (this.chatWorker) {
      // 分支：已有 worker，复用同一个线程继续处理后续消息。
      return this.chatWorker
    }
    // 分支：首次发送消息，创建聊天 worker 并注册回调。
    const chatWorker = new worker.ThreadWorker('entry/ets/workers/ChatWorker.ets')
    chatWorker.onmessage = (event: MessageEvents) => {
      this.onWorkerMessage(event)
    }
    chatWorker.onmessageerror = () => {
      this.finishWithError('worker 消息反序列化失败')
    }
    chatWorker.onAllErrors = (error: ErrorEvent) => {
      this.finishWithError(error.message)
    }
    this.chatWorker = chatWorker
    return chatWorker
  }

  /** 处理 worker 回包，并把输出或错误写回助手占位气泡。 */
  private onWorkerMessage(event: MessageEvents): void {
    const response = event.data as ChatResponse
    if (response.type === ChatResponseType.Started) {
      // 分支：worker 已确认请求开始，页面继续保持发送中状态。
      return
    }
    if (response.type === ChatResponseType.Response) {
      // 分支：收到一段流式文本，追加到当前助手气泡。
      this.appendResponse(response.content ?? '')
      return
    }
    if (response.type === ChatResponseType.Completed) {
      // 分支：流式响应结束，解除发送中状态。
      this.finishWithResponse()
      return
    }
    if (response.type === ChatResponseType.Error) {
      // 分支：worker 或模型请求失败，把错误写入助手气泡。
      this.finishWithError(response.error ?? '发送失败')
    }
  }

  /** 当前基础版本默认使用提供商列表里的第一个 provider 和第一个模型。 */
  private resolveProvider(): Promise<ChatWorkerProviderConfig | undefined> {
    return modelProviderStore.getAllProviders()
      .then((providers) => {
        if (providers.length === 0 || providers[0].modelDefinitions.length === 0) {
          // 分支：没有 provider 或 provider 没有模型，交给 worker 返回配置错误。
          return undefined
        }
        // 分支：使用最近的第一个 provider 和它的第一个模型。
        return {
          apiKey: providers[0].apiKey,
          baseUrl: providers[0].baseUrl,
          model: providers[0].modelDefinitions[0].modelId,
        } as ChatWorkerProviderConfig
      })
  }

  /** 给 worker 发送请求；线程创建或消息发送失败时直接回填错误气泡。 */
  private postToWorker(request: ChatRequest): void {
    try {
      // 分支：worker 可用，发送请求到后台线程。
      this.getWorker().postMessage(request)
    } catch (error) {
      // 分支：worker 创建或 postMessage 失败，回填启动失败。
      this.finishWithError('worker 启动失败')
    }
  }

  /** 把页面消息转换为 worker 可序列化的上下文。 */
  private buildHistory(messages: ChatMessageItem[]): ChatWorkerMessage[] {
    const history: ChatWorkerMessage[] = []
    for (const message of messages) {
      if (message.content.trim().length > 0) {
        // 分支：消息内容有效，加入 worker 请求上下文。
        history.push({
          role: this.toWorkerRole(message.role),
          content: message.content,
        })
      }
    }
    return history
  }

  /** 页面当前只有 user/assistant 两类气泡，其他角色后续再扩展。 */
  private toWorkerRole(role: string): ChatWorkerMessageRole {
    if (role === ChatRole.Assistant) {
      // 分支：助手气泡转换成 assistant 角色。
      return 'assistant'
    }
    // 分支：非助手气泡当前统一按 user 角色发送。
    return 'user'
  }

  /** 收到流式增量后追加到当前助手气泡。 */
  private appendResponse(content: string): void {
    if (content.length === 0) {
      // 分支：空增量不更新 UI，避免无意义刷新。
      return
    }
    // 分支：有效增量追加到累计文本，并刷新助手气泡。
    this.pendingAssistantContent += content
    this.updatePendingAssistantMessage(this.pendingAssistantContent)
  }

  /** 模型流式响应结束后解除发送中状态。 */
  private finishWithResponse(): void {
    if (this.pendingAssistantContent.length === 0) {
      // 分支：流结束但没有任何文本，展示兜底提示。
      this.updatePendingAssistantMessage('模型没有返回文本内容')
    }
    // 分支：无论是否有文本，流结束后都解除发送中状态。
    this.state.isSending = false
  }

  /** 失败时同样复用助手气泡展示错误，避免用户消息孤立。 */
  private finishWithError(message: string): void {
    this.updatePendingAssistantMessage(message.length > 0 ? message : '发送失败')
    this.state.isSending = false
  }

  /** 不直接修改数组元素，重新赋值触发 ObservedV2 刷新。 */
  private updatePendingAssistantMessage(content: string): void {
    const messageId = this.pendingAssistantMessageId
    this.state.messages = this.state.messages.map((message) => {
      if (message.id === messageId) {
        // 分支：找到助手占位气泡，用最新内容替换。
        return {
          id: message.id,
          role: message.role,
          content: content,
          time: this.formatTime(),
        } as ChatMessageItem
      }
      // 分支：其他消息保持不变，避免影响历史气泡。
      return message
    })
  }

  private createMessage(role: string, content: string): ChatMessageItem {
    return {
      id: this.createId(role),
      role: role,
      content: content,
      time: this.formatTime(),
    }
  }

  private createId(prefix: string): string {
    this.requestSeed += 1
    return prefix + '-' + systemDateTime.getTime().toString() + '-' + this.requestSeed.toString()
  }

  private formatTime(): string {
    const date = new Date(systemDateTime.getTime())
    return this.padTime(date.getHours()) + ':' + this.padTime(date.getMinutes())
  }

  private padTime(value: number): string {
    return value < 10 ? '0' + value.toString() : value.toString()
  }
}
