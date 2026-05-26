import { CharacterCard } from '../../store/model/CharacterCard'

@ObservedV2
export class CharacterCardListState {
  @Trace cards: CharacterCard[] = []
}