import { HdsNavDestination } from '@kit.UIDesignKit';
import { Route, RouterName } from 'router';

@Route({ name: RouterName.WorldBook })
@Component
export struct WorldBookPage {
  build() {
    HdsNavDestination() {

    }
    .titleBar({ content: { title: { mainTitle: $r("app.string.world_book") } } })
    .hideBackButton(true)
  }
}
