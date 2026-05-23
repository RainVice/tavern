import { HdsNavDestination } from '@kit.UIDesignKit';
import { Route, RouterName } from 'router';

@Route({ name: RouterName.Contacts })
@Component
export struct ContactsPage {
  build() {
    HdsNavDestination() {

    }
    .titleBar({ content: { title: { mainTitle: $r("app.string.contacts") } } })
    .hideBackButton(true)
  }
}
