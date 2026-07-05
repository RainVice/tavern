import { Route } from '@hzw/zrouter';
import { RouterName } from 'router';
import { HdsListItem, HdsListItemCard, hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { FullPercent } from 'common';
import { AppUtil } from '@pura/harmony-utils';
import { ProviderListViewModel } from './ProviderListViewModel';
import { Provider } from '../../../tavern/setting/provider/ProviderStore';

@Route({ name: RouterName.ProviderList })
@Component
export struct ProviderListPage {
  private readonly viewModel = new ProviderListViewModel()

  aboutToAppear(): void {
    this.viewModel.init()
  }

  build() {
    HdsNavDestination() {
      List() {
        Repeat(this.viewModel.providerList).each((repeat) => {
          HdsListItem({ customItemBuilder: () => this.listItemCard(repeat) })
        })
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
        title: { mainTitle: $r("app.string.model_list") },
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

  @LocalBuilder
  private listItemCard(repeat: RepeatItem<Provider>): void {
    HdsListItemCard({
      textItem: {
        primaryText: { text: repeat.item.name },
        secondaryText: { text: repeat.item.baseUrl },
      },
    }).onClick(() => this.viewModel.onProviderList(repeat.item))
  }
}