import { OpenAIRequestClient } from './core/OpenAIRequestClient';
import type { OpenAIClientOptions } from './core/Types';
import { AudioResource, type OpenAIAudioResource } from './resources/AudioResource';
import { BatchesResource, type OpenAIBatchesResource } from './resources/BatchesResource';
import { BetaResource, type OpenAIBetaResource } from './resources/BetaResource';
import { ChatKitResource, type OpenAIChatKitResource } from './resources/ChatKitResource';
import { ChatResource, type OpenAIChatResource } from './resources/ChatResource';
import { CompletionsResource, type OpenAICompletionsResource } from './resources/CompletionsResource';
import { ContainersResource, type OpenAIContainersResource } from './resources/ContainersResource';
import { ConversationsResource, type OpenAIConversationsResource } from './resources/ConversationsResource';
import { EmbeddingsResource, type OpenAIEmbeddingsResource } from './resources/EmbeddingsResource';
import { EvalsResource, type OpenAIEvalsResource } from './resources/EvalsResource';
import { FilesResource, type OpenAIFilesResource } from './resources/FilesResource';
import { FineTuningResource, type OpenAIFineTuningResource } from './resources/FineTuningResource';
import { ImagesResource, type OpenAIImagesResource } from './resources/ImagesResource';
import { ModelsResource, type OpenAIModelsResource } from './resources/ModelsResource';
import { ModerationsResource, type OpenAIModerationsResource } from './resources/ModerationsResource';
import { OrganizationResource, type OpenAIOrganizationResource } from './resources/OrganizationResource';
import { RealtimeResource, type OpenAIRealtimeResource } from './resources/RealtimeResource';
import { ResponsesResource, type OpenAIResponsesResource } from './resources/ResponsesResource';
import { UploadsResource, type OpenAIUploadsResource } from './resources/UploadsResource';
import { VectorStoresResource, type OpenAIVectorStoresResource } from './resources/VectorStoresResource';
import { VideosResource, type OpenAIVideosResource } from './resources/VideosResource';
import { WebhooksResource, type OpenAIWebhooksResource } from './resources/WebhooksResource';

/**
 * OpenAI SDK 入口。
 *
 * API：所有 OpenAI REST API。
 * 说明：当前先实现 `models.list()`，后续可继续挂载 `responses`、`chat`、`embeddings` 等资源。
 *
 * 示例：
 * ```ts
 * const client = new OpenAI({ apiKey: 'sk-...' });
 * const models = await client.models.list();
 * ```
 */
export class OpenAI {
  /** Realtime WebRTC 语音所需权限。API：Realtime WebRTC。说明：宿主应用需要在 module.json5 申请。 */
  static realtimeRequiredPermissions(): Array<string> {
    return ['ohos.permission.MICROPHONE'];
  }

  /**
   * Models API。
   *
   * API：`GET /v1/models`。
   * 说明：使用 `client.models.list()` 获取模型列表。
   */
  models: OpenAIModelsResource;
  audio: OpenAIAudioResource;
  beta: OpenAIBetaResource;
  responses: OpenAIResponsesResource;
  chat: OpenAIChatResource;
  chatkit: OpenAIChatKitResource;
  completions: OpenAICompletionsResource;
  containers: OpenAIContainersResource;
  conversations: OpenAIConversationsResource;
  embeddings: OpenAIEmbeddingsResource;
  evals: OpenAIEvalsResource;
  images: OpenAIImagesResource;
  files: OpenAIFilesResource;
  fineTuning: OpenAIFineTuningResource;
  moderations: OpenAIModerationsResource;
  organization: OpenAIOrganizationResource;
  realtime: OpenAIRealtimeResource;
  batches: OpenAIBatchesResource;
  uploads: OpenAIUploadsResource;
  vectorStores: OpenAIVectorStoresResource;
  videos: OpenAIVideosResource;
  webhooks: OpenAIWebhooksResource;

  constructor(options: OpenAIClientOptions) {
    const client = new OpenAIRequestClient(options);
    this.models = new ModelsResource(client);
    this.audio = new AudioResource(client);
    this.beta = new BetaResource(client);
    this.responses = new ResponsesResource(client);
    this.chat = new ChatResource(client);
    this.chatkit = new ChatKitResource(client);
    this.completions = new CompletionsResource(client);
    this.containers = new ContainersResource(client);
    this.conversations = new ConversationsResource(client);
    this.embeddings = new EmbeddingsResource(client);
    this.evals = new EvalsResource(client);
    this.images = new ImagesResource(client);
    this.files = new FilesResource(client);
    this.fineTuning = new FineTuningResource(client);
    this.moderations = new ModerationsResource(client);
    this.organization = new OrganizationResource(client);
    this.realtime = new RealtimeResource(client);
    this.batches = new BatchesResource(client);
    this.uploads = new UploadsResource(client);
    this.vectorStores = new VectorStoresResource(client);
    this.videos = new VideosResource(client);
    this.webhooks = new WebhooksResource(options.webhookSecret);
  }
}
