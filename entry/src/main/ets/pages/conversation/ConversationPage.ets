import { Route } from '@hzw/zrouter'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { AppUtil } from '@pura/harmony-utils'
import { FullPercent } from 'common'
import { RouterName, RVRouter } from 'router'
import type { ConversationPageParam } from './ConversationState'
import { ConversationState } from './ConversationState'
import { ConversationViewModel } from './ConversationViewModel'
import { LengthMetrics } from '@kit.ArkUI'
import type { ChatMessage } from 'tavern_ohos'

@Route({ name: RouterName.Conversation })
@ComponentV2
export struct ConversationPage {
  private readonly state = new ConversationState()
  private readonly vm = new ConversationViewModel(this.state)

  aboutToDisappear(): void {
    this.vm.dispose()
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        List({ space: 12 }) {
          if (this.state.messages.length === 0) {
            ListItem() {
              EmptyConversation()
            }
          } else {
            Repeat<ChatMessage>(this.state.messages)
              .each((obj: RepeatItem<ChatMessage>) => {
                ListItem() {
                  MessageBubble({ message: obj.item })
                }
              })
              .key((item: ChatMessage) => item.id + '_' + item.text.length)
          }
        }
        .contentStartOffset(this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
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
      content: { title: { mainTitle: $r("app.string.conversation") } },
      style: {
        systemMaterialEffect: { materialType: hdsMaterial.MaterialType.ADAPTIVE },
        scrollEffectOpts: { scrollEffectType: ScrollEffectType.GRADIENT_BLUR }
      }
    })
    .hideBackButton(false)
  }

  @Builder
  private inputBar() {
    this.inputBarContent(this.state.inputText)
  }

  @Builder
  private inputBarContent(inputText: string) {
    Row({ space: 4 }) {
      Button() {
        SymbolGlyph($r("sys.symbol.plus"))
          .fontColor([$r("sys.color.font_primary")])
      }.padding(8)
      .backgroundColor(Color.Transparent)

      TextArea({ text: inputText, placeholder: $r("app.string.conversation_input_placeholder") })
        .barState(BarState.Off)
        .padding(0)
        .borderRadius(0)
        .constraintSize({ maxHeight: 80 })
        .layoutWeight(1)
        .placeholderColor($r("sys.color.font_tertiary"))
        .fontColor($r("sys.color.font_primary"))
        .backgroundColor(Color.Transparent)
        .onChange((value: string) => this.vm.onInputChange(value))

      Button() {
        SymbolGlyph($r("sys.symbol.paperplane_right_fill"))
          .fontColor([$r("sys.color.font_on_primary")])
      }
      .padding(8)
      .enabled(inputText.trim().length > 0)
      .onClick(() => this.vm.onSend())
    }
    .alignItems(VerticalAlign.Center)
    .borderRadius(100)
    .backgroundColor($r("sys.color.comp_background_tertiary"))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      inactiveColor: $r("sys.color.background_fourth")
    }, { disableSystemAdaptation: true })
    .padding({
      start: LengthMetrics.vp(8),
      end: LengthMetrics.vp(8),
      top: LengthMetrics.vp(8),
      bottom: LengthMetrics.vp(8)
    })
    .margin({
      start: LengthMetrics.vp(12),
      end: LengthMetrics.vp(12),
      top: LengthMetrics.px(12),
      bottom: LengthMetrics.px(AppUtil.getNavigationIndicatorHeight()),
    })
  }

  public static startWithParam(param: ConversationPageParam, onPop?: () => void) {
    RVRouter.pushWithParam(RouterName.Conversation, param, onPop)
  }
}

@ComponentV2
struct MessageBubble {
  @Param @Require message: ChatMessage

  build() {
    this.content()
  }

  @Builder
  private content() {
    Row() {
      if (this.message.isUser) {
        Blank().layoutWeight(1)
      }
      Column({ space: 6 }) {
        Text(this.message.name.length > 0 ? this.message.name : MessageBubble.roleName(this.message))
          .fontSize(11)
          .fontColor($r("sys.color.font_tertiary"))
        Text(this.message.text.length > 0 ? this.message.text : $r("app.string.conversation_waiting_reply"))
          .fontSize(15)
          .fontColor(this.message.isUser ? $r("sys.color.font_on_primary") : $r("sys.color.font_primary"))
          .padding(12)
          .backgroundColor(this.message.isUser ? $r("sys.color.font_emphasize") : $r("sys.color.comp_background_tertiary"))
          .borderRadius(16)
      }
      .alignItems(this.message.isUser ? HorizontalAlign.End : HorizontalAlign.Start)
      .constraintSize({ maxWidth: '78%' })
      if (!this.message.isUser) {
        Blank().layoutWeight(1)
      }
    }
    .width(FullPercent)
  }

  private static roleName(message: ChatMessage): string {
    return message.isUser ? '你' : '助手'
  }
}

@ComponentV2
struct EmptyConversation {
  build() {
    Column({ space: 12 }) {
      SymbolGlyph($r("sys.symbol.message_fill"))
        .fontSize(44)
        .fontColor([$r("sys.color.font_tertiary")])

      Text($r("app.string.conversation_empty_title"))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r("sys.color.font_primary"))

      Text($r("app.string.conversation_empty_description"))
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
