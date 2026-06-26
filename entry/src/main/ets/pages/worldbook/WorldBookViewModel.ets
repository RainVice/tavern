import type { WorldBookIndexEntry } from 'tavern_ohos';
import { TavernRuntimeContainer } from '../../tavern/TavernRuntimeContainer';
import { WorldBookDetailPage } from '../worldbook_detail/WorldBookDetailPage';
import { WorldBookEditPage } from '../worldbook_edit/WorldBookEditPage';
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
    WorldBookEditPage.start(() => {
      this.loadBooks();
    });
  }

  onBookClick(book: WorldBookIndexEntry): void {
    WorldBookDetailPage.startWithParam(book, () => {
      this.loadBooks();
    });
  }

  onDelete(book: WorldBookIndexEntry): void {
    this.runtime.worldInfo.deleteWorldBook(book.id).then(() => {
      this.loadBooks();
    });
  }
}
