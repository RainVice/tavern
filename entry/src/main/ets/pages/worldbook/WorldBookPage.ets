import { Route } from '@hzw/zrouter';
import {
  HdsListItem,
  HdsListItemCard,
  hdsMaterial,
  HdsNavDestination,
  IconSize,
  PrefixIcon,
  ScrollEffectType,
  SuffixIcon,
} from '@kit.UIDesignKit';
import { AppUtil } from '@pura/harmony-utils';
import { FullPercent, symbolModifier } from 'common';
import { RouterName } from 'router';
import type { WorldBookIndexEntry } from 'tavern_ohos';
import { WorldBookState } from './WorldBookState';
import { WorldBookViewModel } from './WorldBookViewModel';

@Route({ name: RouterName.WorldBook })
@ComponentV2
export struct WorldBookPage {
  private readonly state = new WorldBookState()
  private readonly vm = new WorldBookViewModel(this.state)

  aboutToAppear(): void {
    this.vm.loadBooks()
  }

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        if (this.state.books.length === 0) {
          ListItem() {
            WorldBookEmpty()
          }
        } else {
          Repeat<WorldBookIndexEntry>(this.state.books)
            .each((obj: RepeatItem<WorldBookIndexEntry>) => {
              WorldBookItem({
                book: obj.item,
                onDelete: () => this.vm.onDelete(obj.item),
              })
            })
            .key((item: WorldBookIndexEntry) => item.id + '_' + item.updatedAt)
        }
      }
      .contentStartOffset(56 + this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
      .contentEndOffset(this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
      .width(FullPercent)
      .height(FullPercent)
    }
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: $r("app.string.world_book") },
        menu: {
          value: [{
            content: {
              icon: symbolModifier($r("sys.symbol.plus"))
                .fontColor([$r('sys.color.font_primary')]),
              label: $r("app.string.add_world_book"),
              action: () => this.vm.onAdd()
            }
          }]
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
    .hideBackButton(true)
  }
}

@ComponentV2
struct WorldBookItem {
  @Param @Require book: WorldBookIndexEntry
  @Event onDelete: () => void

  build() {
    this.content()
  }

  @Builder
  private content() {
    HdsListItem({
      customItemBuilder: () => this.customItemBuilder(),
      swipeActionOptions: {
        deleteIconOptions: {
          onAction: (): void => this.onDelete()
        }
      }
    })
  }

  @Builder
  private customItemBuilder() {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconValue: {
          symbol: symbolModifier($r("sys.symbol.book_pages_fill_1"))
            .fontColor([$r("sys.color.font_emphasize")])
        },
        iconSize: IconSize.SYSTEM_ICON
      }),
      textItem: {
        primaryText: { text: this.book.name },
        secondaryText: { text: this.book.entryCount.toString() + ' 个条目' },
      },
      suffixItem: new SuffixIcon({
        iconValue: {
          symbol: symbolModifier($r("sys.symbol.chevron_right"))
            .fontColor([$r("sys.color.font_tertiary")])
        }
      }),
    })
  }
}

@ComponentV2
struct WorldBookEmpty {
  build() {
    Column({ space: 12 }) {
      SymbolGlyph($r("sys.symbol.book_pages_fill_1"))
        .fontSize(44)
        .fontColor([$r("sys.color.font_tertiary")])

      Text($r("app.string.world_book_empty_title"))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r("sys.color.font_primary"))

      Text($r("app.string.world_book_empty_description"))
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
