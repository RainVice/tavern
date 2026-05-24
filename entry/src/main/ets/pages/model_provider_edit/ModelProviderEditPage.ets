import { HdsListItem, hdsMaterial, HdsNavDestination } from '@kit.UIDesignKit';
import { FullPercent, hdsAttribute, symbolModifier } from 'common';
import { Route, RouterName } from 'router';
import { ModelProviderEditViewModel } from './ModelProviderEditViewModel';
import { LengthMetrics } from '@kit.ArkUI';
import { ModelProviderEditState } from './ModelProviderEditState';

interface ModelProviderInputOption {
  icon: Resource;
  text: ResourceStr;
  title: ResourceStr;
  placeholder: ResourceStr;
  onTextChange: (text: string) => void;
}

@Route({ name: RouterName.ModelProviderEdit })
@ComponentV2
export struct ModelProviderEditPage {
  private readonly state = new ModelProviderEditState()
  private readonly vm = new ModelProviderEditViewModel(this.state)

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        ListItem().height(56)
        HdsListItem({
          hdsListItemCard: {
            textItem: {
              customBuilder: () => this.modelProviderInput({
                icon: $r("sys.symbol.person_text_rectangle_fill"),
                text: this.state.providerName,
                title: $r("app.string.provider_name"),
                placeholder: $r("app.string.provider_name_placeholder"),
                onTextChange: (text) => this.state.providerName = text,
              }),
            },
          }
        })
        HdsListItem({
          hdsListItemCard: {
            textItem: {
              customBuilder: () => this.modelProviderInput({
                icon: $r("sys.symbol.link"),
                text: this.state.baseUrl,
                title: $r("app.string.base_url"),
                placeholder: $r("app.string.base_url_placeholder"),
                onTextChange: (text) => this.state.baseUrl = text,
              })
            }
          }
        })
        HdsListItem({
          hdsListItemCard: {
            textItem: {
              customBuilder: () => this.modelProviderInput({
                icon: $r("sys.symbol.key_fill"),
                text: this.state.apiKey,
                title: $r("app.string.api_key"),
                placeholder: $r("app.string.api_key_placeholder"),
                onTextChange: (text) => this.state.apiKey = text,
              }),
            }
          }
        })
        HdsListItem({
          hdsListItemCard: {
            textItem: {
              customBuilder: () => this.modelListInput({
                icon: $r("sys.symbol.list_bullet"),
                text: "",
                title: $r("app.string.model_list"),
                placeholder: $r("app.string.model_list_placeholder"),
                onTextChange: (text) => {
                },
              })
            }
          }
        })
      }
      .width(FullPercent)
      .height(FullPercent)
    }
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
      content: {
        title: { mainTitle: $r("app.string.add_model_provider") },
        menu: {
          value: [{
            content: {
              icon: symbolModifier($r("sys.symbol.checkmark"))
                .fontColor([$r('sys.color.font_primary')]),
              label: $r("app.string.save"),
              action: () => this.vm.onSave()
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
    .hideBackButton(false)
  }

  @Builder
  private modelProviderInput(option: ModelProviderInputOption) {
    Column({ space: 8 }) {
      Text() {
        SymbolSpan(option.icon)
          .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
          .effectStrategy(SymbolEffectStrategy.HIERARCHICAL)
        Span(" ")
        Span(option.title)
      }
      .margin({ start: LengthMetrics.vp(8) })
      .fontSize(12)
      .fontColor($r("sys.color.font_emphasize"))

      TextInput({ text: option.text, placeholder: option.placeholder })
        .padding(8)
        .borderRadius(8)
        .width(FullPercent)
        .onChange(option.onTextChange)
    }.alignItems(HorizontalAlign.Start).padding(4)
  }

  @Builder
  private modelListInput(option: ModelProviderInputOption) {
    Column({ space: 8 }) {
      Text() {
        SymbolSpan(option.icon)
          .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
          .effectStrategy(SymbolEffectStrategy.HIERARCHICAL)
        Span(" ")
        Span(option.title)
      }
      .margin({ start: LengthMetrics.vp(8) })
      .fontSize(12)
      .fontColor($r("sys.color.font_emphasize"))

      Column() {
        Row({ space: 8 }) {
          TextInput({ text: option.text, placeholder: option.placeholder })
            .layoutWeight(1)
            .padding(8)
            .borderRadius(8)
            .width(FullPercent)
            .onChange(option.onTextChange)
          Button() {
            SymbolGlyph($r("sys.symbol.plus"))
              .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
              .effectStrategy(SymbolEffectStrategy.HIERARCHICAL)
              .fontColor([$r('sys.color.font_secondary')])
          }
          .padding(8)
          .backgroundColor($r('sys.color.background_tertiary'))
          .attributeModifier(hdsAttribute())
        }
      }
    }.alignItems(HorizontalAlign.Start).padding(4)
  }
}
