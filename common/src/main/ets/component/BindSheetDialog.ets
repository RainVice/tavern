import { ComponentContent } from '@kit.ArkUI';
import { AppUtil } from '@pura/harmony-utils';
import List from '@ohos.util.List';

@ComponentV2
export struct BindSheetDialog {
  @Require @BuilderParam builder: CustomBuilder

  aboutToAppear(): void {
    BindSheetDialogController.instance().registerTarget(this.getUniqueId());
  }

  aboutToDisappear(): void {
    BindSheetDialogController.instance().unregisterTarget(this.getUniqueId());
  }

  build() {
    if (this.builder) {
      this.builder()
    }
  }
}

export class BindSheetDialogController {
  private static _instance?: BindSheetDialogController = undefined;
  private targetIds: Set<number> = new Set();
  private contentStack: List<ComponentContent<Object>> = new List();

  static instance(): BindSheetDialogController {
    return BindSheetDialogController._instance ??= new BindSheetDialogController();
  }

  static show(builder: WrappedBuilder<[]>, options?: SheetOptions): Promise<void> {
    return BindSheetDialogController.instance().show(builder, options);
  }

  static hide(): Promise<void> {
    return BindSheetDialogController.instance().hide();
  }

  registerTarget(targetId: number): void {
    this.targetIds.add(targetId);
  }

  unregisterTarget(targetId: number): void {
    this.targetIds.delete(targetId);
  }

  async show(builder: WrappedBuilder<[]>, options?: SheetOptions): Promise<void> {
    const uiContext = AppUtil.getUIContext();
    const targetId = this.requireTargetId();
    const content = new ComponentContent(uiContext, builder);
    this.contentStack.add(content);

    try {
      await uiContext.openBindSheet(content, this.buildSheetOptions(options, content), targetId);
    } catch (error) {
      this.removeContent(content);
      throw new Error('打开BindSheet失败');
    }
  }

  async hide(): Promise<void> {
    const content = this.getTopContent();
    if (content === undefined) {
      return;
    }

    const uiContext = AppUtil.getUIContext();
    try {
      await uiContext.closeBindSheet(content);
    } catch (error) {
      throw new Error('关闭BindSheet失败');
    } finally {
      this.removeContent(content);
    }
  }

  private requireTargetId(): number {
    const targetId = this.getCurrentTargetId();
    if (targetId === 0) {
      throw new Error('BindSheet根组件尚未挂载');
    }
    return targetId;
  }

  private getCurrentTargetId(): number {
    const targetIds = Array.from(this.targetIds);
    if (targetIds.length === 0) {
      return 0;
    }
    return targetIds[targetIds.length - 1];
  }

  private getTopContent(): ComponentContent<Object> | undefined {
    if (this.contentStack.length === 0) {
      return undefined;
    }
    return this.contentStack[this.contentStack.length - 1];
  }

  private buildSheetOptions(options: SheetOptions | undefined, content: ComponentContent<Object>): SheetOptions {
    const sheetOptions = options ?? BindSheetDialogController.defaultSheetOptions();
    const onDisappear = sheetOptions.onDisappear;
    sheetOptions.onDisappear = () => {
      this.removeContent(content);
      if (onDisappear !== undefined) {
        onDisappear();
      }
    };
    return sheetOptions;
  }

  private static defaultSheetOptions(): SheetOptions {
    return {
      height: SheetSize.FIT_CONTENT,
      preferType: SheetType.POPUP,
      showClose: false,
      dragBar: false,
    };
  }

  private removeContent(content: ComponentContent<Object>): void {
    this.contentStack.remove(content)
    try {
      content.dispose();
    } catch (error) {
    }
  }
}
