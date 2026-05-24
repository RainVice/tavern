import { RVRouter } from 'router'
import { ModelProviderEditState } from './ModelProviderEditState'

export class ModelProviderEditViewModel {
  private state: ModelProviderEditState

  constructor(state: ModelProviderEditState) {
    this.state = state
  }

  onSave() {
    RVRouter.getNavStack().pop()
  }
}
