import { Route } from '@hzw/zrouter'
import { HdsListItem, HdsListItemCard, hdsMaterial, HdsNavDestination, IconSize, PrefixIcon, ScrollEffectType, SuffixIcon } from '@kit.UIDesignKit'
import { AppUtil } from '@pura/harmony-utils'
import { FullPercent, symbolModifier } from 'common'
import { RouterName, RVRouter } from 'router'
import type { WorldBookIndexEntry, WorldInfoEntry } from 'tavern_ohos'
import { WorldBookDetailState } from './WorldBookDetailState'
import { WorldBookDetailViewModel } from './WorldBookDetailViewModel'

@Route({ name: RouterName.WorldBookDetail })
@ComponentV2
export struct WorldBookDetailPage {
  private readonly state = new WorldBookDetailState()
  private readonly vm = new WorldBookDetailViewModel(this.state)

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.header() } } })
        if (this.state.book === undefined || this.state.book.entries.length === 0) {
          ListItem() {
            WorldBookEntryEmpty()
          }
        } else {
          Repeat<WorldInfoEntry>(this.state.book.entries)
            .each((obj: RepeatItem<WorldInfoEntry>) => {
              WorldBookEntryItem({
                entry: obj.item,
                onEntryClick: () => this.vm.onEditEntry(obj.item),
              })
            })
            .key((item: WorldInfoEntry) => item.id + '_' + item.updatedAt)
        }
      }
      .contentStartOffset(56 + this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
      .contentEndOffset(this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
      .width(FullPercent)
      .height(FullPercent)
    }
    .onBackPressed(() => {
      RVRouter.pop(true)
      return true
    })
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: $r("app.string.world_book_detail") },
        menu: {
          value: [
            {
              content: {
                icon: symbolModifier($r("sys.symbol.square_and_pencil"))
                  .fontColor([$r('sys.color.font_primary')]),
                label: $r("app.string.edit_world_book"),
                action: () => this.vm.onEditBook()
              }
            },
            {
              content: {
                icon: symbolModifier($r("sys.symbol.plus"))
                  .fontColor([$r('sys.color.font_primary')]),
                label: $r("app.string.add_world_info_entry"),
                action: () => this.vm.onAddEntry()
              }
            },
          ]
        }
      },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE
        },
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        }
      }
    })
    .hideBackButton(false)
  }

  @Builder
  private header() {
    Column({ space: 12 }) {
      Column() {
        SymbolGlyph($r("sys.symbol.book_pages_fill"))
          .fontSize(40)
          .fontColor([$r("sys.color.font_emphasize")])
      }
      .width(96)
      .height(96)
      .borderRadius(48)
      .backgroundColor($r("sys.color.comp_background_gray"))
      .justifyContent(FlexAlign.Center)

      Text(this.state.getName().length > 0 ? this.state.getName() : $r("app.string.world_book_unnamed"))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r("sys.color.font_primary"))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.state.getEntryCount().toString() + ' 个条目')
        .fontSize(14)
        .fontColor($r("sys.color.font_secondary"))
    }
    .alignItems(HorizontalAlign.Center)
    .width(FullPercent)
    .padding({ top: 16, bottom: 16 })
  }

  public static startWithParam(param: WorldBookIndexEntry, onPop?: () => void) {
    RVRouter.pushWithParam(RouterName.WorldBookDetail, param, onPop)
  }
}

@ComponentV2
struct WorldBookEntryItem {
  @Param @Require entry: WorldInfoEntry
  @Event onEntryClick: () => void

  build() {
    HdsListItem({
      customItemBuilder: () => this.customItemBuilder()
    })
  }

  @Builder
  private customItemBuilder() {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconValue: {
          symbol: symbolModifier(this.entry.enabled ? $r("sys.symbol.doc_text_fill") : $r("sys.symbol.doc_text"))
            .fontColor([this.entry.enabled ? $r("sys.color.font_emphasize") : $r("sys.color.font_tertiary")])
        },
        iconSize: IconSize.SYSTEM_ICON
      }),
      textItem: {
        primaryText: { text: this.entry.comment.length > 0 ? this.entry.comment : $r("app.string.world_info_entry_unnamed") },
        secondaryText: { text: this.summary() },
      },
      suffixItem: new SuffixIcon({
        iconValue: {
          symbol: symbolModifier($r("sys.symbol.chevron_right"))
            .fontColor([$r("sys.color.font_tertiary")])
        }
      }),
      onClick: (): void => this.onEntryClick(),
    })
  }

  private summary(): string {
    const keys = this.entry.keys.join(', ')
    const mode = this.entry.constant ? '常驻' : '关键词'
    const content = this.entry.content.length > 0 ? this.entry.content : '暂无内容'
    return mode + ' · ' + keys + ' · ' + content
  }
}

@ComponentV2
struct WorldBookEntryEmpty {
  build() {
    Column({ space: 12 }) {
      SymbolGlyph($r("sys.symbol.doc_text"))
        .fontSize(44)
        .fontColor([$r("sys.color.font_tertiary")])

      Text($r("app.string.world_info_entry_empty_title"))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r("sys.color.font_primary"))

      Text($r("app.string.world_info_entry_empty_description"))
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
