import { AttributeUpdater } from '@kit.ArkUI';
import { hdsEffect } from '@kit.UIDesignKit';

export class CommonAttributeUpdater<T> extends AttributeUpdater<T> {
  private callback?: (t: T) => void;

  constructor(callback?: (t: T) => void) {
    super();
    this.callback = callback;
  }

  override initializeModifier(instance: T): void {
    this.callback?.(instance);
  }
}

export function defaultAttribute<T>(callback: (t: T) => void): AttributeUpdater<T> {
  return new CommonAttributeUpdater(callback);
}

export function hdsAttribute<T extends CommonAttribute>(): AttributeUpdater<T> {
  return new CommonAttributeUpdater(t => {
    t.visualEffect(
      new hdsEffect.HdsEffectBuilder()
        .pointLight({
          sourceType: hdsEffect.PointLightSourceType.BRIGHT,
          illuminatedType: hdsEffect.PointLightIlluminatedType.CONTENT,
        })
        .pressShadow(hdsEffect.PressShadowType.BLEND_WHITE)
        .buildEffect()
    )
  });
}