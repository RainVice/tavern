import { ZRouter } from '@hzw/zrouter'
import { RouterName, RVRouter } from 'router'
import { characterCardStore } from '../../store/CharacterCardStore'
import { CharacterCard } from '../../store/model/CharacterCard'
import { CharacterCardDetailState } from './CharacterCardDetailState'

export class CharacterCardDetailViewModel {
  private state: CharacterCardDetailState

  constructor(state: CharacterCardDetailState) {
    this.state = state
    const param = ZRouter.getInstance().getParam() as CharacterCard | undefined
    if (param) {
      this.state.updateFrom(param)
      if (param.id) {
        this.loadCard(param.id)
      }
    }
  }

  onEdit(): void {
    if (!this.state.id) {
      return
    }
    RVRouter.pushWithParam(RouterName.CharacterCardEdit, this.toCard(), () => {
      this.loadCard(this.state.id)
    })
  }

  onStartConversation(): void {
    RVRouter.push(RouterName.Chat)
  }

  private loadCard(id: string): void {
    characterCardStore.getCard(id).then((card) => {
      if (card) {
        this.state.updateFrom(card)
      }
    })
  }

  private toCard(): CharacterCard {
    const state = this.state
    return {
      id: state.id,
      name: state.name,
      updateTime: state.updateTime,
      avatarUrl: state.avatarUrl || undefined,
      description: state.description || undefined,
      personality: state.personality || undefined,
      scenario: state.scenario || undefined,
      firstMessage: state.firstMessage || undefined,
      exampleMessages: state.exampleMessages || undefined,
    }
  }
}
