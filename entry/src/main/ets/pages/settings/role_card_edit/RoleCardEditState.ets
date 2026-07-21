import { CharacterCard, RoleCardListItem } from '../../../tavern/role_card/RoleCardStore';

/**
 * 角色卡编辑页的路由参数。
 *
 * roleCard 用于编辑已有角色卡；imageUri 用于以用户刚选择的 PNG 作为新角色卡头像。
 */
export interface RoleCardEditRouteParam {
  roleCard?: RoleCardListItem;
  imageUri?: string;
}

@ObservedV2
export class RoleCardEditState {
  /** 是否正在编辑一个已经保存的角色卡。 */
  @Trace editing: boolean = false;
  /** 当前选择的头像路径；为空时使用默认头像。 */
  @Trace imageUri: string = '';
  /** 角色名称。 */
  @Trace name: string = '';
  /** 角色描述。 */
  @Trace description: string = '';
  /** 性格设定。 */
  @Trace personality: string = '';
  /** 场景设定。 */
  @Trace scenario: string = '';
  /** 开场白。 */
  @Trace firstMessage: string = '';
  /** 对话示例。 */
  @Trace exampleMessages: string = '';
  /** 编辑前角色卡在应用沙箱中的文件路径。 */
  originalCardFilePath: string = '';
  /**
   * 原始完整角色卡，用于保存时保留当前页面未编辑的 V3 字段。
   */
  private card: CharacterCard = new CharacterCard();

  /**
   * 初始化添加场景。
   */
  reset(): void {
    this.editing = false;
    this.imageUri = '';
    this.originalCardFilePath = '';
    this.card = new CharacterCard();
    this.name = '';
    this.description = '';
    this.personality = '';
    this.scenario = '';
    this.firstMessage = '';
    this.exampleMessages = '';
  }

  /**
   * 初始化编辑场景，并将完整角色卡与页面基础字段分开保存。
   *
   * @param item 列表中被选择的角色卡文件。
   * @param card 从该文件读取到的当前角色卡。
   */
  setRoleCard(item: RoleCardListItem, card: CharacterCard): void {
    this.editing = true;
    this.imageUri = item.filePath;
    this.originalCardFilePath = item.filePath;
    this.card = card;
    this.name = card.data.name;
    this.description = card.data.description;
    this.personality = card.data.personality;
    this.scenario = card.data.scenario;
    this.firstMessage = card.data.first_mes;
    this.exampleMessages = card.data.mes_example;
  }

  /**
   * 将页面中的基础字段写回完整角色卡模型。
   *
   * @returns 用于写入 PNG 元数据的当前角色卡模型。
   */
  toCharacterCard(): CharacterCard {
    this.card.data.name = this.name;
    this.card.data.description = this.description;
    this.card.data.personality = this.personality;
    this.card.data.scenario = this.scenario;
    this.card.data.first_mes = this.firstMessage;
    this.card.data.mes_example = this.exampleMessages;
    return this.card;
  }
}
