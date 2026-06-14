import type { CharacterIndexEntry, CharacterRecord } from 'tavern_ohos'
import { TavernRuntimeContainer } from '../../tavern/TavernRuntimeContainer'
import { CharacterCardDetailPage } from '../character_card_detail/CharacterCardDetailPage'
import { CharacterCardEditPage } from '../character_card_edit/CharacterCardEditPage'
import { CharacterCardListState } from './CharacterCardListState'

export class CharacterCardViewModel {
  private state: CharacterCardListState
  private runtime: TavernRuntimeContainer = TavernRuntimeContainer.getInstance()

  constructor(state: CharacterCardListState) {
    this.state = state
    this.loadCards()
  }

  loadCards(): void {
    this.runtime.characters.listCharacters().then(async (items: Array<CharacterIndexEntry>) => {
      const cards = new Array<CharacterRecord>()
      for (let index = 0; index < items.length; index += 1) {
        cards.push(await this.runtime.characters.getCharacter(items[index].id))
      }
      cards.sort((left: CharacterRecord, right: CharacterRecord) => right.updatedAt - left.updatedAt)
      this.state.cards = cards
    })
  }

  onAdd(): void {
    CharacterCardEditPage.start(() => {
      this.loadCards()
    })
  }

  onCardClick(card: CharacterRecord): void {
    CharacterCardDetailPage.startWithParam(card, () => {
      this.loadCards()
    })
  }

  onDeleteCard(card: CharacterRecord): void {
    this.runtime.characters.deleteCharacter(card.id).then(() => {
      this.loadCards()
    })
  }
}
