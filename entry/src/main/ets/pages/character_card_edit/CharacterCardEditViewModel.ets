import { FileUtil, ImageUtil, LogUtil, ToastUtil } from '@pura/harmony-utils'
import { RVRouter } from 'router'
import { CharacterCardEditState } from './CharacterCardEditState'
import { ZRouter } from '@hzw/zrouter'
import { PhotoHelper } from '@pura/picker_utils'
import fs from '@ohos.file.fs'
import type { CharacterCreateParams, CharacterRecord, CharacterUpdateParams } from 'tavern_ohos'
import { TavernRuntimeContainer } from '../../tavern/TavernRuntimeContainer'

export class CharacterCardEditViewModel {
  private state: CharacterCardEditState
  private runtime: TavernRuntimeContainer = TavernRuntimeContainer.getInstance()

  constructor(state: CharacterCardEditState) {
    this.state = state
    const param = ZRouter.getInstance().getParam() as CharacterRecord | undefined;
    if (param) {
      this.initFromParam(param);
    }
  }

  private initFromParam(param: CharacterRecord): void {
    if (param.id.length > 0) {
      this.state.id = param.id
      this.runtime.characters.getCharacter(param.id).then((card: CharacterRecord) => {
        this.state.name = card.name
        this.state.description = card.description
        this.state.personality = card.personality
        this.state.scenario = card.scenario
        this.state.firstMessage = card.firstMessage
        this.state.exampleMessages = card.exampleDialogue
        this.runtime.readCharacterAvatar(card).then((avatar: string) => {
          this.state.avatarUrl = avatar
        })
      })
    } else {
      this.state.name = param.name
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
    this.saveCharacter().then(() => {
      RVRouter.pop(true)
    }).catch((error: Error) => {
      LogUtil.setDomain()
      LogUtil.debug('CharacterCardEditViewModel', 'onSave', '保存角色卡失败', error.message)
      ToastUtil.showToast($r("app.string.character_card_save_failed"));
    })
    return true;
  }

  private async saveCharacter(): Promise<void> {
    const state = this.state
    let saved: CharacterRecord
    if (state.id.length > 0) {
      const params: CharacterUpdateParams = {
        name: state.name.trim(),
        description: state.description.trim(),
        personality: state.personality.trim(),
        scenario: state.scenario.trim(),
        firstMessage: state.firstMessage.trim(),
        exampleDialogue: state.exampleMessages.trim(),
        tags: new Array<string>(),
        favorite: false,
      }
      saved = await this.runtime.characters.updateCharacter(state.id, params)
    } else {
      const params: CharacterCreateParams = {
        name: state.name.trim(),
        description: state.description.trim(),
        personality: state.personality.trim(),
        scenario: state.scenario.trim(),
        firstMessage: state.firstMessage.trim(),
        exampleDialogue: state.exampleMessages.trim(),
        tags: new Array<string>(),
      }
      saved = await this.runtime.characters.createCharacter(params)
    }
    await this.runtime.writeCharacterAvatar(saved, state.avatarUrl)
  }
}
