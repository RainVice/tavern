import { CharacterCard } from '../../store/model/CharacterCard'

@ObservedV2
export class CharacterCardDetailState {
  @Trace id: string = ''
  @Trace name: string = ''
  @Trace updateTime: number = 0
  @Trace avatarUrl: string = ''
  @Trace description: string = ''
  @Trace personality: string = ''
  @Trace scenario: string = ''
  @Trace firstMessage: string = ''
  @Trace exampleMessages: string = ''

  updateFrom(card: CharacterCard): void {
    this.id = card.id
    this.name = card.name
    this.updateTime = card.updateTime ?? 0
    this.avatarUrl = card.avatarUrl ?? ''
    this.description = card.description ?? ''
    this.personality = card.personality ?? ''
    this.scenario = card.scenario ?? ''
    this.firstMessage = card.firstMessage ?? ''
    this.exampleMessages = card.exampleMessages ?? ''
  }
}
