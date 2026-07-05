import { PopResult, Route } from '@hzw/zrouter';
import { RouterName, RVRouter } from 'router';
import { ProviderEditState } from './ProviderEditState';
import { ProviderEditViewModel } from './ProviderEditViewModel';
import { hdsEffect, hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { AppUtil, ArrayUtil } from '@pura/harmony-utils';
import { FullPercent, hdsEffectAttribute, symbolGlyphAttribute } from 'common';
import { LengthMetrics } from '@kit.ArkUI';
import { Provider } from '../../../tavern/setting/provider/ProviderStore';


@Route({ name: RouterName.ProviderEdit })
@ComponentV2
export struct ProviderEditPage {
  private readonly state: ProviderEditState = new ProviderEditState();
  private readonly viewModel: ProviderEditViewModel = new ProviderEditViewModel(this.state);

  aboutToAppear(): void {
    this.viewModel.init();
  }

  build() {
    HdsNavDestination() {
      Scroll() {
        Column({ space: 8 }) {

          Input({
            title: $r("app.string.provider_name"),
            placeholder: $r("app.string.provider_name_placeholder"),
            text: this.state.name!!,
          })

          Input({
            title: $r("app.string.base_url"),
            placeholder: $r("app.string.base_url_placeholder"),
            text: this.state.baseUrl!!,
          })

          Input({
            title: $r("app.string.api_key"),
            placeholder: $r("app.string.api_key_placeholder"),
            text: this.state.key!!,
            inputType: InputType.Password
          })

          Row({ space: 8 }) {
            Input({
              title: $r("app.string.model_name"),
              placeholder: $r("app.string.model_name_placeholder"),
              text: this.state.modelName!!,
            }).layoutWeight(1)
            Column({ space: 4 }) {
              SymbolGlyph($r("sys.symbol.arrow_down_circle"))
                .fontSize(20)
                .fontColor([$r("sys.color.font_emphasize_contrary")])
                .attributeModifier(symbolGlyphAttribute())

              Text($r("app.string.get_model"))
                .fontSize(10)
                .textAlign(TextAlign.Start)
                .fontColor($r("sys.color.font_emphasize_contrary"))
            }
            .padding(4)
            .visibility(this.state.key && this.state.baseUrl ? Visibility.Visible : Visibility.None)
            .animation({ duration: 300 })
            .onClick(() => this.viewModel.onGetModelClick())
          }

          if (ArrayUtil.isNotEmpty(this.state.modelList)) {
            Flex({ wrap: FlexWrap.NoWrap, space: { main: LengthMetrics.vp(4), cross: LengthMetrics.vp(4) } }) {
              Repeat(this.state.modelList).each(repeat => {
                Stack() {
                  Text(repeat.item.id).fontSize(12).fontWeight(FontWeight.Regular).padding(8)
                    .fontColor(this.state.modelName == repeat.item.id ? $r("sys.color.font_emphasize") :
                      $r("sys.color.font_tertiary"))
                }
                .borderRadius(100)
                .backgroundColor(this.state.modelName == repeat.item.id
                  ? $r("sys.color.comp_emphasize_secondary") : $r("sys.color.background_tertiary"))
                .visualEffect(new hdsEffect.HdsEffectBuilder().pointLight({
                  illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER,
                }).buildEffect())
                .onClick(() => this.state.modelName = repeat.item.id)
              })
            }
          }
        }.margin(16)

      }
      .align(Alignment.Top)
      .width(FullPercent)
      .height(FullPercent)
      .contentStartOffset(56 + this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
      .contentEndOffset(this.getUIContext().px2vp(AppUtil.getNavigationIndicatorHeight()))
    }
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: $r("app.string.edit_model_provider") },
        menu: {
          value: [{
            content: {
              icon: $r("sys.symbol.checkmark"),
              label: $r("app.string.save"),
              action: () => this.viewModel.onSaveClick()
            }
          }]
        }
      },
      style: {
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      },
    })
  }

  static start(param: ProviderEditParam) {
    RVRouter.push({ name: RouterName.ProviderEdit, param: param.provider, onPop: param.onPop })
  }
}

interface ProviderEditParam {
  provider?: Provider,
  onPop: (provider: PopResult<Provider | null | undefined>) => void
}


@ComponentV2
struct Input {
  @Require @Param title: ResourceStr;
  @Require @Param text: string;
  @Param inputType: InputType = InputType.Normal;
  @Event $text: (value: string) => void;
  @Require @Param placeholder: ResourceStr;
  @Local private hasFocus: boolean = false

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontColor($r("sys.color.font_secondary"))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
      TextInput({ placeholder: this.placeholder, text: this.text })
        .onChange((text) => this.$text(text))
        .onFocus(() => this.getUIContext().animateTo({ duration: 300 }, () => this.hasFocus = true))
        .onBlur(() => this.getUIContext().animateTo({ duration: 300 }, () => this.hasFocus = false))
        .borderRadius(0)
        .placeholderColor($r("sys.color.font_tertiary"))
        .padding(0)
        .backgroundColor(Color.Transparent)
        .type(this.inputType)
    }.itemStyle(this.hasFocus)
    .attributeModifier(hdsEffectAttribute({
      color: this.hasFocus ? $r("sys.color.background_emphasize") : undefined,
      height: this.hasFocus ? 200 : 0,
      intensity: this.hasFocus ? 1 : 0,
      bloom: this.hasFocus ? 0.5 : 0
    }))
  }
}

@Extend(Column)
function itemStyle(hasFocus: boolean) {
  .borderColor(hasFocus ? undefined : $r("sys.color.background_fourth"))
  .borderWidth(hasFocus ? undefined : 0.2)
  .borderRadius(16)
  .padding(16 + (hasFocus ? 0.2 : 0))
  .alignItems(HorizontalAlign.Start)
}


