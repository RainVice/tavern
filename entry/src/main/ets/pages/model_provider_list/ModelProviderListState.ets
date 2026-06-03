import { ModelProvider } from "../../db/entity/ModelProviderEntity";

@ObservedV2
export class ModelProviderListState {
  @Trace providers: ModelProvider[] = []
}