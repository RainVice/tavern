export class ChatRole {
  public static readonly Assistant: string = 'assistant'
  public static readonly User: string = 'user'
}

export interface ChatMessageItem {
  id: string
  role: string
  content: string
  time: string
}

@ObservedV2
export class ChatState {
  @Trace inputText: string = ''
  @Trace messages: ChatMessageItem[] = []
  @Trace isSending: boolean = false
}
