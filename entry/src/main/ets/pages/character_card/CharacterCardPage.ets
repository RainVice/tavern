import { Route } from '@hzw/zrouter'
import {
  HdsListItem,
  HdsListItemCard,
  hdsMaterial,
  HdsNavDestination,
  IconSize,
  PrefixIcon,
  ScrollEffectType,
  SuffixIcon
} from '@kit.UIDesignKit'
import { FullPercent, symbolModifier } from 'common'
import { RouterName } from 'router'
import { CharacterCardViewModel } from './CharacterCardViewModel'
import { CharacterCardListState } from './CharacterCardListState'
import { AppUtil } from '@pura/harmony-utils'
import type { CharacterRecord } from 'tavern_ohos'

@Route({ name: RouterName.CharacterCard })
@ComponentV2
export struct CharacterCardPage {
  private readonly state = new CharacterCardListState()
  private readonly vm = new CharacterCardViewModel(this.state)

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        Repeat<CharacterRecord>(this.state.cards)
          .each((obj: RepeatItem<CharacterRecord>) => {
            CharacterCardItem({
              repeat: obj,
              onCardClick: () => this.vm.onCardClick(obj.item),
              onCardDelete: () => this.vm.onDeleteCard(obj.item)
            })
          }).key((item: CharacterRecord) => item.id + '_' + item.updatedAt)
          .virtualScroll()
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
        title: { mainTitle: $r("app.string.character_card") },
        menu: {
          value: [{
            content: {
              icon: symbolModifier($r("sys.symbol.plus"))
                .fontColor([$r('sys.color.font_primary')]),
              label: $r("app.string.add_character_card"),
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
struct CharacterCardItem {
  @Param @Require repeat: RepeatItem<CharacterRecord>
  @Event onCardClick: () => void
  @Event onCardDelete: () => void

  build() {
    HdsListItem({
      customItemBuilder: () => this.customItemBuilder(),
      swipeActionOptions: {
        deleteIconOptions: {
          onAction: (): void => this.onCardDelete()
        }
      }
    })
  }

  @Builder
  customItemBuilder() {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconValue: {
          symbol: symbolModifier($r("sys.symbol.person_fill"))
            .fontColor([$r("sys.color.font_emphasize")])
        },
        iconSize: IconSize.SYSTEM_ICON
      }),
      textItem: {
        primaryText: { text: this.repeat.item.name },
        secondaryText: {
          text: this.repeat.item.description.length > 0 ? this.repeat.item.description : this.repeat.item.personality,
        }
      },
      suffixItem: new SuffixIcon({
        iconValue: {
          symbol: symbolModifier($r("sys.symbol.chevron_right"))
            .fontColor([$r("sys.color.font_tertiary")])
        }
      }),
      onClick: (): void => this.onCardClick(),
    })
  }
}
