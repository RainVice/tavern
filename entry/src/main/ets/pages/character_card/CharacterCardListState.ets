import type { CharacterRecord } from 'tavern_ohos';

@ObservedV2
export class CharacterCardListState {
  @Trace cards: Array<CharacterRecord> = []
}
