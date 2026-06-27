import { LengthMetrics } from '@kit.ArkUI'
import { HdsListItem, hdsMaterial, HdsNavigationTitleBarOptions, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { AppUtil } from '@pura/harmony-utils'
import { BindSheetDialogController, FullPercent, symbolModifier } from 'common'
import type { WorldBookIndexEntry } from 'tavern_ohos'
import { WorldBookEditState } from './WorldBookEditState'
import { WorldBookEditViewModel } from './WorldBookEditViewModel'

@Builder
function worldBookEditSheetBuilder(param: WorldBookEditPageParam) {
  WorldBookEditPage({ param: param })
}

export class WorldBookEditPageParam {
  book?: WorldBookIndexEntry = undefined
  onSaved: () => void = () => {
  }
}


@ComponentV2
export struct WorldBookEditPage {
  @Param param: WorldBookEditPageParam = new WorldBookEditPageParam()
  private readonly state = new WorldBookEditState()
  private readonly vm = new WorldBookEditViewModel(this.state)

  aboutToAppear(): void {
    this.state.onSaved = this.param.onSaved
    const book = this.param.book
    if (book !== undefined) {
      this.state.id = book.id
      this.state.name = book.name
    }
  }

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
    .titleBar(this.titleBarOptions())
    .hideBackButton(false)
  }

  private getPageTitle(): ResourceStr {
    return this.state.id.length > 0 ? $r("app.string.edit_world_book") : $r("app.string.add_world_book")
  }

  private onSave(): void {
    this.vm.onSave()
  }

  private titleBarOptions(): HdsNavigationTitleBarOptions {
    const mainTitle = this.getPageTitle()
    const saveAction = (): void => this.onSave()
    return {
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: mainTitle },
        menu: {
          value: [{
            content: {
              icon: symbolModifier($r("sys.symbol.checkmark")).fontColor([$r('sys.color.font_primary')]),
              label: $r("app.string.save"),
              action: saveAction
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
    }
  }

  @Builder
  private nameInput() {
    WorldBookInput({
      text: this.state.name!!,
      title: $r("app.string.world_book_name"),
      placeholder: $r("app.string.world_book_name_placeholder"),
    })
  }

  public static start(onSaved?: () => void) {
    const param = new WorldBookEditPageParam()
    param.onSaved = onSaved ?? (() => {
    })
    BindSheetDialogController.showWithParam(wrapBuilder(worldBookEditSheetBuilder), param)
  }

  public static startWithParam(book: WorldBookIndexEntry, onSaved?: () => void) {
    const param = new WorldBookEditPageParam()
    param.book = book
    param.onSaved = onSaved ?? (() => {
    })
    BindSheetDialogController.showWithParam(wrapBuilder(worldBookEditSheetBuilder), param)
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
