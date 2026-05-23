import { HdsListItem, HdsNavDestination, IconSize, PrefixIcon, SuffixIcon } from '@kit.UIDesignKit';
import { FullPercent, symbolModifier } from 'common';
import { Route, RouterName } from 'router';
import { SettingsViewModel } from './SettingsViewModel';

@Route({ name: RouterName.Settings })
@Component
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
                text: '模型提供商',
              },
            },
            suffixItem: new SuffixIcon({
              iconValue: {
                symbol: symbolModifier($r("sys.symbol.chevron_right"))
                  .fontColor([$r("sys.color.font_tertiary")])
              }
            })
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
