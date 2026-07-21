import { PickerUtil } from '@pura/picker_utils';
import picker from '@ohos.file.picker';
import { RoleCardListState } from './RoleCardListState';
import { RoleCardStore } from '../../../tavern/role_card/RoleCardStore';

export class RoleCardListViewModel {
  private readonly state: RoleCardListState

  constructor(state: RoleCardListState) {
    this.state = state;
  }

  init(): void {
    this.refreshCardList();
  }

  /**
   * 重新读取应用私有目录中的角色卡列表。
   */
  refreshCardList(): void {
    this.state.cardList = RoleCardStore.instance().getCardList();
  }

  /**
   * 选择一张角色卡图片，读取其元数据并保存到应用私有角色卡目录。
   */
  async addRoleCard(): Promise<void> {
    const documentUris = await PickerUtil.selectDocument({
      maxSelectNumber: 1,
      fileSuffixFilters: ['PNG 图片|.png'],
      mergeMode: picker.MergeTypeMode.PICTURE
    })
    const pngUri = documentUris[0]
    if (!pngUri) {
      return
    }
    const roleCardStore = RoleCardStore.instance();
    const card = await roleCardStore.readCard(pngUri);
    if (card === undefined) {
      return;
    }
    const isWritten = await roleCardStore.writeCard(pngUri, card);
    if (isWritten) {
      this.refreshCardList();
    }
  }
}
