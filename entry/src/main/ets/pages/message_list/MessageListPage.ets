import { Route } from '@hzw/zrouter'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { AppUtil } from '@pura/harmony-utils'
import { FullPercent } from 'common'
import { RouterName } from 'router'

@Route({ name: RouterName.MessageList })
@ComponentV2
export struct MessageListPage {
  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        ListItem() {
          MessageListEmpty()
        }
      }
      .contentStartOffset(56 + this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
      .contentEndOffset(this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
      .width(FullPercent)
      .height(FullPercent)
      .padding({ left: 12, right: 12 })
    }
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r("app.string.message_list") } },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE
        },
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        }
      }
    })
    .hideBackButton(true)
  }
}

@ComponentV2
struct MessageListEmpty {
  build() {
    Column({ space: 12 }) {
      SymbolGlyph($r("sys.symbol.message_fill"))
        .fontSize(44)
        .fontColor([$r("sys.color.font_tertiary")])

      Text($r("app.string.message_list_empty_title"))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r("sys.color.font_primary"))

      Text($r("app.string.message_list_empty_description"))
        .fontSize(14)
        .fontColor($r("sys.color.font_secondary"))
        .textAlign(TextAlign.Center)
        .width(240)
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .width(FullPercent)
    .height(360)
  }
}
