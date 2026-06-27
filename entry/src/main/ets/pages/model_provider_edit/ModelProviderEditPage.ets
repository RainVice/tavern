import {
  HdsListItem,
  hdsMaterial,
  HdsNavDestination,
  PrefixIcon,
  ScrollEffectType,
  SuffixSwitch
} from '@kit.UIDesignKit';
import { FullPercent, hdsAttribute, symbolModifier, symbolSpanAttribute } from 'common';
import { RouterName, RVRouter } from 'router';
import { ModelProviderEditViewModel } from './ModelProviderEditViewModel';
import { LengthMetrics } from '@kit.ArkUI';
import { ModelProviderEditState } from './ModelProviderEditState';
import { Route } from '@hzw/zrouter';
import { AppUtil } from '@pura/harmony-utils';
import type { ConnectionProfileRecord } from 'tavern_ohos';


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
        HdsListItem({
          hdsListItemCard: {
            prefixItem: new PrefixIcon({ iconValue: { symbol: $r("sys.symbol.checkmark") } }),
            textItem: { primaryText: { text: $r("app.string.default_model_provider") }, },
            suffixItem: new SuffixSwitch({
              isCheck: this.state.isDefault,
              onChange: (isCheck: boolean) => this.state.isDefault = isCheck
            })
          }
        })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.modelInput() } } })
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
      text: this.state.serverUrl!!,
      title: $r("app.string.base_url"),
      placeholder: $r("app.string.base_url_placeholder"),
    })
  }

  @Builder
  private apiKeyInput() {
    ModelProviderInput({
      icon: $r("sys.symbol.key_fill"),
      text: this.state.secretRef!!,
      title: $r("app.string.api_key"),
      placeholder: $r("app.string.api_key_placeholder"),
    })
  }

  @Builder
  private modelInput() {
    ModelProviderModelInput({
      text: this.state.model!!,
      availableModels: this.state.availableModels,
      canGetModel: this.state.isShowGetModel(),
      onGetModel: () => this.vm.onGetModel(),
    })
  }

  public static start(onPop?: () => void) {
    RVRouter.push(RouterName.ModelProviderEdit, onPop)
  }

  public static startWithParam(param: ConnectionProfileRecord, onPop?: () => void) {
    RVRouter.pushWithParam(RouterName.ModelProviderEdit, param, onPop)
  }
}

@ComponentV2
struct ModelProviderInput {
  @Param icon: Resource = $r("sys.symbol.person_text_rectangle_fill");
  @Param text: ResourceStr = "";
  @Event $text: (text: string) => void = () => {
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
        .type(InputType.Password)
        .padding(8)
        .borderRadius(8)
        .width(FullPercent)
        .onChange((text: string) => this.$text(text))
    }.alignItems(HorizontalAlign.Start).padding(4)
  }
}

@ComponentV2
struct ModelProviderModelInput {
  @Param text: ResourceStr = "";
  @Event $text: (text: string) => void = () => {
  };
  @Param availableModels: Array<string> = new Array<string>();
  @Param canGetModel: boolean = false;
  @Event onGetModel: () => void = () => {
  };

  build() {
    Column({ space: 8 }) {
      Row() {
        Text() {
          SymbolSpan($r("sys.symbol.list_bullet")).attributeModifier(symbolSpanAttribute())
          Span(" ")
          Span($r("app.string.model_list"))
        }.margin({ start: LengthMetrics.vp(8) }).fontSize(12).fontColor($r("sys.color.font_secondary"))

        Blank().layoutWeight(1)
        if (this.canGetModel) {
          Text() {
            SymbolSpan($r("sys.symbol.arrow_down_circle")).attributeModifier(symbolSpanAttribute())
            Span(" ")
            Span($r("app.string.get_model"))
          }.margin({ start: LengthMetrics.vp(8) }).fontSize(12).fontColor($r("sys.color.font_emphasize"))
          .onClick(() => this.onGetModel())
        }
      }

      TextInput({ text: this.text, placeholder: $r("app.string.model_list_placeholder") })
        .padding(8)
        .borderRadius(8)
        .width(FullPercent)
        .onChange((text: string) => this.$text(text))

      if (this.availableModels.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          Repeat<string>(this.availableModels).each((repeat: RepeatItem<string>) => {
            Text(repeat.item)
              .onClick(() => this.$text(repeat.item))
              .fontSize(12)
              .fontColor($r("sys.color.font_secondary"))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding(8)
              .backgroundColor($r('sys.color.background_fourth'))
              .borderRadius(100)
              .attributeModifier(hdsAttribute())
          }).key((item: string) => item)
        }
      }
    }.alignItems(HorizontalAlign.Start).padding(4)
  }
}
