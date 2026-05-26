import { ToastUtil } from '@pura/harmony-utils'
import { RVRouter } from 'router'
import { CharacterCard } from '../../store/model/CharacterCard'
import { characterCardStore } from '../../store/CharacterCardStore'
import { CharacterCardEditState } from './CharacterCardEditState'
import { ZRouter } from '@hzw/zrouter'

export class CharacterCardEditViewModel {
  private state: CharacterCardEditState

  constructor(state: CharacterCardEditState) {
    this.state = state
    const param = ZRouter.getInstance().getParam() as CharacterCard | undefined;
    if (param) {
      this.initFromParam(param);
    }
  }

  private initFromParam(param: CharacterCard): void {
    if (param.id) {
      this.state.id = param.id
      characterCardStore.getCard(param.id).then((card) => {
        if (card) {
          this.state.name = card.name
          this.state.avatarUrl = card.avatarUrl ?? ''
          this.state.description = card.description ?? ''
          this.state.personality = card.personality ?? ''
          this.state.scenario = card.scenario ?? ''
          this.state.firstMessage = card.firstMessage ?? ''
          this.state.exampleMessages = card.exampleMessages ?? ''
        }
      })
    } else {
      this.state.name = param.name ?? ''
    }
  }

  onSave(): boolean {
    if (this.state.name.trim() === '') {
      ToastUtil.showToast($r("app.string.character_card_name_empty"));
      return false;
    }
    const state = this.state;
    const card: CharacterCard = {
      id: state.id,
      name: state.name.trim(),
      avatarUrl: state.avatarUrl.trim() || undefined,
      description: state.description.trim() || undefined,
      personality: state.personality.trim() || undefined,
      scenario: state.scenario.trim() || undefined,
      firstMessage: state.firstMessage.trim() || undefined,
      exampleMessages: state.exampleMessages.trim() || undefined,
    }
    characterCardStore.saveCard(card).then(() => {
      RVRouter.pop(true)
    })
    return true;
  }
}