import { Route } from '@hzw/zrouter';
import { RouterName, RVRouter } from 'router';
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { AppUtil } from '@pura/harmony-utils';
import { FullPercent } from 'common';
import { RoleCardEditRouteParam, RoleCardEditState } from './RoleCardEditState';
import { RoleCardEditViewModel } from './RoleCardEditViewModel';

@Route({ name: RouterName.CharacterCardEdit })
@ComponentV2
export struct RoleCardEditPage {
  private readonly state: RoleCardEditState = new RoleCardEditState();
  private readonly viewModel: RoleCardEditViewModel = new RoleCardEditViewModel(this.state);

  aboutToAppear(): void {
    this.viewModel.init();
  }

  build() {
    HdsNavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 12 }) {
            Text($r('app.string.character_card_avatar'))
              .fontColor($r('sys.color.font_secondary'))
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
            if (this.state.imageUri.length > 0) {
              Image(this.state.imageUri)
                .width(120)
                .height(120)
                .borderRadius(60)
                .objectFit(ImageFit.Cover)
            } else {
              Image($rawfile('default_role_card.png'))
                .width(120)
                .height(120)
                .borderRadius(60)
                .objectFit(ImageFit.Cover)
            }
            Button($r('app.string.character_card_avatar_placeholder'))
              .onClick(() => this.viewModel.selectAvatar())
          }
          .width(FullPercent)
          .alignItems(HorizontalAlign.Center)
          .padding(16)
          .borderRadius(16)
          .backgroundColor($r('sys.color.background_tertiary'))

          CharacterCardTextInput({
            title: $r('app.string.character_card_name'),
            placeholder: $r('app.string.character_card_name_placeholder'),
            text: this.state.name!!,
          })

          CharacterCardTextArea({
            title: $r('app.string.character_card_description'),
            placeholder: $r('app.string.character_card_description_placeholder'),
            text: this.state.description!!,
          })

          CharacterCardTextArea({
            title: $r('app.string.character_card_personality'),
            placeholder: $r('app.string.character_card_personality_placeholder'),
            text: this.state.personality!!,
          })

          CharacterCardTextArea({
            title: $r('app.string.character_card_scenario'),
            placeholder: $r('app.string.character_card_scenario_placeholder'),
            text: this.state.scenario!!,
          })

          CharacterCardTextArea({
            title: $r('app.string.character_card_first_message'),
            placeholder: $r('app.string.character_card_first_message_placeholder'),
            text: this.state.firstMessage!!,
          })

          CharacterCardTextArea({
            title: $r('app.string.character_card_example_messages'),
            placeholder: $r('app.string.character_card_example_messages_placeholder'),
            text: this.state.exampleMessages!!,
          })
        }
        .margin(16)
      }
      .align(Alignment.Top)
      .width(FullPercent)
      .height(FullPercent)
      .contentStartOffset(56 + this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
      .contentEndOffset(this.getUIContext().px2vp(AppUtil.getNavigationIndicatorHeight()))
    }
    .backgroundColor($r('sys.color.background_secondary'))
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: {
          mainTitle: this.state.editing ? $r('app.string.edit_character_card') : $r('app.string.add_character_card')
        },
        menu: {
          value: [{
            content: {
              icon: $r('sys.symbol.checkmark'),
              label: $r('app.string.save'),
              action: () => this.viewModel.save()
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

  static start(param: RoleCardEditPageParam): void {
    const routeParam: RoleCardEditRouteParam = {
      roleCard: param.roleCard,
      imageUri: param.imageUri
    };
    RVRouter.push({
      name: RouterName.CharacterCardEdit,
      param: routeParam,
      onPop: param.onPop
    });
  }
}

interface RoleCardEditPageParam extends RoleCardEditRouteParam {
  onPop: () => void;
}

@ComponentV2
struct CharacterCardTextInput {
  @Require @Param title: ResourceStr;
  @Require @Param placeholder: ResourceStr;
  @Param text: ResourceStr = '';
  @Event $text: (value: string) => void;

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontColor($r('sys.color.font_secondary'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
      TextInput({ text: this.text, placeholder: this.placeholder })
        .onChange((text: string) => this.$text(text))
        .borderRadius(0)
        .placeholderColor($r('sys.color.font_tertiary'))
        .padding(0)
        .backgroundColor(Color.Transparent)
    }
    .padding(16)
    .borderRadius(16)
    .borderWidth(0.2)
    .borderColor($r('sys.color.background_fourth'))
    .backgroundColor($r('sys.color.background_tertiary'))
  }
}

@ComponentV2
struct CharacterCardTextArea {
  @Require @Param title: ResourceStr;
  @Require @Param placeholder: ResourceStr;
  @Param text: ResourceStr = '';
  @Event $text: (value: string) => void;

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontColor($r('sys.color.font_secondary'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
      TextArea({ text: this.text, placeholder: this.placeholder })
        .onChange((text: string) => this.$text(text))
        .height(120)
        .borderRadius(0)
        .placeholderColor($r('sys.color.font_tertiary'))
        .padding(0)
        .backgroundColor(Color.Transparent)
    }
    .padding(16)
    .borderRadius(16)
    .borderWidth(0.2)
    .borderColor($r('sys.color.background_fourth'))
    .backgroundColor($r('sys.color.background_tertiary'))
  }
}
