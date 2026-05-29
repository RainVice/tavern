import { ChatState } from './ChatState'

export class ChatViewModel {
  private state: ChatState

  constructor(state: ChatState) {
    this.state = state
  }

  onInputChange(value: string): void {
    this.state.inputText = value
  }

  onSend(): void {
    this.state.inputText = ''
  }
}
