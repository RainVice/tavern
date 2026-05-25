import { Route } from '@hzw/zrouter';
import { hdsMaterial, HdsNavDestination } from '@kit.UIDesignKit';
import {  RouterName } from 'router';

@Route({ name: RouterName.AddContacts })
@ComponentV2
export struct AddContactsPage {
  build() {
    HdsNavDestination() {

    }
    .titleBar({
      content: { title: { mainTitle: $r("app.string.add_contacts") }, },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE
        }
      }
    })
    .hideBackButton(false)
  }
}
