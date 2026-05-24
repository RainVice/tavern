import { hdsMaterial, HdsNavDestination } from '@kit.UIDesignKit';
import { Route, RouterName } from 'router';

@Route({ name: RouterName.Message })
@ComponentV2
export struct MessagePage {
  build() {
    HdsNavDestination() {

    }
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
      content: { title: { mainTitle: $r("app.string.messages") } },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE
        }
      }
    })
    .hideBackButton(true)
  }
}