import { RoleCardListState } from './RoleCardListState';
import { RoleCardListItem, RoleCardStore } from '../../../tavern/role_card/RoleCardStore';
import { RoleCardEditPage } from '../role_card_edit/RoleCardEditPage';

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
   * 使用用户刚选择的 PNG 打开新建角色卡编辑页。
   */
  addRoleCardWithImage(imageUri: string): void {
    RoleCardEditPage.start({
      imageUri: imageUri,
      onPop: () => this.refreshCardList()
    });
  }

  /**
   * 直接打开空白角色卡编辑页；保存时未选择头像则使用默认头像。
   */
  addRoleCard(): void {
    RoleCardEditPage.start({ onPop: () => this.refreshCardList() });
  }

  /**
   * 打开编辑角色卡页面。
   *
   * @param roleCard 列表中被点击的角色卡。
   */
  editRoleCard(roleCard: RoleCardListItem): void {
    RoleCardEditPage.start({
      roleCard: roleCard,
      onPop: () => this.refreshCardList()
    });
  }
}
