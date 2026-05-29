import { Route } from '@hzw/zrouter'
import { HdsListItem, hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { AppUtil } from '@pura/harmony-utils'
import { FullPercent, symbolModifier } from 'common'
import { RouterName, RVRouter } from 'router'
import { CharacterCardDetailState } from './CharacterCardDetailState'
import { CharacterCardDetailViewModel } from './CharacterCardDetailViewModel'

@Route({ name: RouterName.CharacterCardDetail })
@ComponentV2
export struct CharacterCardDetailPage {
  private readonly state = new CharacterCardDetailState()
  private readonly vm = new CharacterCardDetailViewModel(this.state)

  build() {
    HdsNavDestination() {
      List({ space: 10 }) {
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.header() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.descriptionField() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.personalityField() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.scenarioField() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.firstMessageField() } } })
        HdsListItem({ hdsListItemCard: { textItem: { customBuilder: () => this.exampleMessagesField() } } })
      }
      .contentStartOffset(56 + this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
      .contentEndOffset(this.getUIContext().px2vp(AppUtil.getStatusBarHeight()))
      .width(FullPercent)
      .height(FullPercent)
    }
    .onBackPressed(() => {
      RVRouter.pop(true)
      return true
    })
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: $r("app.string.character_card_detail") },
        menu: {
          value: [
            {
              content: {
                icon: symbolModifier($r("sys.symbol.square_and_pencil"))
                  .fontColor([$r('sys.color.font_primary')]),
                label: $r("app.string.edit_character_card"),
                action: () => this.vm.onEdit()
              }
            },
            {
              content: {
                icon: symbolModifier($r("sys.symbol.message_fill"))
                  .fontColor([$r('sys.color.font_primary')]),
                label: $r("app.string.start_conversation"),
                action: () => this.vm.onStartConversation()
              }
            },
          ]
        }
      },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE
        },
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        }
      }
    })
    .hideBackButton(false)
  }

  @Builder
  private header() {
    Column({ space: 12 }) {
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
      }

      Text(this.state.name || $r("app.string.character_card_unnamed"))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r("sys.color.font_primary"))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.state.description) {
        Text(this.state.description)
          .fontSize(14)
          .fontColor($r("sys.color.font_secondary"))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .alignItems(HorizontalAlign.Center)
    .width(FullPercent)
    .padding({ top: 16, bottom: 16 })
  }

  @Builder
  private descriptionField() {
    Column({ space: 8 }) {
      Text($r("app.string.character_card_description"))
        .fontSize(12)
        .fontColor($r("sys.color.font_secondary"))
        .padding({ left: 8 })

      if (this.state.description.trim().length > 0) {
        Text(this.state.description)
          .fontSize(14)
          .fontColor($r("sys.color.font_primary"))
          .width(FullPercent)
          .padding(8)
      } else {
        Text($r("app.string.character_card_detail_empty"))
          .fontSize(14)
          .fontColor($r("sys.color.font_tertiary"))
          .width(FullPercent)
          .padding(8)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(4)
  }

  @Builder
  private personalityField() {
    Column({ space: 8 }) {
      Text($r("app.string.character_card_personality"))
        .fontSize(12)
        .fontColor($r("sys.color.font_secondary"))
        .padding({ left: 8 })

      if (this.state.personality.trim().length > 0) {
        Text(this.state.personality)
          .fontSize(14)
          .fontColor($r("sys.color.font_primary"))
          .width(FullPercent)
          .padding(8)
      } else {
        Text($r("app.string.character_card_detail_empty"))
          .fontSize(14)
          .fontColor($r("sys.color.font_tertiary"))
          .width(FullPercent)
          .padding(8)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(4)
  }

  @Builder
  private scenarioField() {
    Column({ space: 8 }) {
      Text($r("app.string.character_card_scenario"))
        .fontSize(12)
        .fontColor($r("sys.color.font_secondary"))
        .padding({ left: 8 })

      if (this.state.scenario.trim().length > 0) {
        Text(this.state.scenario)
          .fontSize(14)
          .fontColor($r("sys.color.font_primary"))
          .width(FullPercent)
          .padding(8)
      } else {
        Text($r("app.string.character_card_detail_empty"))
          .fontSize(14)
          .fontColor($r("sys.color.font_tertiary"))
          .width(FullPercent)
          .padding(8)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(4)
  }

  @Builder
  private firstMessageField() {
    Column({ space: 8 }) {
      Text($r("app.string.character_card_first_message"))
        .fontSize(12)
        .fontColor($r("sys.color.font_secondary"))
        .padding({ left: 8 })

      if (this.state.firstMessage.trim().length > 0) {
        Text(this.state.firstMessage)
          .fontSize(14)
          .fontColor($r("sys.color.font_primary"))
          .width(FullPercent)
          .padding(8)
      } else {
        Text($r("app.string.character_card_detail_empty"))
          .fontSize(14)
          .fontColor($r("sys.color.font_tertiary"))
          .width(FullPercent)
          .padding(8)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(4)
  }

  @Builder
  private exampleMessagesField() {
    Column({ space: 8 }) {
      Text($r("app.string.character_card_example_messages"))
        .fontSize(12)
        .fontColor($r("sys.color.font_secondary"))
        .padding({ left: 8 })

      if (this.state.exampleMessages.trim().length > 0) {
        Text(this.state.exampleMessages)
          .fontSize(14)
          .fontColor($r("sys.color.font_primary"))
          .width(FullPercent)
          .padding(8)
      } else {
        Text($r("app.string.character_card_detail_empty"))
          .fontSize(14)
          .fontColor($r("sys.color.font_tertiary"))
          .width(FullPercent)
          .padding(8)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(4)
  }
}
