import { RVRouter, RouterName } from 'router'

interface ModelProviderItem {
  name: string;
  apiType: string;
}

export class ModelProviderListViewModel {
  providers: ModelProviderItem[] = [
    { name: 'OpenAI', apiType: 'OpenAI' },
    { name: 'Claude', apiType: 'Anthropic' },
  ]

  onAdd() {
    RVRouter.push(RouterName.ModelProviderEdit)
  }

  onProviderClick(index: number) {
    RVRouter.push(RouterName.ModelProviderEdit, this.providers[index])
  }
}
