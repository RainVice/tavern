import { hdsMaterial, HdsNavigation, HdsTabs } from '@kit.UIDesignKit';
import { FullPercent, symbolModifier } from 'common';
import { RVRouter } from 'router';
import { MessagePage } from './pages/message/MessagePage';
import { ContactsPage } from './pages/contacts/ContactsPage';
import { WorldBookPage } from './pages/worldbook/WorldBookPage';

@Entry
@Component
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
          ContactsPage()
        }
        .width(FullPercent)
        .height(FullPercent)
        .tabBar(new BottomTabBarStyle({ normal: symbolModifier($r("sys.symbol.person_2_fill")) },
          $r('app.string.contacts')))


        TabContent() {
          WorldBookPage()
        }
        .width(FullPercent)
        .height(FullPercent)
        .tabBar(new BottomTabBarStyle({ normal: symbolModifier($r("sys.symbol.book_pages_fill_1")) },
          $r('app.string.world_book')))
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
    .width(FullPercent)
    .height(FullPercent)
  }
}