import { ZRouter } from '@hzw/zrouter'
import { RouterName, RVRouter } from 'router'
import { CharacterCard } from '../../store/model/CharacterCard'
import { CharacterCardDetailState } from './CharacterCardDetailState'

export class CharacterCardDetailViewModel {
  private state: CharacterCardDetailState

  constructor(state: CharacterCardDetailState) {
    this.state = state
    const param = ZRouter.getInstance().getParam() as CharacterCard | undefined
    this.state.setParam(param)
  }

  onEdit(): void {
    const card = this.state.getParam()
    if (!card || !this.state.getId()) {
      return
    }
    RVRouter.pushWithParam(RouterName.CharacterCardEdit, card)
  }

  onStartConversation(): void {
    RVRouter.pushWithParam(RouterName.Conversation, this.state.getParam())
  }
}
