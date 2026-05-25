import { Route } from '@hzw/zrouter';
import { hdsMaterial, HdsNavDestination } from '@kit.UIDesignKit';
import {  RouterName } from 'router';

@Route({ name: RouterName.WorldBook })
@ComponentV2
export struct WorldBookPage {
  build() {
    HdsNavDestination() {

    }
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
      content: { title: { mainTitle: $r("app.string.world_book") } },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE
        }
      }
    })
    .hideBackButton(true)
  }
}
