import { Route } from '@hzw/zrouter';
import {
  HdsListItem,
  hdsMaterial,
  HdsNavDestination,
  IconSize,
  PrefixIcon,
  SuffixIcon
} from '@kit.UIDesignKit';
import { FullPercent, symbolModifier } from 'common';
import { RouterName } from 'router';
import { ModelProviderListViewModel } from './ModelProviderListViewModel';
import { ModelProvider } from '../../store/model/ModelProvider';
import { ModelProviderListState } from './ModelProviderListState';

@Route({ name: RouterName.ModelProviderList })
@ComponentV2
export struct ModelProviderListPage {
  private readonly state = new ModelProviderListState()
  private readonly vm = new ModelProviderListViewModel(this.state)

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        ListItem().height(56)
        Repeat<ModelProvider>(this.state.providers)
          .each((obj: RepeatItem<ModelProvider>) => {
            HdsListItem({
              hdsListItemCard: {
                prefixItem: new PrefixIcon({
                  iconValue: {
                    symbol: symbolModifier($r("sys.symbol.cloud_and_arrow_up"))
                      .fontColor([$r("sys.color.font_emphasize")])
                  },
                  iconSize: IconSize.SYSTEM_ICON
                }),
                textItem: {
                  primaryText: {
                    text: obj.item.name,
                  },
                  secondaryText: {
                    text: obj.item.baseUrl,
                  }
                },
                suffixItem: new SuffixIcon({
                  iconValue: {
                    symbol: symbolModifier($r("sys.symbol.chevron_right"))
                      .fontColor([$r("sys.color.font_tertiary")])
                  }
                }),
                onClick: (): void => {
                  this.vm.onProviderClick(obj.index)
                }
              },
              swipeActionOptions: {
                deleteIconOptions: {
                  onAction: (): void => this.vm.onDeleteProvider(obj.index)
                }
              }
            })
          }).key((item: ModelProvider) => item.id + '_' + item.updateTime)
          .virtualScroll()
      }
      .width(FullPercent)
      .height(FullPercent)
    }
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
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
        }
      }
    })
    .hideBackButton(false)
  }
}
