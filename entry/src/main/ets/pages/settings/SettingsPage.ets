import { HdsListItem, HdsNavDestination, IconSize, PrefixIcon, SuffixArrow } from '@kit.UIDesignKit';
import { FullPercent, symbolModifier } from 'common';
import { Route, RouterName } from 'router';
import { SettingsViewModel } from './SettingsViewModel';

@Route({ name: RouterName.Settings })
@ComponentV2
export struct SettingsPage {
  private readonly vm = new SettingsViewModel();

  build() {
    HdsNavDestination() {
      List({ space: 10, }) {
        ListItem().height(56)
        HdsListItem({
          hdsListItemCard: {
            prefixItem: new PrefixIcon({
              iconValue: {
                symbol: symbolModifier($r("sys.symbol.worldclock_fill_2"))
                  .fontColor([$r("sys.color.font_emphasize")])
              },
              iconSize: IconSize.SYSTEM_ICON
            }),
            textItem: {
              primaryText: {
                text: $r("app.string.model_provider"),
              },
            },
            suffixItem: new SuffixArrow({ color: $r("sys.color.font_tertiary") }),
            onClick: (): void => {
              this.vm.onModelProviderClick()
            }
          }
        })
      }
      .width(FullPercent)
      .height(FullPercent)
    }
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({ content: { title: { mainTitle: $r("app.string.settings") } } })
    .hideBackButton(true)
  }
}
