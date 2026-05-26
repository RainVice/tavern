import { Route } from '@hzw/zrouter';
import { hdsMaterial, HdsNavDestination } from '@kit.UIDesignKit';
import {  RouterName } from 'router';

@Route({ name: RouterName.AddCharacterCard })
@ComponentV2
export struct AddCharacterCardPage {
  build() {
    HdsNavDestination() {

    }
    .titleBar({
      content: { title: { mainTitle: $r("app.string.add_character_card") }, },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE
        }
      }
    })
    .hideBackButton(false)
  }
}
