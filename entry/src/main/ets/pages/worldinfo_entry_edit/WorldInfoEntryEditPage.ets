import { Route } from '@hzw/zrouter'
import { LengthMetrics } from '@kit.ArkUI'
import { HdsListItem, hdsMaterial, HdsNavDestination, PrefixIcon, ScrollEffectType, SuffixSwitch } from '@kit.UIDesignKit'
import { AppUtil } from '@pura/harmony-utils'
import { FullPercent, hdsAttribute, symbolModifier, symbolSpanAttribute } from 'common'
import { RouterName, RVRouter } from 'router'
import type { WorldInfoEntry } from 'tavern_ohos'
import { WorldInfoEntryEditState } from './WorldInfoEntryEditState'
import { WorldInfoEntryEditViewModel } from './WorldInfoEntryEditViewModel'

export interface WorldInfoEntryEditPageParam {
  worldBookId: string
  entry?: WorldInfoEntry
}

@Route({ name: RouterName.WorldInfoEntryEdit })
@ComponentV2
export struct WorldInfoEntryEditPage {
  private readonly state = new WorldInfoEntryEditState()
  private readonly vm = new WorldInfoEntryEditViewModel(this.state)

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.commentInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.keysInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.secondaryKeysInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.contentInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.insertionOrderInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.positionInput() } } })
        this.switchItem($r("sys.symbol.checkmark_circle"), $r("app.string.world_info_entry_enabled"), this.state.enabled, (value: boolean) => this.state.enabled = value)
        this.switchItem($r("sys.symbol.pin_fill"), $r("app.string.world_info_entry_constant"), this.state.constant, (value: boolean) => this.state.constant = value)
        this.switchItem($r("sys.symbol.scope"), $r("app.string.world_info_entry_selective"), this.state.selective, (value: boolean) => this.state.selective = value)
        this.switchItem($r("sys.symbol.textformat"), $r("app.string.world_info_entry_case_sensitive"), this.state.caseSensitive, (value: boolean) => this.state.caseSensitive = value)
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
        title: { mainTitle: this.state.entryId.length > 0 ? $r("app.string.edit_world_info_entry") : $r("app.string.add_world_info_entry") },
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
  private commentInput() {
    WorldInfoEntryInput({
      icon: $r("sys.symbol.ellipsis_bubble"),
      text: this.state.comment!!,
      title: $r("app.string.world_info_entry_comment"),
      placeholder: $r("app.string.world_info_entry_comment_placeholder"),
    })
  }

  @Builder
  private keysInput() {
    WorldInfoEntryInput({
      icon: $r("sys.symbol.key_fill"),
      text: this.state.keysText!!,
      title: $r("app.string.world_info_entry_keys"),
      placeholder: $r("app.string.world_info_entry_keys_placeholder"),
    })
  }

  @Builder
  private secondaryKeysInput() {
    WorldInfoEntryInput({
      icon: $r("sys.symbol.key"),
      text: this.state.secondaryKeysText!!,
      title: $r("app.string.world_info_entry_secondary_keys"),
      placeholder: $r("app.string.world_info_entry_secondary_keys_placeholder"),
    })
  }

  @Builder
  private contentInput() {
    WorldInfoEntryInput({
      icon: $r("sys.symbol.doc_text_fill"),
      text: this.state.content!!,
      title: $r("app.string.world_info_entry_content"),
      placeholder: $r("app.string.world_info_entry_content_placeholder"),
      areaHeight: 220,
    })
  }

  @Builder
  private insertionOrderInput() {
    WorldInfoEntryInput({
      icon: $r("sys.symbol.sort"),
      text: this.state.insertionOrderText!!,
      title: $r("app.string.world_info_entry_insertion_order"),
      placeholder: $r("app.string.world_info_entry_insertion_order_placeholder"),
    })
  }

  @Builder
  private positionInput() {
    Column({ space: 8 }) {
      Text() {
        SymbolSpan($r("sys.symbol.rectangle_uphalf_inset_filled")).attributeModifier(symbolSpanAttribute())
        Span(" ")
        Span($r("app.string.world_info_entry_position"))
      }
      .fontSize(12)
      .fontColor($r("sys.color.font_secondary"))
      .padding({ start: LengthMetrics.vp(8) })

      Row({ space: 8 }) {
        this.positionOption($r("app.string.world_info_entry_position_before"), 'before')
        this.positionOption($r("app.string.world_info_entry_position_after"), 'after')
      }
      .width(FullPercent)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(4)
  }

  @Builder
  private positionOption(label: ResourceStr, value: string) {
    Text(label)
      .fontSize(14)
      .fontColor(this.state.position === value ? $r("sys.color.font_on_primary") : $r("sys.color.font_primary"))
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .padding(10)
      .backgroundColor(this.state.position === value ? $r("sys.color.font_emphasize") : $r("sys.color.background_tertiary"))
      .borderRadius(8)
      .attributeModifier(hdsAttribute())
      .onClick(() => this.state.position = value)
  }

  @Builder
  private switchItem(icon: Resource, title: ResourceStr, isCheck: boolean, onChange: (value: boolean) => void) {
    HdsListItem({
      hdsListItemCard: {
        prefixItem: new PrefixIcon({ iconValue: { symbol: icon } }),
        textItem: { primaryText: { text: title } },
        suffixItem: new SuffixSwitch({
          isCheck: isCheck,
          onChange: onChange,
        })
      }
    })
  }

  public static startWithParam(param: WorldInfoEntryEditPageParam, onPop?: () => void) {
    RVRouter.pushWithParam(RouterName.WorldInfoEntryEdit, param, onPop)
  }
}

@ComponentV2
struct WorldInfoEntryInput {
  @Param icon: Resource = $r("sys.symbol.doc_text")
  @Param text: ResourceStr = ""
  @Event $text: (text: string) => void = () => {
  }
  @Param title: ResourceStr = ""
  @Param placeholder: ResourceStr = ""
  @Param areaHeight: number = 0

  build() {
    Column({ space: 8 }) {
      Text() {
        SymbolSpan(this.icon).attributeModifier(symbolSpanAttribute())
        Span(" ")
        Span(this.title)
      }
      .fontSize(12)
      .fontColor($r("sys.color.font_secondary"))
      .padding({ start: LengthMetrics.vp(8) })

      if (this.areaHeight > 0) {
        TextArea({ text: this.text, placeholder: this.placeholder })
          .padding(8)
          .borderRadius(8)
          .width(FullPercent)
          .height(this.areaHeight)
          .fontSize(14)
          .onChange((text: string) => this.$text(text))
      } else {
        TextInput({ text: this.text, placeholder: this.placeholder })
          .padding(8)
          .borderRadius(8)
          .width(FullPercent)
          .fontSize(14)
          .onChange((text: string) => this.$text(text))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(4)
  }
}
