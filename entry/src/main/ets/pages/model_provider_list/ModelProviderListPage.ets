import { Route } from '@hzw/zrouter';
import {
  HdsListItem,
  HdsListItemCard,
  hdsMaterial,
  HdsNavDestination,
  IconSize,
  PrefixIcon,
  ScrollEffectType,
  SuffixIcon
} from '@kit.UIDesignKit';
import { FullPercent, symbolModifier } from 'common';
import { RouterName } from 'router';
import { ModelProviderListViewModel } from './ModelProviderListViewModel';
import { ModelProvider } from '../../store/model/ModelProvider';
import { ModelProviderListState } from './ModelProviderListState';
import { AppUtil } from '@pura/harmony-utils';

@Route({ name: RouterName.ModelProviderList })
@ComponentV2
export struct ModelProviderListPage {
  private readonly state = new ModelProviderListState()
  private readonly vm = new ModelProviderListViewModel(this.state)

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        Repeat<ModelProvider>(this.state.providers)
          .each((obj: RepeatItem<ModelProvider>) => {
            ModelProviderItem({
              repeat: obj,
              onProviderClick: () => this.vm.onProviderClick(obj.item),
              onProviderDelete: () => this.vm.onDeleteProvider(obj.item),
            })
          }).key((item: ModelProvider) => item.id + '_' + item.updateTime)
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
          value: [{
            content: {
              icon: symbolModifier($r("sys.symbol.plus"))
                .fontColor([$r('sys.color.font_primary')]),
              label: $r("app.string.add_model_provider"),
              action: () => this.vm.onAdd()
            }
          }]
        }
      },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE
        },
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        }
      }
    })
    .hideBackButton(false)
  }
}

@ComponentV2
struct ModelProviderItem {
  @Param @Require repeat: RepeatItem<ModelProvider>
  @Event onProviderClick: () => void
  @Event onProviderDelete: () => void

  build() {
    HdsListItem({
      customItemBuilder: () => this.customItemBuilder(),
      swipeActionOptions: {
        deleteIconOptions: {
          onAction: (): void => this.onProviderDelete()
        }
      }
    })
  }

  @Builder
  customItemBuilder() {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconValue: {
          symbol: symbolModifier($r("sys.symbol.cloud_and_arrow_up"))
            .fontColor([$r("sys.color.font_emphasize")])
        },
        iconSize: IconSize.SYSTEM_ICON
      }),
      textItem: {
        primaryText: {
          text: this.repeat.item.name,
        },
        secondaryText: {
          text: this.repeat.item.baseUrl,
        }
      },
      suffixItem: new SuffixIcon({
        iconValue: {
          symbol: symbolModifier($r("sys.symbol.chevron_right"))
            .fontColor([$r("sys.color.font_tertiary")])
        }
      }),
      onClick: (): void => this.onProviderClick()
    })
  }
}
