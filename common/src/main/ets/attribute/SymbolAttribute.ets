import { AttributeUpdater, SymbolGlyphModifier } from '@kit.ArkUI';
import { CommonAttributeUpdater } from './CommonAttributeUpdater';

export function symbolSpanAttribute(): AttributeUpdater<SymbolSpanAttribute> {
  return new CommonAttributeUpdater(symbolAttr => {
    symbolAttr.renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
      .effectStrategy(SymbolEffectStrategy.HIERARCHICAL)
  });
}

export function symbolGlyphAttribute(): AttributeUpdater<SymbolGlyphAttribute> {
  return new CommonAttributeUpdater(symbolAttr => {
    symbolAttr.renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
      .effectStrategy(SymbolEffectStrategy.HIERARCHICAL)
  });
}

export function symbolModifier(res: Resource) {
  return new SymbolGlyphModifier(res)
    .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
    .effectStrategy(SymbolEffectStrategy.HIERARCHICAL)
}