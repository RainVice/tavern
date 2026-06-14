import { ZRouter } from '@hzw/zrouter'
import type { CharacterRecord, ChatRecord } from 'tavern_ohos'
import { TavernRuntimeContainer } from '../../tavern/TavernRuntimeContainer'
import { CharacterCardEditPage } from '../character_card_edit/CharacterCardEditPage'
import { ConversationPage } from '../conversation/ConversationPage'
import { ConversationPageType } from '../conversation/ConversationState'
import { CharacterCardDetailState } from './CharacterCardDetailState'

export class CharacterCardDetailViewModel {
  private state: CharacterCardDetailState
  private runtime: TavernRuntimeContainer = TavernRuntimeContainer.getInstance()

  constructor(state: CharacterCardDetailState) {
    this.state = state
    const param = ZRouter.getInstance().getParam() as CharacterRecord | undefined
    this.state.setParam(param)
    if (param !== undefined) {
      this.runtime.readCharacterAvatar(param).then((avatar: string) => {
        this.state.avatarUrl = avatar
      })
    }
  }

  onEdit(): void {
    const card = this.state.getParam()
    if (card === undefined || this.state.getId().length === 0) {
      return
    }
    CharacterCardEditPage.startWithParam(card)
  }

  onStartConversation(): void {
    const card = this.state.getParam()
    if (card === undefined) {
      return
    }
    this.createChat(card).then((chat: ChatRecord) => {
      ConversationPage.startWithParam({
        type: ConversationPageType.NewConversation,
        chatId: chat.id,
        characterId: card.id,
      })
    })
  }

  private async createChat(card: CharacterRecord): Promise<ChatRecord> {
    const title = card.name.length > 0 ? card.name : '未命名聊天'
    const chat = await this.runtime.chats.createChat({
      title: title,
      characterId: card.id,
      personaId: '',
    })
    if (card.firstMessage.trim().length > 0) {
      await this.runtime.messages(chat.id).addMessage({
        name: card.name,
        role: 'assistant',
        text: card.firstMessage.trim(),
      })
    }
    return chat
  }
}
