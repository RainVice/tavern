import { Route } from '@hzw/zrouter'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { AppUtil } from '@pura/harmony-utils'
import { FullPercent } from 'common'
import { RouterName } from 'router'
import { ChatMessageItem, ChatRole, ChatState } from './ChatState'
import { ChatViewModel } from './ChatViewModel'
import { LengthMetrics } from '@kit.ArkUI'

@Route({ name: RouterName.Chat })
@ComponentV2
export struct ChatPage {
  private readonly state = new ChatState()
  private readonly vm = new ChatViewModel(this.state)

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        List({ space: 12 }) {
          if (this.state.messages.length === 0) {
            ListItem() {
              EmptyConversation()
            }
          } else {
            Repeat<ChatMessageItem>(this.state.messages)
              .each((obj: RepeatItem<ChatMessageItem>) => {
                ChatMessageBubble({ message: obj.item })
              })
              .key((item: ChatMessageItem) => item.id)
              .virtualScroll()
          }
        }
        .contentStartOffset(56 + this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
        .contentEndOffset(112 + this.getUIContext().px2vp(AppUtil.getNavigationIndicatorHeight()))
        .width(FullPercent)
        .height(FullPercent)
        .padding({ start: LengthMetrics.vp(12), end: LengthMetrics.vp(12) })

        this.inputBar()
      }
      .width(FullPercent)
      .height(FullPercent)
    }
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r("app.string.chat") } },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE
        },
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        }
      }
    })
    .hideBackButton(true)
  }

  @Builder
  private inputBar() {
    Column() {
      Row({ space: 8 }) {
        Row({ space: 4 }) {
          Button() {
            SymbolGlyph($r("sys.symbol.plus"))
              .fontSize(22)
              .fontColor([$r("sys.color.font_secondary")])
          }
          .width(36)
          .height(36)
          .borderRadius(18)
          .backgroundColor(Color.Transparent)

          TextInput({ placeholder: $r("app.string.chat_input_placeholder") })
            .layoutWeight(1)
            .height(42)
            .padding({ start: LengthMetrics.vp(0), end: LengthMetrics.vp(0) })
            .fontSize(15)
            .fontColor($r("sys.color.font_primary"))
            .placeholderColor($r("sys.color.font_tertiary"))
            .backgroundColor(Color.Transparent)
            .onChange((value: string) => this.vm.onInputChange(value))
        }
        .height(48)
        .layoutWeight(1)
        .padding({ start: LengthMetrics.vp(6), end: LengthMetrics.vp(12) })
        .borderRadius(24)
        .border({ width: 0.5, color: '#1A000000' })
        .shadow({
          radius: 14,
          color: '#12000000',
          offsetX: 0,
          offsetY: 4
        })
        .backgroundColor($r("sys.color.background_primary"))

        Button() {
          SymbolGlyph($r("sys.symbol.message_fill"))
            .fontSize(20)
            .fontColor([$r("sys.color.font_on_primary")])
        }
        .width(48)
        .height(48)
        .borderRadius(24)
        .shadow({
          radius: 14,
          color: '#24000000',
          offsetX: 0,
          offsetY: 4
        })
        .backgroundColor($r("sys.color.font_emphasize"))
        .onClick(() => this.vm.onSend())
      }
      .width(FullPercent)
    }
    .width(FullPercent)
    .padding({
      start: LengthMetrics.vp(12),
      end: LengthMetrics.vp(12),
      top: LengthMetrics.px(12),
      bottom: LengthMetrics.px(AppUtil.getNavigationIndicatorHeight()),
    })
  }
}

@ComponentV2
struct EmptyConversation {
  build() {
    Column({ space: 12 }) {
      SymbolGlyph($r("sys.symbol.message_fill"))
        .fontSize(44)
        .fontColor([$r("sys.color.font_tertiary")])

      Text($r("app.string.chat_empty_title"))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r("sys.color.font_primary"))

      Text($r("app.string.chat_empty_description"))
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

@ComponentV2
struct ChatMessageBubble {
  @Require @Param message: ChatMessageItem

  build() {
    Row() {
      if (this.message.role === ChatRole.User) {
        Blank()
        this.bubble($r("sys.color.font_emphasize"), $r("sys.color.font_on_primary"))
      } else {
        this.bubble($r("sys.color.comp_background_gray"), $r("sys.color.font_primary"))
        Blank()
      }
    }
    .width(FullPercent)
  }

  @Builder
  private bubble(backgroundColor: ResourceColor, fontColor: ResourceColor) {
    Column({ space: 6 }) {
      Text(this.message.content)
        .fontSize(15)
        .fontColor(fontColor)

      Text(this.message.time)
        .fontSize(11)
        .fontColor($r("sys.color.font_tertiary"))
    }
    .alignItems(HorizontalAlign.Start)
    .constraintSize({ maxWidth: 280 })
    .padding({
      start: LengthMetrics.vp(12),
      end: LengthMetrics.vp(12),
      top: LengthMetrics.vp(10),
      bottom: LengthMetrics.vp(10)
    })
    .borderRadius(8)
    .backgroundColor(backgroundColor)
  }
}
