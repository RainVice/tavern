@ObservedV2
export class ModelProviderEditState {
  @Trace id: string = ''
  @Trace name: string = ''
  @Trace secretRef: string = ''
  @Trace serverUrl: string = ''
  @Trace model: string = ''
  @Trace availableModels: Array<string> = []
  @Trace isDefault: boolean = false

  isShowGetModel(): boolean {
    return this.secretRef !== '' && this.serverUrl !== ''
  }
}
