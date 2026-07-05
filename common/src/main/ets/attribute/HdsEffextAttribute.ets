import { CommonAttributeUpdater } from './CommonAttributeUpdater';
import { AttributeUpdater } from '@kit.ArkUI';
import { hdsEffect } from '@kit.UIDesignKit';

export function hdsEffectAttribute(
  options: hdsEffect.PointLightOptions = {
    color: $r("sys.color.background_emphasize"),
    intensity: 1,
    height: 200,
    bloom: 0.5,
  }
): AttributeUpdater<CommonAttribute> {
  return new CommonAttributeUpdater(symbolAttr => {
    symbolAttr.visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER,
        options: options,
      }).buildEffect()
    )
  });
}