import type { WorldBookIndexEntry } from 'tavern_ohos';
import { TavernRuntimeContainer } from '../../tavern/TavernRuntimeContainer';
import { WorldBookState } from './WorldBookState';

export class WorldBookViewModel {
  private state: WorldBookState;
  private runtime: TavernRuntimeContainer = TavernRuntimeContainer.getInstance();

  constructor(state: WorldBookState) {
    this.state = state;
    this.loadBooks();
  }

  loadBooks(): void {
    this.runtime.worldInfo.listWorldBooks().then((books: Array<WorldBookIndexEntry>) => {
      books.sort((left: WorldBookIndexEntry, right: WorldBookIndexEntry) => right.updatedAt - left.updatedAt);
      this.state.books = books;
    });
  }

  onAdd(): void {
    const index = this.state.books.length + 1;
    this.runtime.worldInfo.createWorldBook('世界书 ' + index).then(() => {
      this.loadBooks();
    });
  }

  onDelete(book: WorldBookIndexEntry): void {
    this.runtime.worldInfo.deleteWorldBook(book.id).then(() => {
      this.loadBooks();
    });
  }
}
