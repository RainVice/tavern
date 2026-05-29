import { Route } from '@hzw/zrouter';
import { HdsListItem, hdsMaterial, HdsNavDestination } from '@kit.UIDesignKit';
import { FullPercent, symbolModifier } from 'common';
import { RouterName } from 'router';
import { CharacterCardEditViewModel } from './CharacterCardEditViewModel';
import { CharacterCardEditState } from './CharacterCardEditState';

@Route({ name: RouterName.CharacterCardEdit })
@ComponentV2
export struct CharacterCardEditPage {
  private readonly state = new CharacterCardEditState()
  private readonly vm = new CharacterCardEditViewModel(this.state)

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        ListItem().height(56)
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.avatarInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.nameInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.descriptionInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.personalityInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.scenarioInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.firstMessageInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.exampleMessagesInput() } } })
      }.width(FullPercent).height(FullPercent)
    }
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
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
        }
      }
    })
    .hideBackButton(false)
  }

  @Builder
  private nameInput() {
    Column({ space: 8 }) {
      Text($r("app.string.character_card_name"))
        .fontSize(12)
        .fontColor($r("sys.color.font_secondary"))
        .padding({ left: 8 })

      TextInput({ text: this.getName(), placeholder: $r("app.string.character_card_name_placeholder") })
        .padding(8)
        .borderRadius(8)
        .width(FullPercent)
        .onChange((value: string) => this.state.name = value)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(4)
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
    Column({ space: 8 }) {
      Text($r("app.string.character_card_description"))
        .fontSize(12)
        .fontColor($r("sys.color.font_secondary"))
        .padding({ left: 8 })

      TextArea({ text: this.getDescription(), placeholder: $r("app.string.character_card_description_placeholder") })
        .padding(8)
        .borderRadius(8)
        .width(FullPercent)
        .height(144)
        .fontSize(14)
        .onChange((value: string) => this.state.description = value)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(4)
  }

  @Builder
  private personalityInput() {
    Column({ space: 8 }) {
      Text($r("app.string.character_card_personality"))
        .fontSize(12)
        .fontColor($r("sys.color.font_secondary"))
        .padding({ left: 8 })

      TextArea({ text: this.getPersonality(), placeholder: $r("app.string.character_card_personality_placeholder") })
        .padding(8)
        .borderRadius(8)
        .width(FullPercent)
        .height(144)
        .fontSize(14)
        .onChange((value: string) => this.state.personality = value)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(4)
  }

  @Builder
  private scenarioInput() {
    Column({ space: 8 }) {
      Text($r("app.string.character_card_scenario"))
        .fontSize(12)
        .fontColor($r("sys.color.font_secondary"))
        .padding({ left: 8 })

      TextArea({ text: this.getScenario(), placeholder: $r("app.string.character_card_scenario_placeholder") })
        .padding(8)
        .borderRadius(8)
        .width(FullPercent)
        .height(144)
        .fontSize(14)
        .onChange((value: string) => this.state.scenario = value)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(4)
  }

  @Builder
  private firstMessageInput() {
    Column({ space: 8 }) {
      Text($r("app.string.character_card_first_message"))
        .fontSize(12)
        .fontColor($r("sys.color.font_secondary"))
        .padding({ left: 8 })

      TextArea({ text: this.getFirstMessage(), placeholder: $r("app.string.character_card_first_message_placeholder") })
        .padding(8)
        .borderRadius(8)
        .width(FullPercent)
        .height(192)
        .fontSize(14)
        .onChange((value: string) => this.state.firstMessage = value)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(4)
  }

  @Builder
  private exampleMessagesInput() {
    Column({ space: 8 }) {
      Text($r("app.string.character_card_example_messages"))
        .fontSize(12)
        .fontColor($r("sys.color.font_secondary"))
        .padding({ left: 8 })

      TextArea({ text: this.getExampleMessages(), placeholder: $r("app.string.character_card_example_messages_placeholder") })
        .padding(8)
        .borderRadius(8)
        .width(FullPercent)
        .height(192)
        .fontSize(14)
        .onChange((value: string) => this.state.exampleMessages = value)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(4)
  }

  private getName(): string {
    return this.state.name
  }

  private getDescription(): string {
    return this.state.description
  }

  private getPersonality(): string {
    return this.state.personality
  }

  private getScenario(): string {
    return this.state.scenario
  }

  private getFirstMessage(): string {
    return this.state.firstMessage
  }

  private getExampleMessages(): string {
    return this.state.exampleMessages
  }
}
