import { HdsNavDestination } from '@kit.UIDesignKit';
import { symbolModifier } from 'common';
import { Route, RouterName } from 'router';
import { ContactsViewModel } from './ContactsViewModel';

@Route({ name: RouterName.Contacts })
@Component
export struct ContactsPage {
  private readonly vm = new ContactsViewModel();

  build() {
    HdsNavDestination() {

    }
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
      content: {
        title: { mainTitle: $r("app.string.contacts") },
        menu: {
          value: [{
            content: {
              icon: symbolModifier($r("sys.symbol.plus"))
                .fontColor([$r('sys.color.font_primary')]),
              label: $r("app.string.add_contacts"),
              action: () => this.vm.onAdd()
            }
          }]
        }
      },
    })
    .hideBackButton(true)
  }
}
