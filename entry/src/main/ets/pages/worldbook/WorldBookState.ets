import type { WorldBookIndexEntry } from 'tavern_ohos';

@ObservedV2
export class WorldBookState {
  @Trace books: Array<WorldBookIndexEntry> = []
}
