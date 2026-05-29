import { RVRouter, RouterName } from 'router'
import { characterCardStore } from '../../store/CharacterCardStore'
import { CharacterCard } from '../../store/model/CharacterCard'
import { CharacterCardListState } from './CharacterCardListState'

export class CharacterCardViewModel {
  private state: CharacterCardListState

  constructor(state: CharacterCardListState) {
    this.state = state
    this.loadCards()
  }

  loadCards(): void {
    characterCardStore.getAllCards().then((list) => {
      this.state.cards = list
    })
  }

  onAdd(): void {
    RVRouter.push(RouterName.AddCharacterCard, () => {
      this.loadCards()
    })
  }

  onCardClick(card: CharacterCard): void {
    RVRouter.pushWithParam(RouterName.CharacterCardDetail, card, () => {
      this.loadCards()
    })
  }

  onDeleteCard(card: CharacterCard): void {
    characterCardStore.deleteCard(card.id).then(() => {
      this.loadCards()
    })
  }
}
