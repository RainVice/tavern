import type { ChatMessage } from 'tavern_ohos'

export enum ConversationPageType {
  NewConversation,
  ResumeConversation,
}

export interface ConversationPageParam {
  type: ConversationPageType;
  chatId: string;
  characterId: string;
}

@ObservedV2
export class ConversationState {
  private param?: ConversationPageParam = undefined
  @Trace chatId: string = ''
  @Trace title: string = ''
  @Trace messages: Array<ChatMessage> = []
  @Trace inputText: string = ''

  setParam(param?: ConversationPageParam): void {
    this.param = param
    this.chatId = param === undefined ? '' : param.chatId
  }

  getParam(): ConversationPageParam | undefined {
    return this.param
  }
}
