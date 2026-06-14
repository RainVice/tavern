import type { CharacterRecord } from 'tavern_ohos'

@ObservedV2
export class CharacterCardDetailState {
  @Trace private param?: CharacterRecord = undefined
  @Trace avatarUrl: string = ''

  setParam(param?: CharacterRecord): void {
    this.param = param
  }

  getParam(): CharacterRecord | undefined {
    return this.param
  }

  getId(): string {
    return this.param?.id ?? ''
  }

  getName(): string {
    return this.param?.name ?? ''
  }

  getAvatarUrl(): string {
    return this.avatarUrl
  }

  getDescription(): string {
    return this.param?.description ?? ''
  }

  getPersonality(): string {
    return this.param?.personality ?? ''
  }

  getScenario(): string {
    return this.param?.scenario ?? ''
  }

  getFirstMessage(): string {
    return this.param?.firstMessage ?? ''
  }

  getExampleMessages(): string {
    return this.param?.exampleDialogue ?? ''
  }
}
