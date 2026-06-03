import { FileUtil, ImageUtil, ToastUtil } from '@pura/harmony-utils'
import { RVRouter } from 'router'
import { CharacterCardEditState } from './CharacterCardEditState'
import { ZRouter } from '@hzw/zrouter'
import { PhotoHelper } from '@pura/picker_utils'
import fs from '@ohos.file.fs'
import { CharacterCard, CharacterCardEntity } from '../../db/entity/CharacterCardEntity'
import { CharacterCardDao } from '../../db/dao/CharacterCardDao'

export class CharacterCardEditViewModel {
  private state: CharacterCardEditState

  constructor(state: CharacterCardEditState) {
    this.state = state
    const param = ZRouter.getInstance().getParam() as CharacterCardEntity | undefined;
    if (param) {
      this.initFromParam(param);
    }
  }

  private initFromParam(param: CharacterCardEntity): void {
    if (param.id) {
      this.state.id = param.id
      CharacterCardDao.queryById(param.id).then((card) => {
        if (card) {
          this.state.name = card.name ?? ''
          this.state.avatarUrl = card.avatarUrl ?? ''
          this.state.description = card.description ?? ''
          this.state.personality = card.personality ?? ''
          this.state.scenario = card.scenario ?? ''
          this.state.firstMessage = card.firstMessage ?? ''
          this.state.exampleMessages = card.exampleMessages ?? ''
        }
      })
    } else {
      this.state.name = param.name ?? ''
    }
  }

  onSelectAvatar(): void {
    PhotoHelper.selectEasy()
      .then((uris) => {
        if (uris.length === 0) {
          return;
        }
        const uri = uris[0];
        FileUtil.open(uri, fs.OpenMode.READ_ONLY)
          .then((file) => {
            ImageUtil.createImageSource(file.fd).createPixelMap()
              .then((pixelMap) => {
                FileUtil.closeSync(file.fd);
                ImageUtil.pixelMapToBase64Str(pixelMap, 'image/jpeg')
                  .then((base64) => {
                    this.state.avatarUrl = base64;
                    pixelMap.release();
                  });
              });
          });
      });
  }

  onSave(): boolean {
    if (this.state.name.trim() === '') {
      ToastUtil.showToast($r("app.string.character_card_name_empty"));
      return false;
    }
    const state = this.state;
    const card: CharacterCard = {
      id: state.id,
      name: state.name.trim(),
      avatarUrl: state.avatarUrl.trim(),
      description: state.description.trim(),
      personality: state.personality.trim(),
      scenario: state.scenario.trim(),
      firstMessage: state.firstMessage.trim(),
      exampleMessages: state.exampleMessages.trim()
    }
    CharacterCardDao.save(card).then(() => {
      RVRouter.pop(true)
    })
    return true;
  }
}