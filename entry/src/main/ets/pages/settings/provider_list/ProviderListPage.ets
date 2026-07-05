import { Route } from '@hzw/zrouter';
import { RouterName } from 'router';
import { HdsListItemCard, hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { FullPercent } from 'common';
import { AppUtil } from '@pura/harmony-utils';
import { ProviderListViewModel } from './ProviderListViewModel';

@Route({ name: RouterName.ProviderList })
@ComponentV2
export struct ProviderListPage {
  private readonly viewModel = new ProviderListViewModel()

  aboutToAppear(): void {
    this.viewModel.init()
  }

  build() {
    HdsNavDestination() {
      List({ space: 8 }) {
        Repeat(this.viewModel.providerList).each((repeat) => {
          ListItem() {
            HdsListItemCard({
              textItem: {
                primaryText: { text: repeat.item.name },
                secondaryText: { text: repeat.item.baseUrl },
              },
            }).onClick(() => this.viewModel.onProviderList(repeat.item))
          }
        }).key((item) => `${item.id}-${item.name}`)
          .virtualScroll()
      }
      .contentStartOffset(56 + this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
      .contentEndOffset(this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
      .width(FullPercent)
      .height(FullPercent)
    }
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: $r("app.string.model_provider") },
        menu: {
          value: [
            {
              content: {
                icon: $r("sys.symbol.plus"),
                label: $r("app.string.add_model_provider"),
                action: () => this.viewModel.onAddProviderList()
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
