import { ConversationState } from './ConversationState'
import { worker } from '@kit.ArkTS'

export class ConversationViewModel {
  private state: ConversationState
  private conversationWorker: worker.ThreadWorker

  constructor(state: ConversationState) {
    this.state = state
    this.conversationWorker = new worker.ThreadWorker('entry/ets/workers/ConversationWorker.ets')
  }

  onInputChange(value: string): void {
    this.state.inputText = value
  }

  onSend(): void {
  }

  dispose(): void {
  }
}
