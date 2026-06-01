import { characterCardStore } from '../../store/CharacterCardStore'
import { CharacterCard } from '../../store/model/CharacterCard'
import { CharacterCardDetailPage } from '../character_card_detail/CharacterCardDetailPage'
import { CharacterCardEditPage } from '../character_card_edit/CharacterCardEditPage'
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
    CharacterCardEditPage.start(() => {
      this.loadCards()
    })
  }

  onCardClick(card: CharacterCard): void {
    CharacterCardDetailPage.startWithParam(card, () => {
      this.loadCards()
    })
  }

  onDeleteCard(card: CharacterCard): void {
    characterCardStore.deleteCard(card.id).then(() => {
      this.loadCards()
    })
  }
}
