import { ChatState } from './ChatState'
import { worker } from '@kit.ArkTS'

export class ChatViewModel {
  private state: ChatState
  private chatWorker: worker.ThreadWorker

  constructor(state: ChatState) {
    this.state = state
    this.chatWorker = new worker.ThreadWorker('entry/ets/workers/ChatWorker.ets')
  }

  onInputChange(value: string): void {
    this.state.inputText = value
  }

  onSend(): void {
  }

  dispose(): void {
  }
}
