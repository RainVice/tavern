import { Route } from '@hzw/zrouter';
import { HdsListItem, HdsNavDestination, IconSize, PrefixIcon, ScrollEffectType, SuffixArrow } from '@kit.UIDesignKit';
import { AppUtil } from '@pura/harmony-utils';
import { FullPercent, symbolModifier } from 'common';
import { RouterName } from 'router';
import { SettingsViewModel } from './SettingsViewModel';

@Route({ name: RouterName.Settings })
@ComponentV2
export struct SettingsPage {
  private readonly vm = new SettingsViewModel();

  build() {
    HdsNavDestination() {
      List({ space: 10, }) {
        HdsListItem({
          hdsListItemCard: {
            prefixItem: new PrefixIcon({
              iconValue: {
                symbol: symbolModifier($r("sys.symbol.worldclock_fill_2")).fontColor([$r("sys.color.font_emphasize")])
              },
              iconSize: IconSize.SYSTEM_ICON
            }),
            textItem: { primaryText: { text: $r("app.string.model_provider"), }, },
            suffixItem: new SuffixArrow({ color: $r("sys.color.font_tertiary") }),
            onClick: (): void => {
              this.vm.onModelProviderClick()
            }
          }
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
      content: { title: { mainTitle: $r("app.string.settings") } },
      style: {
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        }
      }
    })
    .hideBackButton(true)
  }
}
