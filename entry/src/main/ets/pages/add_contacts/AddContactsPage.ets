import { HdsNavDestination } from '@kit.UIDesignKit';
import { Route, RouterName } from 'router';

@Route({ name: RouterName.AddContacts })
@Component
export struct AddContactsPage {
  build() {
    HdsNavDestination() {

    }
    .titleBar({ content: { title: { mainTitle: $r("app.string.add_contacts") } } })
    .hideBackButton(false)
  }
}
