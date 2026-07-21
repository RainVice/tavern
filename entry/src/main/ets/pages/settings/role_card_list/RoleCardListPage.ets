import { Route } from '@hzw/zrouter';
import picker from '@ohos.file.picker';
import { RouterName } from 'router';
import { RoleCardListState } from './RoleCardListState';
import { RoleCardListViewModel } from './RoleCardListViewModel';
import { HdsListItemCard, hdsMaterial, HdsNavDestination, PrefixImage, ScrollEffectType } from '@kit.UIDesignKit';
import { FullPercent } from 'common';
import { AppUtil, ToastUtil } from '@pura/harmony-utils';


@Route({ name: RouterName.RoleCardList })
@ComponentV2
export struct RoleCardListPage {
  private readonly state: RoleCardListState = new RoleCardListState();
  private readonly viewModel: RoleCardListViewModel = new RoleCardListViewModel(this.state);

  aboutToAppear(): void {
    this.viewModel.init();
  }

  /**
   * 选择 PNG 后直接进入新建页，让用户继续补充角色卡字段。
   *
   * DocumentViewPicker 使用当前 UIAbility 上下文创建，避免无参构造在部分设备上无法拉起选择器。
   */
  private async selectRoleCardImage(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      ToastUtil.showToast($r('app.string.character_card_image_select_failed'));
      return;
    }

    try {
      const options = new picker.DocumentSelectOptions();
      // 每次只选择一个 PNG，作为即将创建角色卡的头像源文件。
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = ['PNG 图片|.png'];
      options.mergeMode = picker.MergeTypeMode.PICTURE;
      const documentUris = await new picker.DocumentViewPicker(context).select(options);
      const imageUri = documentUris[0];
      if (imageUri !== undefined) {
        this.viewModel.addRoleCardWithImage(imageUri);
      }
    } catch (error) {
      ToastUtil.showToast($r('app.string.character_card_image_select_failed'));
    }
  }

  build() {
    HdsNavDestination() {
      if (this.state.cardList.length > 0) {
        List({ space: 8 }) {
          Repeat(this.state.cardList).each((repeat) => {
            ListItem() {
              HdsListItemCard({
                // 角色卡 PNG 同时就是头像图片，直接使用已保存的沙箱文件路径。
                prefixItem: new PrefixImage({
                  image: repeat.item.filePath
                }),
                textItem: {
                  primaryText: { text: `${repeat.item.name}（序号 ${repeat.item.index}）` },
                  secondaryText: { text: repeat.item.filePath },
                },
              })
              .onClick(() => this.viewModel.editRoleCard(repeat.item))
            }
          }).key((item) => item.filePath)
            .virtualScroll()
        }
        .contentStartOffset(56 + this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
        .contentEndOffset(this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
        .width(FullPercent)
        .height(FullPercent)
      } else {
        Column({ space: 8 }) {
          Text($r("app.string.character_card_empty_title"))
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
          Text($r("app.string.character_card_empty_description"))
            .fontColor($r("sys.color.font_secondary"))
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .width(FullPercent)
        .height(FullPercent)
      }
    }
    .backgroundColor($r("sys.color.background_secondary"))
    .hideBackButton(true)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: $r("app.string.role_card") },
        menu: {
          value: [
            {
              content: {
                icon: $r("sys.symbol.picture"),
                label: $r("app.string.select_character_card_image"),
                action: () => {
                  this.selectRoleCardImage();
                }
              }
            },
            {
              content: {
                icon: $r("sys.symbol.plus"),
                label: $r("app.string.add_character_card_directly"),
                action: () => this.viewModel.addRoleCard()
              }
            }
          ]
        }
      },
      style: {
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      },
    })
  }
}
