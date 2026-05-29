import { Route } from '@hzw/zrouter'
import { hdsMaterial, HdsNavDestination } from '@kit.UIDesignKit'
import { FullPercent } from 'common'
import { RouterName } from 'router'

@Route({ name: RouterName.MessageList })
@ComponentV2
export struct MessageListPage {
  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        ListItem().height(56)
        ListItem() {
          MessageListEmpty()
        }
      }
      .width(FullPercent)
      .height(FullPercent)
      .padding({ left: 12, right: 12 })
    }
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
      content: { title: { mainTitle: $r("app.string.message_list") } },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE
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
