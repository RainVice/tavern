@ObservedV2
export class CharacterCardEditState {
  @Trace id: number = 0
  @Trace name: string = ''
  @Trace avatarUrl: string = ''
  @Trace description: string = ''
  @Trace personality: string = ''
  @Trace scenario: string = ''
  @Trace firstMessage: string = ''
  @Trace exampleMessages: string = ''
}
