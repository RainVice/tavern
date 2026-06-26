import { Route } from '@hzw/zrouter'
import { LengthMetrics } from '@kit.ArkUI'
import { HdsListItem, hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { AppUtil } from '@pura/harmony-utils'
import { FullPercent, symbolModifier } from 'common'
import { RouterName, RVRouter } from 'router'
import type { WorldBookIndexEntry } from 'tavern_ohos'
import { WorldBookEditState } from './WorldBookEditState'
import { WorldBookEditViewModel } from './WorldBookEditViewModel'

@Route({ name: RouterName.WorldBookEdit })
@ComponentV2
export struct WorldBookEditPage {
  private readonly state = new WorldBookEditState()
  private readonly vm = new WorldBookEditViewModel(this.state)

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.nameInput() } } })
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
        title: { mainTitle: this.state.id.length > 0 ? $r("app.string.edit_world_book") : $r("app.string.add_world_book") },
        menu: {
          value: [{
            content: {
              icon: symbolModifier($r("sys.symbol.checkmark")).fontColor([$r('sys.color.font_primary')]),
              label: $r("app.string.save"),
              action: () => this.vm.onSave()
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
    .hideBackButton(false)
  }

  @Builder
  private nameInput() {
    WorldBookInput({
      text: this.state.name!!,
      title: $r("app.string.world_book_name"),
      placeholder: $r("app.string.world_book_name_placeholder"),
    })
  }

  public static start(onPop?: () => void) {
    RVRouter.push(RouterName.WorldBookEdit, onPop)
  }

  public static startWithParam(param: WorldBookIndexEntry, onPop?: () => void) {
    RVRouter.pushWithParam(RouterName.WorldBookEdit, param, onPop)
  }
}

@ComponentV2
struct WorldBookInput {
  @Param text: ResourceStr = ""
  @Event $text: (text: string) => void = () => {
  }
  @Param title: ResourceStr = ""
  @Param placeholder: ResourceStr = ""

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontSize(12)
        .fontColor($r("sys.color.font_secondary"))
        .padding({ start: LengthMetrics.vp(8) })

      TextInput({ text: this.text, placeholder: this.placeholder })
        .padding(8)
        .borderRadius(8)
        .width(FullPercent)
        .onChange((text: string) => this.$text(text))
    }
    .alignItems(HorizontalAlign.Start)
    .padding(4)
  }
}
