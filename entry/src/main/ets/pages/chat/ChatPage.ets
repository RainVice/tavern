import { Route } from '@hzw/zrouter'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { AppUtil } from '@pura/harmony-utils'
import { FullPercent } from 'common'
import { RouterName } from 'router'
import { ChatMessageItem, ChatRole, ChatState } from './ChatState'
import { ChatViewModel } from './ChatViewModel'

@Route({ name: RouterName.Chat })
@ComponentV2
export struct ChatPage {
  private readonly state = new ChatState()
  private readonly vm = new ChatViewModel(this.state)

  build() {
    HdsNavDestination() {
      Column() {
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
        .contentEndOffset(this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
        .layoutWeight(1)
        .width(FullPercent)
        .padding({ left: 12, right: 12 })

        Row({ space: 8 }) {
          TextInput({ placeholder: $r("app.string.chat_input_placeholder") })
            .layoutWeight(1)
            .height(44)
            .padding({ left: 12, right: 12 })
            .borderRadius(8)
            .backgroundColor($r("sys.color.background_tertiary"))
            .onChange((value: string) => this.vm.onInputChange(value))

          Button() {
            SymbolGlyph($r("sys.symbol.message_fill"))
              .fontSize(20)
              .fontColor([$r("sys.color.font_on_primary")])
          }
          .width(44)
          .height(44)
          .borderRadius(8)
          .backgroundColor($r("sys.color.font_emphasize"))
          .onClick(() => this.vm.onSend())
        }
        .width(FullPercent)
        .padding({ left: 12, right: 12, top: 10, bottom: 96 })
        .backgroundColor($r("sys.color.background_secondary"))
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
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        }
      }
    })
    .hideBackButton(true)
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
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(8)
    .backgroundColor(backgroundColor)
  }
}
