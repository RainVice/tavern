import { Route } from '@hzw/zrouter';
import { RouterName } from 'router';
import { RoleCardListState } from './RoleCardListState';
import { RoleCardListViewModel } from './RoleCardListViewModel';
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';


@Route({ name: RouterName.RoleCardList })
@ComponentV2
export struct RoleCardListPage {
  private readonly state: RoleCardListState = new RoleCardListState();
  private readonly viewModel: RoleCardListViewModel = new RoleCardListViewModel(this.state);

  aboutToAppear(): void {
    this.viewModel.init();
  }

  build() {
    HdsNavDestination() {
    }
    .backgroundColor($r("sys.color.background_secondary"))
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: $r("app.string.role_card") },
        menu: {
          value: [{
            content: {
              icon: $r("sys.symbol.plus"),
              label: $r("app.string.add_character_card"),
              action: () => {
                this.viewModel.addRoleCard();
              }
            }
          }]
        }
      },
      style: {
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      },
    })
  }
}