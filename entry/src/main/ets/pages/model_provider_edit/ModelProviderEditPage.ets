import { HdsListItem, hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { FullPercent, hdsAttribute, symbolGlyphAttribute, symbolModifier, symbolSpanAttribute } from 'common';
import { RouterName } from 'router';
import { ModelProviderEditViewModel } from './ModelProviderEditViewModel';
import { LengthMetrics } from '@kit.ArkUI';
import { ModelProviderEditState } from './ModelProviderEditState';
import { Route } from '@hzw/zrouter';
import { AppUtil } from '@pura/harmony-utils';


@Route({ name: RouterName.ModelProviderEdit })
@ComponentV2
export struct ModelProviderEditPage {
  private readonly state = new ModelProviderEditState()
  private readonly vm = new ModelProviderEditViewModel(this.state)

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.providerNameInput() }, } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.baseUrlInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.apiKeyInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.modelListInput() } } })
      }
      .contentStartOffset(56 + this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
      .contentEndOffset(this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
      .width(FullPercent)
      .height(FullPercent)
    }.backgroundColor($r("sys.color.background_secondary")).titleBar({
      avoidLayoutSafeArea: true,

      content: {
        title: { mainTitle: $r("app.string.add_model_provider") }, menu: {
          value: [{
            content: {
              icon: symbolModifier($r("sys.symbol.checkmark")).fontColor([$r('sys.color.font_primary')]),
              label: $r("app.string.save"),
              action: () => this.vm.onSave()
            }
          }]
        }
      }, style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE
        },
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        }
      }
    }).hideBackButton(false)
  }

  @Builder
  private providerNameInput() {
    ModelProviderInput({
      icon: $r("sys.symbol.person_text_rectangle_fill"),
      text: this.state.name!!,
      title: $r("app.string.provider_name"),
      placeholder: $r("app.string.provider_name_placeholder"),
    })
  }

  @Builder
  private baseUrlInput() {
    ModelProviderInput({
      icon: $r("sys.symbol.link"),
      text: this.state.baseUrl!!,
      title: $r("app.string.base_url"),
      placeholder: $r("app.string.base_url_placeholder"),
    })
  }

  @Builder
  private apiKeyInput() {
    ModelProviderInput({
      icon: $r("sys.symbol.key_fill"),
      text: this.state.apiKey!!,
      title: $r("app.string.api_key"),
      placeholder: $r("app.string.api_key_placeholder"),
    })
  }

  @Builder
  private modelListInput() {
    ModelListInput({ state: this.state, vm: this.vm })
  }
}

@ComponentV2
struct ModelProviderInput {
  @Param icon: Resource = $r("sys.symbol.person_text_rectangle_fill");
  @Param text: ResourceStr = "";
  @Event $text: (text: string) => void = (text: string) => {
  };
  @Param title: ResourceStr = "";
  @Param placeholder: ResourceStr = "";

  build() {
    Column({ space: 8 }) {
      Text() {
        SymbolSpan(this.icon).attributeModifier(symbolSpanAttribute())
        Span(" ")
        Span(this.title)
      }.margin({ start: LengthMetrics.vp(8) }).fontSize(12).fontColor($r("sys.color.font_secondary"))

      TextInput({ text: this.text, placeholder: this.placeholder })
        .padding(8)
        .borderRadius(8)
        .width(FullPercent)
        .onChange((text: string) => this.$text(text))
    }.alignItems(HorizontalAlign.Start).padding(4)
  }
}

@ComponentV2
struct ModelListInput {
  @Require @Param state: ModelProviderEditState
  @Require @Param vm: ModelProviderEditViewModel
  @Local private modelName: string = ""

  build() {
    Column({ space: 8 }) {
      Row() {
        Text() {
          SymbolSpan($r("sys.symbol.list_bullet")).attributeModifier(symbolSpanAttribute())
          Span(" ")
          Span($r("app.string.model_list"))
        }.margin({ start: LengthMetrics.vp(8) }).fontSize(12).fontColor($r("sys.color.font_secondary"))

        Blank().layoutWeight(1)
        if (this.state.isShowGetModel()) {
          Text() {
            SymbolSpan($r("sys.symbol.arrow_down_circle")).attributeModifier(symbolSpanAttribute())
            Span(" ")
            Span($r("app.string.get_model"))
          }.margin({ start: LengthMetrics.vp(8) }).fontSize(12).fontColor($r("sys.color.font_emphasize"))
          .onClick(() => this.vm.onGetModel())
        }
      }

      Row({ space: 8 }) {
        TextInput({ text: this.modelName!!, placeholder: $r("app.string.model_list_placeholder") })
          .layoutWeight(1)
          .padding(8)
          .borderRadius(8)
          .width(FullPercent)
        Button() {
          SymbolGlyph($r("sys.symbol.plus"))
            .attributeModifier(symbolGlyphAttribute())
            .fontColor([$r('sys.color.font_primary')])
        }.padding(8).backgroundColor($r('sys.color.background_tertiary')).attributeModifier(hdsAttribute())
        .onClick(() => {
          if (this.vm.onAddModel(this.modelName.trim())) {
            this.modelName = ""
          }
        })
      }

      if (this.state.modelList.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          Repeat(this.state.modelList).each(repeat => {
            Text() {
              Span(repeat.item.modelId)
              Span(" ")
              SymbolSpan($r("sys.symbol.xmark"))
                .attributeModifier(symbolSpanAttribute())
            }
            .onClick(() => this.vm.onDeleteModel(repeat.item))
            .fontSize(12)
            .fontColor($r("sys.color.font_secondary"))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding(8)
            .backgroundColor($r('sys.color.background_fourth'))
            .borderRadius(100)
            .attributeModifier(hdsAttribute())
          }).key(item => item.modelId)
        }
      }
    }.alignItems(HorizontalAlign.Start).padding(4)
  }
}
