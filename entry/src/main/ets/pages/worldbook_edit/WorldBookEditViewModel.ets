import { LogUtil, ToastUtil } from '@pura/harmony-utils'
import { BindSheetDialogController } from 'common'
import { TavernRuntimeContainer } from '../../tavern/TavernRuntimeContainer'
import { WorldBookEditState } from './WorldBookEditState'

export class WorldBookEditViewModel {
  private state: WorldBookEditState
  private runtime: TavernRuntimeContainer = TavernRuntimeContainer.getInstance()

  constructor(state: WorldBookEditState) {
    this.state = state
  }

  onSave(): boolean {
    if (this.state.name.trim().length === 0) {
      ToastUtil.showToast($r("app.string.world_book_name_empty"))
      return false
    }
    this.saveWorldBook().then(() => {
      this.state.onSaved()
      BindSheetDialogController.hide()
    }).catch((error: Error) => {
      LogUtil.setDomain()
      LogUtil.debug('WorldBookEditViewModel', 'onSave', '保存世界书失败', error.message)
      ToastUtil.showToast($r("app.string.world_book_save_failed"))
    })
    return true
  }

  private async saveWorldBook(): Promise<void> {
    const name = this.state.name.trim()
    if (this.state.id.length > 0) {
      await this.runtime.worldInfo.updateWorldBook(this.state.id, name)
    } else {
      await this.runtime.worldInfo.createWorldBook(name)
    }
  }
}
