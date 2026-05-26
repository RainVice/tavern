import { RouterName, RVRouter } from 'router'

export class CharacterCardViewModel {
  onAdd() {
    RVRouter.push(RouterName.AddCharacterCard)
  }
}