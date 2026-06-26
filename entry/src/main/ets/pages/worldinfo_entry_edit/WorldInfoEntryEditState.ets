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
}
