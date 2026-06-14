import { ZRouter } from '@hzw/zrouter'
import { ToastUtil } from '@pura/harmony-utils'
import {
  OpenAIOhosProviderStreamSource,
  type CharacterRecord,
  type ChatMessage,
  type ChatRecord,
  type ConnectionResolvedProfile,
  type EventSubscription,
  type MessageEventPayload,
  type MessageRuntime,
  type ProviderChatMessage,
  type ProviderGenerationPayload,
  type ProviderStreamRequest,
  type StreamDeltaPayload,
} from 'tavern_ohos'
import { TavernRuntimeContainer } from '../../tavern/TavernRuntimeContainer'
import type { ConversationPageParam } from './ConversationState'
import { ConversationState } from './ConversationState'

export class ConversationViewModel {
  private state: ConversationState
  private runtime: TavernRuntimeContainer = TavernRuntimeContainer.getInstance()
  private subscriptions: Array<EventSubscription> = []

  constructor(state: ConversationState) {
    this.state = state
    const param = ZRouter.getInstance().getParam() as ConversationPageParam | undefined
    this.state.setParam(param)
    this.loadChat()
    this.subscribeRuntimeEvents()
  }

  onInputChange(value: string): void {
    this.state.inputText = value
  }

  onSend(): void {
    const chatId = this.state.chatId
    const text = this.state.inputText.trim()
    if (chatId.length === 0 || text.length === 0) {
      return
    }
    this.state.inputText = ''
    this.sendUserMessageAndGenerate(chatId, text).then((started: boolean) => {
      if (!started) {
        ToastUtil.showToast($r("app.string.no_default_model_provider"))
      }
      this.loadMessages()
    })
  }

  dispose(): void {
    for (let index = 0; index < this.subscriptions.length; index += 1) {
      this.subscriptions[index].unsubscribe()
    }
    this.subscriptions = new Array<EventSubscription>()
  }

  private loadChat(): void {
    const chatId = this.state.chatId
    if (chatId.length === 0) {
      return
    }
    this.runtime.chats.getChat(chatId).then((chat: ChatRecord) => {
      this.state.title = chat.title
      this.loadMessages()
    })
  }

  private loadMessages(): void {
    const chatId = this.state.chatId
    if (chatId.length === 0) {
      return
    }
    this.runtime.messages(chatId).listMessages().then((messages: Array<ChatMessage>) => {
      this.state.messages = messages
    })
  }

  private subscribeRuntimeEvents(): void {
    const container = TavernRuntimeContainer.getInstance()
    this.subscriptions.push(container.events.subscribe<MessageEventPayload>('message.added', (event) => {
      if (event.payload.chatId === this.state.chatId) {
        this.loadMessages()
      }
    }))
    this.subscriptions.push(container.events.subscribe<MessageEventPayload>('message.updated', (event) => {
      if (event.payload.chatId === this.state.chatId) {
        this.loadMessages()
      }
    }))
    this.subscriptions.push(container.events.subscribe<StreamDeltaPayload>('stream.delta', (event) => {
      if (event.payload.chatId === this.state.chatId) {
        this.loadMessages()
      }
    }))
    this.subscriptions.push(container.events.subscribe<ProviderGenerationPayload>('generation.failed', (event) => {
      if (event.payload.task.chatId === this.state.chatId) {
        this.loadMessages()
      }
    }))
  }

  private async sendUserMessageAndGenerate(chatId: string, text: string): Promise<boolean> {
    const content = text.trim()
    if (content.length === 0) {
      return false
    }
    await this.runtime.messages(chatId).addMessage({
      name: '你',
      role: 'user',
      text: content,
    })
    return this.generateAssistantMessage(chatId)
  }

  private async generateAssistantMessage(chatId: string): Promise<boolean> {
    await this.runtime.loadConnections()
    let resolved: ConnectionResolvedProfile
    try {
      resolved = this.runtime.connections.resolveActiveProfile(
        TavernRuntimeContainer.DEFAULT_CONNECTION_SCOPE,
        TavernRuntimeContainer.DEFAULT_CONNECTION_SCOPE_ID,
      )
    } catch (error) {
      return false
    }
    if (!resolved.profile.enabled || resolved.profile.model.length === 0) {
      return false
    }
    const chat = await this.runtime.chats.getChat(chatId)
    const character = await this.runtime.characters.getCharacter(chat.characterId)
    const history = await this.runtime.messages(chatId).listMessages()
    const providerMessages = this.buildProviderMessages(character, history)
    const messageRuntime: MessageRuntime = this.runtime.messages(chatId)
    const assistant = await messageRuntime.addMessage({
      name: character.name,
      role: 'assistant',
      text: '',
    })
    const request: ProviderStreamRequest = {
      provider: 'openai-compatible',
      model: resolved.profile.model,
      messages: providerMessages,
      temperature: 0.7,
      maxTokens: 1024,
      stop: resolved.profile.stopStrings,
      stream: true,
    }
    await this.runtime.provider.startOpenAICompatibleStream({
      taskId: `task-${Date.now()}-${assistant.id}`,
      chatId: chatId,
      messageId: assistant.id,
      request: request,
      source: new OpenAIOhosProviderStreamSource({
        apiKey: resolved.secretRef,
        baseURL: resolved.profile.serverUrl,
      }),
    })
    return true
  }

  private buildProviderMessages(character: CharacterRecord, history: Array<ChatMessage>): Array<ProviderChatMessage> {
    const result = new Array<ProviderChatMessage>()
    const systemPrompt = this.buildCharacterSystemPrompt(character)
    if (systemPrompt.length > 0) {
      result.push({
        role: 'system',
        content: systemPrompt,
      })
    }
    for (let index = 0; index < history.length; index += 1) {
      const message = history[index]
      if (message.text.trim().length === 0 || message.isSystem) {
        continue
      }
      result.push({
        role: message.isUser ? 'user' : 'assistant',
        content: message.text,
      })
    }
    return result
  }

  private buildCharacterSystemPrompt(character: CharacterRecord): string {
    const parts = new Array<string>()
    if (character.description.trim().length > 0) {
      parts.push('角色描述：' + character.description.trim())
    }
    if (character.personality.trim().length > 0) {
      parts.push('性格设定：' + character.personality.trim())
    }
    if (character.scenario.trim().length > 0) {
      parts.push('场景设定：' + character.scenario.trim())
    }
    if (character.exampleDialogue.trim().length > 0) {
      parts.push('对话示例：' + character.exampleDialogue.trim())
    }
    return parts.join('\n')
  }
}
