import { ZRouter } from '@hzw/zrouter'
import type { WorldBook, WorldBookIndexEntry, WorldInfoEntry } from 'tavern_ohos'
import { TavernRuntimeContainer } from '../../tavern/TavernRuntimeContainer'
import { WorldBookEditPage } from '../worldbook_edit/WorldBookEditPage'
import { WorldInfoEntryEditPage, type WorldInfoEntryEditPageParam } from '../worldinfo_entry_edit/WorldInfoEntryEditPage'
import { WorldBookDetailState } from './WorldBookDetailState'

export class WorldBookDetailViewModel {
  private state: WorldBookDetailState
  private runtime: TavernRuntimeContainer = TavernRuntimeContainer.getInstance()

  constructor(state: WorldBookDetailState) {
    this.state = state
    const param = ZRouter.getInstance().getParam() as WorldBookIndexEntry | undefined
    if (param !== undefined) {
      this.state.id = param.id
      this.state.name = param.name
      this.state.entryCount = param.entryCount
      this.loadBook(param.id)
    }
  }

  loadBook(id: string = this.state.getId()): void {
    if (id.length === 0) {
      return
    }
    this.runtime.worldInfo.getWorldBook(id).then((book: WorldBook) => {
      this.state.book = book
    })
  }

  onEditBook(): void {
    const book = this.state.book
    if (book === undefined) {
      return
    }
    WorldBookEditPage.startWithParam({
      id: book.id,
      name: book.name,
      entryCount: book.entries.length,
      createdAt: book.createdAt,
      updatedAt: book.updatedAt,
    }, () => this.loadBook(book.id))
  }

  onAddEntry(): void {
    const worldBookId = this.state.getId()
    if (worldBookId.length === 0) {
      return
    }
    const param: WorldInfoEntryEditPageParam = {
      worldBookId: worldBookId,
    }
    WorldInfoEntryEditPage.startWithParam(param, () => this.loadBook(worldBookId))
  }

  onEditEntry(entry: WorldInfoEntry): void {
    const worldBookId = this.state.getId()
    if (worldBookId.length === 0) {
      return
    }
    const param: WorldInfoEntryEditPageParam = {
      worldBookId: worldBookId,
      entry: entry,
    }
    WorldInfoEntryEditPage.startWithParam(param, () => this.loadBook(worldBookId))
  }
}
