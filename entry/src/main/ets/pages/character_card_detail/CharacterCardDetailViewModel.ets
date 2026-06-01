import { ZRouter } from '@hzw/zrouter'
import { CharacterCard } from '../../store/model/CharacterCard'
import { CharacterCardEditPage } from '../character_card_edit/CharacterCardEditPage'
import { ConversationPage } from '../conversation/ConversationPage'
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
    CharacterCardEditPage.startWithParam(card)
  }

  onStartConversation(): void {
    const card = this.state.getParam()
    if (!card) {
      return
    }
    // todo
    // ConversationPage.startWithParam({ type: ConversationPageType.New, conversation: card })
  }
}
