import type { ChatIndexEntry } from 'tavern_ohos';
import { TavernRuntimeContainer } from '../../tavern/TavernRuntimeContainer';
import { ConversationPage } from '../conversation/ConversationPage';
import { ConversationPageType } from '../conversation/ConversationState';
import { MessageListState } from './MessageListState';

export class MessageListViewModel {
  private state: MessageListState;
  private runtime: TavernRuntimeContainer = TavernRuntimeContainer.getInstance();

  constructor(state: MessageListState) {
    this.state = state;
    this.loadChats();
  }

  loadChats(): void {
    this.runtime.chats.listChats().then((chats: Array<ChatIndexEntry>) => {
      chats.sort((left: ChatIndexEntry, right: ChatIndexEntry) => right.updatedAt - left.updatedAt);
      this.state.chats = chats;
    });
  }

  onChatClick(chat: ChatIndexEntry): void {
    ConversationPage.startWithParam({
      type: ConversationPageType.ResumeConversation,
      chatId: chat.id,
      characterId: chat.characterId,
    }, () => {
      this.loadChats();
    });
  }
}
