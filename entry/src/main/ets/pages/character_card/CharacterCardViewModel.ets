import { RVRouter, RouterName } from 'router'
import { characterCardStore } from '../../store/CharacterCardStore'
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

  onCardClick(index: number): void {
    const card = this.state.cards[index]
    RVRouter.pushWithParam(RouterName.AddCharacterCard, card, () => {
      this.loadCards()
    })
  }

  onDeleteCard(index: number): void {
    const card = this.state.cards[index]
    characterCardStore.deleteCard(card.id).then(() => {
      this.loadCards()
    })
  }
}