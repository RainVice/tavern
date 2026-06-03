import { CharacterCardDao } from '../../db/dao/CharacterCardDao'
import { CharacterCard } from '../../db/entity/CharacterCardEntity'
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
    CharacterCardDao.queryAll().then((list) => {
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
    CharacterCardDao.delete(card).then(() => {
      this.loadCards()
    })
  }
}
