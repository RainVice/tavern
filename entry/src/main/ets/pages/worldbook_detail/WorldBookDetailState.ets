import type { WorldBook } from 'tavern_ohos'

@ObservedV2
export class WorldBookDetailState {
  @Trace id: string = ''
  @Trace name: string = ''
  @Trace entryCount: number = 0
  @Trace book: WorldBook | undefined = undefined

  getId(): string {
    return this.book?.id ?? this.id
  }

  getName(): string {
    return this.book?.name ?? this.name
  }

  getEntryCount(): number {
    return this.book?.entries.length ?? this.entryCount
  }
}
