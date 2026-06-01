import { CharacterCard } from '../../store/model/CharacterCard'

@ObservedV2
export class ChatState {
  private param?: CharacterCard = undefined
  @Trace inputText: string = ''
}
