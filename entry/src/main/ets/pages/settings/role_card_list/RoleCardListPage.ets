import { Route } from '@hzw/zrouter';
import { RouterName } from 'router';
import { RoleCardListState } from './RoleCardListState';
import { RoleCardListViewModel } from './RoleCardListViewModel';
import { HdsListItemCard, hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { FullPercent } from 'common';
import { AppUtil } from '@pura/harmony-utils';


@Route({ name: RouterName.RoleCardList })
@ComponentV2
export struct RoleCardListPage {
  private readonly state: RoleCardListState = new RoleCardListState();
  private readonly viewModel: RoleCardListViewModel = new RoleCardListViewModel(this.state);

  aboutToAppear(): void {
    this.viewModel.init();
  }

  build() {
    HdsNavDestination() {
      if (this.state.cardList.length > 0) {
        List({ space: 8 }) {
          Repeat(this.state.cardList).each((repeat) => {
            ListItem() {
              HdsListItemCard({
                textItem: {
                  primaryText: { text: `${repeat.item.name}（序号 ${repeat.item.index}）` },
                  secondaryText: { text: repeat.item.filePath },
                },
              })
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
        .padding({ top: 56 + this.getUIContext().px2vp(AppUtil.getStatusBarHeight()) })
      }
    }
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: $r("app.string.role_card") },
        menu: {
          value: [{
            content: {
              icon: $r("sys.symbol.plus"),
              label: $r("app.string.add_character_card"),
              action: () => {
                this.viewModel.addRoleCard();
              }
            }
          }]
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
