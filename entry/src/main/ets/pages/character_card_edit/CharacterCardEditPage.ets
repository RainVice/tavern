import { Route } from '@hzw/zrouter';
import { LengthMetrics } from '@kit.ArkUI';
import { HdsListItem, hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { FullPercent, symbolModifier } from 'common';
import { RouterName, RVRouter } from 'router';
import { CharacterCardEditViewModel } from './CharacterCardEditViewModel';
import { CharacterCardEditState } from './CharacterCardEditState';
import { AppUtil } from '@pura/harmony-utils';
import type { CharacterRecord } from 'tavern_ohos';

@Route({ name: RouterName.CharacterCardEdit })
@ComponentV2
export struct CharacterCardEditPage {
  private readonly state = new CharacterCardEditState()
  private readonly vm = new CharacterCardEditViewModel(this.state)

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.avatarInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.nameInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.descriptionInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.personalityInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.scenarioInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.firstMessageInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.exampleMessagesInput() } } })
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
        title: { mainTitle: $r("app.string.add_character_card") }, menu: {
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
    CharacterCardInput({
      text: this.state.name!!,
      title: $r("app.string.character_card_name"),
      placeholder: $r("app.string.character_card_name_placeholder"),
    })
  }

  @Builder
  private avatarInput() {
    Column({ space: 12 }) {
      Text($r("app.string.character_card_avatar"))
        .fontSize(12)
        .fontColor($r("sys.color.font_secondary"))

      Stack() {
        if (this.state.avatarUrl) {
          Image(this.state.avatarUrl)
            .width(96)
            .height(96)
            .borderRadius(48)
            .objectFit(ImageFit.Cover)
        } else {
          Column() {
            SymbolGlyph($r("sys.symbol.person_fill"))
              .fontSize(40)
              .fontColor([$r("sys.color.font_tertiary")])
          }
          .width(96)
          .height(96)
          .borderRadius(48)
          .backgroundColor($r("sys.color.comp_background_gray"))
          .justifyContent(FlexAlign.Center)
        }

        // 相机角标
        Column() {
          SymbolGlyph($r("sys.symbol.camera_fill"))
            .fontSize(14)
            .fontColor([$r("sys.color.font_on_primary")])
        }
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor($r("sys.color.font_emphasize"))
        .justifyContent(FlexAlign.Center)
        .position({ x: 68, y: 68 })
      }
      .onClick(() => this.vm.onSelectAvatar())

      Text($r("app.string.character_card_avatar_placeholder"))
        .fontSize(12)
        .fontColor($r("sys.color.font_tertiary"))
    }
    .alignItems(HorizontalAlign.Center)
    .width(FullPercent)
    .padding({ top: 12, bottom: 12 })
  }

  @Builder
  private descriptionInput() {
    CharacterCardInput({
      text: this.state.description!!,
      title: $r("app.string.character_card_description"),
      placeholder: $r("app.string.character_card_description_placeholder"),
      areaHeight: 144,
    })
  }

  @Builder
  private personalityInput() {
    CharacterCardInput({
      text: this.state.personality!!,
      title: $r("app.string.character_card_personality"),
      placeholder: $r("app.string.character_card_personality_placeholder"),
      areaHeight: 144,
    })
  }

  @Builder
  private scenarioInput() {
    CharacterCardInput({
      text: this.state.scenario!!,
      title: $r("app.string.character_card_scenario"),
      placeholder: $r("app.string.character_card_scenario_placeholder"),
      areaHeight: 144,
    })
  }

  @Builder
  private firstMessageInput() {
    CharacterCardInput({
      text: this.state.firstMessage!!,
      title: $r("app.string.character_card_first_message"),
      placeholder: $r("app.string.character_card_first_message_placeholder"),
      areaHeight: 192,
    })
  }

  @Builder
  private exampleMessagesInput() {
    CharacterCardInput({
      text: this.state.exampleMessages!!,
      title: $r("app.string.character_card_example_messages"),
      placeholder: $r("app.string.character_card_example_messages_placeholder"),
      areaHeight: 192,
    })
  }

  public static start(onPop?: () => void) {
    RVRouter.push(RouterName.CharacterCardEdit, onPop)
  }

  public static startWithParam(param: CharacterRecord, onPop?: () => void) {
    RVRouter.pushWithParam(RouterName.CharacterCardEdit, param, onPop)
  }
}

@ComponentV2
struct CharacterCardInput {
  @Param text: ResourceStr = "";
  @Event $text: (text: string) => void = () => {
  };
  @Param title: ResourceStr = "";
  @Param placeholder: ResourceStr = "";
  @Param areaHeight: number = 0;

  build() {
    Column({ space: 8 }) {
      Text(this.title)
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
          .onChange((text: string) => this.$text(text))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(4)
  }
}
