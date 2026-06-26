@ObservedV2
export class WorldInfoEntryEditState {
  @Trace worldBookId: string = ''
  @Trace entryId: string = ''
  @Trace comment: string = ''
  @Trace keysText: string = ''
  @Trace secondaryKeysText: string = ''
  @Trace content: string = ''
  @Trace constant: boolean = false
  @Trace selective: boolean = false
  @Trace enabled: boolean = true
  @Trace insertionOrderText: string = '100'
  @Trace position: string = 'before'
  @Trace caseSensitive: boolean = false
  @Trace matchWholeWords: boolean = false
  @Trace probabilityText: string = '100'
  @Trace excludeRecursion: boolean = false
  @Trace depthText: string = '0'
  @Trace scanDepthText: string = '0'
  @Trace role: string = 'all'
  @Trace group: string = ''
  @Trace groupOverride: boolean = false
  @Trace groupWeightText: string = '100'
  @Trace automationId: string = ''
}
