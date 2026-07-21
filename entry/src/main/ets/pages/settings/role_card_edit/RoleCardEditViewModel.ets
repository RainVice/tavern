import picker from '@ohos.file.picker';
import { PickerUtil } from '@pura/picker_utils';
import { FileUtil, ResUtil, StrUtil, ToastUtil } from '@pura/harmony-utils';
import { RVRouter } from 'router';
import { RoleCardListItem, RoleCardStore } from '../../../tavern/role_card/RoleCardStore';
import { RoleCardEditRouteParam, RoleCardEditState } from './RoleCardEditState';

export class RoleCardEditViewModel {
  /** 默认头像在 rawfile 资源目录中的文件名。 */
  private static readonly DEFAULT_AVATAR_RAWFILE: string = 'default_role_card.png';
  /** 默认头像写入缓存目录时使用的文件夹。 */
  private static readonly DEFAULT_AVATAR_CACHE_DIRECTORY: string = 'role_card';
  /** 默认头像写入缓存目录时使用的文件名。 */
  private static readonly DEFAULT_AVATAR_CACHE_FILE: string = 'default_role_card_v4.png';

  private readonly state: RoleCardEditState;

  constructor(state: RoleCardEditState) {
    this.state = state;
  }

  /**
   * 根据路由参数决定当前是添加还是编辑场景。
   */
  init(): void {
    const routeParam = RVRouter.getParam<RoleCardEditRouteParam>();
    this.state.reset();
    if (routeParam === undefined) {
      return;
    }
    if (routeParam.roleCard !== undefined) {
      this.loadRoleCard(routeParam.roleCard);
      return;
    }
    if (routeParam.imageUri !== undefined) {
      this.state.imageUri = routeParam.imageUri;
    }
  }

  /**
   * 选择新的 PNG 头像；未选择时继续保留当前头像或默认头像。
   */
  async selectAvatar(): Promise<void> {
    const documentUris = await PickerUtil.selectDocument({
      maxSelectNumber: 1,
      fileSuffixFilters: ['PNG 图片|.png'],
      mergeMode: picker.MergeTypeMode.PICTURE
    });
    const imageUri = documentUris[0];
    if (imageUri !== undefined) {
      this.state.imageUri = imageUri;
    }
  }

  /**
   * 保存角色卡。添加场景未选择头像时，会先将 rawfile 中的默认头像复制到缓存目录，
   * 再由 RoleCardStore 将 V2/V3 元数据写入新 PNG。
   */
  async save(): Promise<void> {
    if (StrUtil.isBlank(this.state.name)) {
      ToastUtil.showToast($r('app.string.character_card_name_empty'));
      return;
    }

    try {
      let sourcePngUri = this.state.imageUri;
      if (StrUtil.isBlank(sourcePngUri)) {
        const defaultAvatarBytes = await ResUtil.getRawFileContent(RoleCardEditViewModel.DEFAULT_AVATAR_RAWFILE);
        const defaultAvatarPath = FileUtil.getCacheDirPath(
          RoleCardEditViewModel.DEFAULT_AVATAR_CACHE_DIRECTORY,
          RoleCardEditViewModel.DEFAULT_AVATAR_CACHE_FILE
        );
        if (!FileUtil.accessSync(defaultAvatarPath)) {
          const defaultAvatarBuffer = defaultAvatarBytes.buffer.slice(
            defaultAvatarBytes.byteOffset,
            defaultAvatarBytes.byteOffset + defaultAvatarBytes.byteLength
          );
          await FileUtil.writeEasy(defaultAvatarPath, defaultAvatarBuffer, false);
        }
        sourcePngUri = defaultAvatarPath;
      }

      const deleteSourceFile = this.state.editing && sourcePngUri === this.state.originalCardFilePath;
      const isWritten = await RoleCardStore.instance().writeCard(
        sourcePngUri,
        this.state.toCharacterCard(),
        deleteSourceFile
      );
      if (!isWritten) {
        ToastUtil.showToast($r('app.string.character_card_save_failed'));
        return;
      }

      // 选择新头像时，写入源文件不是旧角色卡，因此需要在新文件成功生成后再删除旧文件。
      if (this.state.editing && !deleteSourceFile) {
        await FileUtil.unlink(FileUtil.getFilePath(this.state.originalCardFilePath));
      }
      RVRouter.pop();
    } catch (error) {
      ToastUtil.showToast($r('app.string.character_card_save_failed'));
    }
  }

  /**
   * 读取传入列表项对应的 PNG，并切换到编辑场景。
   *
   * @param selectedCard 列表中被点击的角色卡。
   */
  private async loadRoleCard(selectedCard: RoleCardListItem): Promise<void> {
    const card = await RoleCardStore.instance().readCard(selectedCard.filePath);
    if (card === undefined) {
      ToastUtil.showToast($r('app.string.character_card_save_failed'));
      RVRouter.pop();
      return;
    }
    this.state.setRoleCard(selectedCard, card);
  }
}
