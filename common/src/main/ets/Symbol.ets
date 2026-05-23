import { SymbolGlyphModifier } from '@kit.ArkUI'

export function symbolModifier(res: Resource) {
  return new SymbolGlyphModifier(res)
    .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
    .effectStrategy(SymbolEffectStrategy.HIERARCHICAL)

}