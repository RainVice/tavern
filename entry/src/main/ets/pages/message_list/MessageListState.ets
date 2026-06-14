import type { ChatIndexEntry } from 'tavern_ohos';

@ObservedV2
export class MessageListState {
  @Trace chats: Array<ChatIndexEntry> = []
}
