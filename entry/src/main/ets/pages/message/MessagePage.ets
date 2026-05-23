import { HdsNavDestination } from '@kit.UIDesignKit';
import { Route, RouterName } from 'router';

@Route({ name: RouterName.Message })
@Component
export struct MessagePage {
  build() {
    HdsNavDestination() {

    }
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({ content: { title: { mainTitle: $r("app.string.messages") } } })
    .hideBackButton(true)
  }
}