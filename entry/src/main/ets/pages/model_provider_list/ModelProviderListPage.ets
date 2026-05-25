import { Route } from '@hzw/zrouter';
import { HdsListItem, hdsMaterial, HdsNavDestination, IconSize, PrefixIcon, SuffixIcon } from '@kit.UIDesignKit';
import { FullPercent, symbolModifier } from 'common';
import {  RouterName } from 'router';
import { ModelProviderListViewModel } from './ModelProviderListViewModel';

@Route({ name: RouterName.ModelProviderList })
@ComponentV2
export struct ModelProviderListPage {
  private readonly vm = new ModelProviderListViewModel();

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        ListItem().height(56)
        ForEach(this.vm.providers, (item: ModelProviderItem, index: number) => {
          HdsListItem({
            hdsListItemCard: {
              prefixItem: new PrefixIcon({
                iconValue: {
                  symbol: symbolModifier($r("sys.symbol.gearshape"))
                    .fontColor([$r("sys.color.font_emphasize")])
                },
                iconSize: IconSize.SYSTEM_ICON
              }),
              textItem: {
                primaryText: {
                  text: item.name,
                },
                secondaryText: {
                  text: item.apiType,
                }
              },
              suffixItem: new SuffixIcon({
                iconValue: {
                  symbol: symbolModifier($r("sys.symbol.chevron_right"))
                    .fontColor([$r("sys.color.font_tertiary")])
                }
              }),
              onClick: (): void => {
                this.vm.onProviderClick(index)
              }
            }
          })
        })
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

interface ModelProviderItem {
  name: string;
  apiType: string;
}
