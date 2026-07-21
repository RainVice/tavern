import { RoleCardListItem } from '../../../tavern/role_card/RoleCardStore';

@ObservedV2
export class RoleCardListState {
  /**
   * 角色卡存储目录中已保存的角色卡。
   */
  @Trace cardList: RoleCardListItem[] = [];
}
