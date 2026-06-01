import { CharacterCard } from '../../store/model/CharacterCard'

@ObservedV2
export class CharacterCardDetailState {
  private param?: CharacterCard = undefined

  setParam(param?: CharacterCard): void {
    this.param = param
  }

  getParam(): CharacterCard | undefined {
    return this.param
  }

  getId(): number {
    return this.param?.id ?? 0
  }

  getName(): string {
    return this.param?.name ?? ''
  }

  getAvatarUrl(): string {
    return this.param?.avatarUrl ?? ''
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
    return this.param?.exampleMessages ?? ''
  }
}
