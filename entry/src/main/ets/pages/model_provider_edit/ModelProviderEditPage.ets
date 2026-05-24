import { HdsListItem, hdsMaterial, HdsNavDestination } from '@kit.UIDesignKit';
import { FullPercent, hdsAttribute, symbolModifier } from 'common';
import { Route, RouterName } from 'router';
import { ModelProviderEditViewModel } from './ModelProviderEditViewModel';
import { LengthMetrics } from '@kit.ArkUI';
import { ModelProviderEditState } from './ModelProviderEditState';


@Route({ name: RouterName.ModelProviderEdit })
@ComponentV2
export struct ModelProviderEditPage {
  private readonly state = new ModelProviderEditState()
  private readonly vm = new ModelProviderEditViewModel(this.state)

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        ListItem().height(56)
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.providerNameInput() }, } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.baseUrlInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.apiKeyInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.modelListInput() } } })
      }.width(FullPercent).height(FullPercent)
    }.backgroundColor($r("sys.color.background_secondary")).titleBar({
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
        }
      }
    }).hideBackButton(false)
  }

  @Builder
  private providerNameInput() {
    ModelProviderInput({
      icon: $r("sys.symbol.person_text_rectangle_fill"),
      text: this.state.providerName,
      $text: (text: string) => this.state.providerName = text,
      title: $r("app.string.provider_name"),
      placeholder: $r("app.string.provider_name_placeholder"),
    })
  }

  @Builder
  private baseUrlInput() {
    ModelProviderInput({
      icon: $r("sys.symbol.link"),
      text: this.state.baseUrl,
      $text: (text: string) => this.state.baseUrl = text,
      title: $r("app.string.base_url"),
      placeholder: $r("app.string.base_url_placeholder"),
    })
  }

  @Builder
  private apiKeyInput() {
    ModelProviderInput({
      icon: $r("sys.symbol.key_fill"),
      text: this.state.apiKey,
      $text: (text: string) => this.state.apiKey = text,
      title: $r("app.string.api_key"),
      placeholder: $r("app.string.api_key_placeholder"),
    })
  }

  @Builder
  private modelListInput() {
    ModelListInput({ state: this.state })
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
        SymbolSpan(this.icon)
          .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
          .effectStrategy(SymbolEffectStrategy.HIERARCHICAL)
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

  build() {
    Column({ space: 8 }) {
      Row() {
        Text() {
          SymbolSpan($r("sys.symbol.list_bullet"))
            .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
            .effectStrategy(SymbolEffectStrategy.HIERARCHICAL)
          Span(" ")
          Span($r("app.string.model_list"))
        }.margin({ start: LengthMetrics.vp(8) }).fontSize(12).fontColor($r("sys.color.font_secondary"))

        Blank().layoutWeight(1)
        if (this.state.isShowGetModel()) {
          Text() {
            SymbolSpan($r("sys.symbol.arrow_down_circle"))
              .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
              .effectStrategy(SymbolEffectStrategy.HIERARCHICAL)
            Span(" ")
            Span($r("app.string.get_model"))
          }.margin({ start: LengthMetrics.vp(8) }).fontSize(12).fontColor($r("sys.color.font_emphasize"))
        }
      }

      Column() {
        Row({ space: 8 }) {
          TextInput({ text: "", placeholder: $r("app.string.model_list_placeholder") })
            .layoutWeight(1)
            .padding(8)
            .borderRadius(8)
            .width(FullPercent) // .onChange()
          Button() {
            SymbolGlyph($r("sys.symbol.plus"))
              .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
              .effectStrategy(SymbolEffectStrategy.HIERARCHICAL)
              .fontColor([$r('sys.color.font_secondary')])
          }.padding(8).backgroundColor($r('sys.color.background_tertiary')).attributeModifier(hdsAttribute())
        }
      }
    }.alignItems(HorizontalAlign.Start).padding(4)
  }
}

