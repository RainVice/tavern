import { ComponentContent, FrameNode } from '@kit.ArkUI';
import { AppUtil } from '@pura/harmony-utils';
import List from '@ohos.util.List';

@ComponentV2
export struct BindSheetDialog {
  @Require @BuilderParam builder: CustomBuilder

  aboutToAppear(): void {
    const target: BindSheetDialog = this;
    BindSheetDialogController.instance().registerTarget(target);
  }

  aboutToDisappear(): void {
    const target: BindSheetDialog = this;
    BindSheetDialogController.instance().unregisterTarget(target);
  }

  build() {
    if (this.builder) {
      this.builder()
    }
  }
}

export class BindSheetDialogController {
  private static _instance?: BindSheetDialogController = undefined;
  private targets: Set<BindSheetDialog> = new Set();
  private contentStack: List<ComponentContent<Object>> = new List();

  static instance(): BindSheetDialogController {
    return BindSheetDialogController._instance ??= new BindSheetDialogController();
  }

  static show(builder: WrappedBuilder<[]>, options?: SheetOptions): Promise<void> {
    return BindSheetDialogController.instance().show(builder, options);
  }

  static showWithParam<T extends Object>(builder: WrappedBuilder<[T]>, param: T, options?: SheetOptions): Promise<void> {
    return BindSheetDialogController.instance().showWithParam(builder, param, options);
  }

  static hide(): Promise<void> {
    return BindSheetDialogController.instance().hide();
  }

  registerTarget(target: BindSheetDialog): void {
    this.targets.add(target);
  }

  unregisterTarget(target: BindSheetDialog): void {
    this.targets.delete(target);
  }

  async show(builder: WrappedBuilder<[]>, options?: SheetOptions): Promise<void> {
    const uiContext = AppUtil.getUIContext();
    const targetId = this.requireTargetId();
    const content = new ComponentContent(uiContext, builder);

    try {
      this.contentStack.add(content);
      await uiContext.openBindSheet(content, this.buildSheetOptions(options, content), targetId);
    } catch (error) {
      this.removeContent(content);
      throw new Error('打开BindSheet失败');
    }
  }

  async showWithParam<T extends Object>(builder: WrappedBuilder<[T]>, param: T, options?: SheetOptions): Promise<void> {
    const uiContext = AppUtil.getUIContext();
    const targetId = this.requireTargetId();
    const content = new ComponentContent(uiContext, builder, param);

    try {
      this.contentStack.add(content);
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
    const targets = Array.from(this.targets);
    if (targets.length === 0) {
      return 0;
    }
    const target = targets[targets.length - 1];
    const uniqueId = target.getUniqueId();
    const frameNode: FrameNode | null = target.getUIContext().getFrameNodeByUniqueId(uniqueId);
    const targetId = frameNode?.getFirstChild()?.getUniqueId();
    return targetId ?? 0;
  }

  private getTopContent(): ComponentContent<Object> | undefined {
    if (this.contentStack.length === 0) {
      return undefined;
    }
    try {
      return this.contentStack.getLast();
    } catch (error) {
      return undefined;
    }
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
    try {
      this.contentStack.remove(content);
    } catch (error) {
    }
    try {
      content.dispose();
    } catch (error) {
    }
  }
}
