import { hdsMaterial, HdsNavigation, HdsTabs } from '@kit.UIDesignKit';
import { FullPercent, symbolModifier } from 'common';
import { RVRouter } from 'router';
import { MessagePage } from './pages/message/MessagePage';
import { CharacterCardPage } from './pages/character_card/CharacterCardPage';
import { WorldBookPage } from './pages/worldbook/WorldBookPage';
import { SettingsPage } from './pages/settings/SettingsPage';

@Entry
@ComponentV2
struct Index {
  build() {
    HdsNavigation(RVRouter.getNavStack()) {
      HdsTabs() {
        TabContent() {
          MessagePage()
        }
        .width(FullPercent)
        .height(FullPercent)
        .tabBar(new BottomTabBarStyle({ normal: symbolModifier($r("sys.symbol.message_fill")) },
          $r('app.string.messages')))

        TabContent() {
          CharacterCardPage()
        }
        .width(FullPercent)
        .height(FullPercent)
        .tabBar(new BottomTabBarStyle({ normal: symbolModifier($r("sys.symbol.person_2_fill")) },
          $r('app.string.character_card')))


        TabContent() {
          WorldBookPage()
        }
        .width(FullPercent)
        .height(FullPercent)
        .tabBar(new BottomTabBarStyle({ normal: symbolModifier($r("sys.symbol.book_pages_fill_1")) },
          $r('app.string.world_book')))

        // 设置
        TabContent() {
          SettingsPage()
        }
        .width(FullPercent)
        .height(FullPercent)
        .tabBar(new BottomTabBarStyle({ normal: symbolModifier($r("sys.symbol.gearshape_fill")) },
          $r('app.string.settings')))
      }
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .barFloatingStyle({
        adaptToHandedness: true,
        thermoCtrl: true,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        }
      })
    }
    .backgroundColor($r("sys.color.background_secondary"))
    .hideTitleBar(true)
    .width(FullPercent)
    .height(FullPercent)
  }
}