import { CharacterCard } from "../../db/entity/CharacterCardEntity";

@ObservedV2
export class CharacterCardListState {
  @Trace cards: CharacterCard[] = []
}