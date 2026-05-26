import { Route } from '@hzw/zrouter'
import {
  HdsListItem, hdsMaterial, HdsNavDestination, PrefixImage, SuffixIcon
} from '@kit.UIDesignKit'
import { FullPercent, symbolModifier } from 'common'
import { RouterName } from 'router'
import { CharacterCardViewModel } from './CharacterCardViewModel'
import { CharacterCardListState } from './CharacterCardListState'
import { CharacterCard } from '../../store/model/CharacterCard'
import { util } from '@kit.ArkTS'
import { ImageModifier } from '@kit.ArkUI'
import { JSONUtil } from '@pura/harmony-utils'

@Route({ name: RouterName.CharacterCard })
@ComponentV2
export struct CharacterCardPage {
  private readonly state = new CharacterCardListState()
  private readonly vm = new CharacterCardViewModel(this.state)

  aboutToAppear(): void {
    this.vm.loadCards()
  }

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        ListItem().height(56)
        Repeat<CharacterCard>(this.state.cards)
          .each((obj: RepeatItem<CharacterCard>) => {
            HdsListItem({
              hdsListItemCard: {
                prefixItem: new PrefixImage({
                  image: obj.item.avatarUrl,
                  modifier: new ImageModifier().size({width: 40, height: 40})
                }),
                textItem: {
                  primaryText: { text: obj.item.name },
                  secondaryText: {
                    text: obj.item.description ?? obj.item.personality ?? '',
                  }
                },
                suffixItem: new SuffixIcon({
                  iconValue: {
                    symbol: symbolModifier($r("sys.symbol.chevron_right"))
                      .fontColor([$r("sys.color.font_tertiary")])
                  }
                }),
                onClick: (): void => {
                  this.vm.onCardClick(obj.index)
                }
              }
            })
          }).key((item: CharacterCard) => item.id + '_' + item.updateTime)
      }
      .width(FullPercent)
      .height(FullPercent)
    }
    .onShown(() => {
      this.vm.loadCards()
    })
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
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
        }
      }
    })
    .hideBackButton(true)
  }
}
