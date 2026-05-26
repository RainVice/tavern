import { Route } from '@hzw/zrouter';
import { HdsListItem, hdsMaterial, HdsNavDestination } from '@kit.UIDesignKit';
import { FullPercent, symbolModifier } from 'common';
import { RouterName } from 'router';
import { CharacterCardEditViewModel } from './CharacterCardEditViewModel';
import { CharacterCardEditState } from './CharacterCardEditState';

@Route({ name: RouterName.AddCharacterCard })
@ComponentV2
export struct AddCharacterCardPage {
  private readonly state = new CharacterCardEditState()
  private readonly vm = new CharacterCardEditViewModel(this.state)

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        ListItem().height(56)
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.nameInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.avatarUrlInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.descriptionInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.personalityInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.scenarioInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.firstMessageInput() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.exampleMessagesInput() } } })
      }.width(FullPercent).height(FullPercent)
    }.backgroundColor($r("sys.color.background_secondary"))
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
    CharacterCardField({
      text: this.state.name!!,
      title: $r("app.string.character_card_name"),
      placeholder: $r("app.string.character_card_name_placeholder"),
    })
  }

  @Builder
  private avatarUrlInput() {
    CharacterCardField({
      text: this.state.avatarUrl!!,
      title: $r("app.string.character_card_avatar"),
      placeholder: $r("app.string.character_card_avatar_placeholder"),
    })
  }

  @Builder
  private descriptionInput() {
    CharacterCardField({
      text: this.state.description!!,
      lines: 3,
      title: $r("app.string.character_card_description"),
      placeholder: $r("app.string.character_card_description_placeholder"),
    })
  }

  @Builder
  private personalityInput() {
    CharacterCardField({
      text: this.state.personality!!,
      lines: 3,
      title: $r("app.string.character_card_personality"),
      placeholder: $r("app.string.character_card_personality_placeholder"),
    })
  }

  @Builder
  private scenarioInput() {
    CharacterCardField({
      text: this.state.scenario!!,
      lines: 3,
      title: $r("app.string.character_card_scenario"),
      placeholder: $r("app.string.character_card_scenario_placeholder"),
    })
  }

  @Builder
  private firstMessageInput() {
    CharacterCardField({
      text: this.state.firstMessage!!,
      lines: 4,
      title: $r("app.string.character_card_first_message"),
      placeholder: $r("app.string.character_card_first_message_placeholder"),
    })
  }

  @Builder
  private exampleMessagesInput() {
    CharacterCardField({
      text: this.state.exampleMessages!!,
      lines: 4,
      title: $r("app.string.character_card_example_messages"),
      placeholder: $r("app.string.character_card_example_messages_placeholder"),
    })
  }
}

@ComponentV2
struct CharacterCardField {
  @Param text: ResourceStr = "";
  @Event $text: (text: string) => void = (text: string) => {};
  @Param title: ResourceStr = "";
  @Param placeholder: ResourceStr = "";
  @Param lines: number = 1;

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontSize(12)
        .fontColor($r("sys.color.font_secondary"))
        .padding({ left: 8 })

      if (this.lines > 1) {
        TextArea({ text: this.text!!, placeholder: this.placeholder })
          .padding(8)
          .borderRadius(8)
          .width(FullPercent)
          .height(48 * this.lines)
          .fontSize(14)
          .onChange((value: string) => this.$text(value))
      } else {
        TextInput({ text: this.text!!, placeholder: this.placeholder })
          .padding(8)
          .borderRadius(8)
          .width(FullPercent)
          .onChange((value: string) => this.$text(value))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(4)
  }
}
