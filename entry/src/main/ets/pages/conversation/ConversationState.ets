import { Conversation } from "openai_ohos"

@ObservedV2
export class ConversationState {
  private param?: ConversationPageParam = undefined
  @Trace inputText: string = ''
}


export enum ConversationPageType {
  NewConversation,
  ResumeConversation,
}

export interface ConversationPageParam {
  type: ConversationPageType
  conversation?: Conversation
}
