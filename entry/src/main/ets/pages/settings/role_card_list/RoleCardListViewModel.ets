import { PickerUtil } from '@pura/picker_utils';
import picker from '@ohos.file.picker';
import { RoleCardListState } from './RoleCardListState';
import { RoleCardStore } from '../../../tavern/role_card/RoleCardStore';

export class RoleCardListViewModel {
  private readonly state: RoleCardListState

  constructor(state: RoleCardListState) {
    this.state = state;
  }

  init() {

  }

  async addRoleCard() {
    const documentUris = await PickerUtil.selectDocument({
      maxSelectNumber: 1,
      fileSuffixFilters: ['PNG 图片|.png'],
      mergeMode: picker.MergeTypeMode.PICTURE
    })
    const pngUri = documentUris[0]
    if (!pngUri) {
      return
    }
    await RoleCardStore.instance().readCard(pngUri)
  }
}
