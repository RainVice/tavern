/**
 * 百分比
 */
export const FullPercent = percent(100)
export const HalfPercent = percent(50)
export const ZeroPercent = percent(0)
export function percent(value: number): Percentage {
  return `${value}%`
}
