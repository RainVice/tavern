import { Route } from '@hzw/zrouter'
import { LengthMetrics } from '@kit.ArkUI'
import {
  HdsListItem,
  HdsListItemCard,
  hdsMaterial,
  HdsNavDestination,
  IconSize,
  PrefixIcon,
  ScrollEffectType,
  SuffixIcon,
} from '@kit.UIDesignKit'
import { AppUtil } from '@pura/harmony-utils'
import { FullPercent, symbolModifier } from 'common'
import { RouterName } from 'router'
import type { ChatIndexEntry } from 'tavern_ohos'
import { MessageListState } from './MessageListState'
import { MessageListViewModel } from './MessageListViewModel'

@Route({ name: RouterName.MessageList })
@ComponentV2
export struct MessageListPage {
  private readonly state = new MessageListState()
  private readonly vm = new MessageListViewModel(this.state)

  aboutToAppear(): void {
    this.vm.loadChats()
  }

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        if (this.state.chats.length === 0) {
          ListItem() {
            MessageListEmpty()
          }
        } else {
          Repeat<ChatIndexEntry>(this.state.chats)
            .each((obj: RepeatItem<ChatIndexEntry>) => {
              ChatListItem({
                chat: obj.item,
                onChatClick: () => this.vm.onChatClick(obj.item),
              })
            })
            .key((item: ChatIndexEntry) => item.id + '_' + item.updatedAt)
        }
      }
      .contentStartOffset(56 + this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
      .contentEndOffset(this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
      .width(FullPercent)
      .height(FullPercent)
      .padding({ start: LengthMetrics.vp(12), end: LengthMetrics.vp(12) })
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
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        }
      }
    })
    .hideBackButton(true)
  }
}

@ComponentV2
struct ChatListItem {
  @Param @Require chat: ChatIndexEntry
  @Event onChatClick: () => void

  build() {
    this.content()
  }

  @Builder
  private content() {
    HdsListItem({
      customItemBuilder: () => this.customItemBuilder()
    })
  }

  @Builder
  private customItemBuilder() {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconValue: {
          symbol: symbolModifier($r("sys.symbol.message_fill"))
            .fontColor([$r("sys.color.font_emphasize")])
        },
        iconSize: IconSize.SYSTEM_ICON
      }),
      textItem: {
        primaryText: { text: this.chat.title },
        secondaryText: { text: this.chat.previewMessage.length > 0 ? this.chat.previewMessage : this.chat.characterId },
      },
      suffixItem: new SuffixIcon({
        iconValue: {
          symbol: symbolModifier($r("sys.symbol.chevron_right"))
            .fontColor([$r("sys.color.font_tertiary")])
        }
      }),
      onClick: (): void => this.onChatClick(),
    })
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
