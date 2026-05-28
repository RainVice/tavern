import { describe, it, expect } from '@ohos/hypium';
import {
  OpenAI,
  type AssistantCreateParams,
  type AssistantDeleted,
  type AssistantObject,
  type AssistantStreamHandlers,
  type AssistantThread,
  type AssistantThreadDeleted,
  type BatchObject,
  type ChatCompletion,
  type ChatCompletionDeleted,
  type ChatCompletionListResponse,
  type ChatKitSession,
  type ChatKitResponseOutputTextFileSource,
  type ChatKitResponseOutputTextFileAnnotation,
  type ChatKitUploadStrategy,
  type ChatKitThread,
  type ChatKitThreadDeleted,
  type ChatKitThreadItemListResponse,
  type ChatKitThreadListResponse,
  type Completion,
  type Container,
  type ContainerDeleted,
  type ContainerFile,
  type ContainerFileDeleted,
  type ContainerFileListResponse,
  type Conversation,
  type ConversationDeleted,
  type ConversationItem,
  type ConversationItemListResponse,
  type CreateEmbeddingResponse,
  type EvalObject,
  type EvalRun,
  type EvalRunOutputItem,
  type EvalRunOutputItemListResponse,
  type EvalRunListResponse,
  type EvalDeleted,
  type EvalStringCheckGrader,
  type FileListResponse,
  type FileObject,
  type FineTuningCheckpointPermission,
  type FineTuningCheckpointPermissionCreateParams,
  type FineTuningCheckpointPermissionDeleted,
  type FineTuningCheckpointPermissionListResponse,
  type FineTuningGraderRunParams,
  type FineTuningGraderRunResponse,
  type FineTuningGraderValidateResponse,
  type FineTuningJob,
  type FineTuningJobCheckpointListResponse,
  type FineTuningJobEventListResponse,
  type ImagesResponse,
  type ModelObject,
  type ModerationCreateResponse,
  type FileDownloadOptions,
  type FileContentWriter,
  type JsonObject,
  type OpenAIClientOptions,
  type OpenAIRequestOptions,
  type OpenAIRequestSettings,
  type OpenAIResponse,
  OpenAICancelToken,
  OpenAISSEParser,
  type OpenAISSEEvent,
  type OpenAIStream,
  type OpenAIStreamChunkHandler,
  type OpenAITransport,
  type OpenAIWebhookEvent,
  type OpenAIWebhookResourceEvent,
  OpenAIWebhookSignatureError,
  type RealtimeClientEvent,
  type RealtimeClientSecret,
  type RealtimeWebSocketOptions,
  type RealtimeWebRTCOptions,
  type RealtimeServerEvent,
  type RealtimeTranscriptionSession,
  type ResponseObject,
  type ResponseOutputItem,
  type SpeechResponse,
  type Transcription,
  type Upload,
  type UploadPart,
  type VectorStore,
  type VectorStoreDeleted,
  type VectorStoreFile,
  type VectorStoreFileBatch,
  type VectorStoreSearchResponse,
  type Voice,
  type VoiceConsent,
  type VoiceConsentDeleted,
  type VoiceConsentListResponse,
  type VideoCharacter,
  type VideoCharacterCreateParams,
  type ResponseCreateParams,
  type RunCreateParams,
  type AssistantStreamEvent,
  type RunStep,
  type RunStepListResponse,
  type ChatCompletionCreateParams,
  type ChatKitSessionCreateParams,
  type ContainerCreateParams,
  type ContainerFileCreateParams,
  type ConversationCreateParams,
  type ConversationItemCreateParams,
  type EmbeddingCreateParams,
  type EvalCreateParams,
  type EvalRunCreateParams,
  type ImageGenerateParams,
  type ImageStreamingEvent,
  type SpeechCreateParams,
  type TranscriptionCreateParams,
  type UploadCreateParams,
  type VoiceConsentCreateParams,
  type VoiceCreateParams,
  type FileCreateParams,
  type BatchCreateParams,
  type FineTuningJobCreateParams,
  type MessageCreateParams,
  type ModerationCreateParams,
  type OrganizationAdminApiKey,
  type OrganizationAdminApiKeyCreateParams,
  type OrganizationAdminApiKeyDeleted,
  type OrganizationAdminApiKeyListResponse,
  type OrganizationAuditLogListResponse,
  type OrganizationCertificate,
  type OrganizationCertificateCreateParams,
  type OrganizationCertificateDeleted,
  type OrganizationCertificateListResponse,
  type OrganizationCertificateUpdateParams,
  type OrganizationCertificateActivationResponse,
  type OrganizationCertificateToggleParams,
  type OrganizationGroup,
  type OrganizationGroupCreateParams,
  type OrganizationGroupDeleted,
  type OrganizationGroupListResponse,
  type OrganizationGroupUpdateParams,
  type OrganizationGroupUser,
  type OrganizationGroupUserCreateParams,
  type OrganizationGroupUserDeleted,
  type OrganizationGroupUserListResponse,
  type OrganizationInvite,
  type OrganizationInviteCreateParams,
  type OrganizationInviteDeleted,
  type OrganizationInviteListResponse,
  type OrganizationInviteProject,
  type OrganizationProject,
  type OrganizationProjectApiKey,
  type OrganizationProjectApiKeyDeleted,
  type OrganizationProjectApiKeyListResponse,
  type OrganizationProjectCreateParams,
  type OrganizationProjectGroup,
  type OrganizationProjectGroupCreateParams,
  type OrganizationProjectGroupDeleted,
  type OrganizationProjectGroupListResponse,
  type OrganizationProjectListResponse,
  type OrganizationProjectRateLimit,
  type OrganizationProjectRateLimitListResponse,
  type OrganizationProjectRateLimitUpdateParams,
  type OrganizationRole,
  type OrganizationRoleCreateParams,
  type OrganizationRoleDeleted,
  type OrganizationRoleListResponse,
  type OrganizationRoleUpdateParams,
  type OrganizationProjectServiceAccount,
  type OrganizationProjectServiceAccountCreateParams,
  type OrganizationProjectServiceAccountDeleted,
  type OrganizationProjectServiceAccountListResponse,
  type OrganizationProjectUser,
  type OrganizationProjectUserCreateParams,
  type OrganizationProjectUserDeleted,
  type OrganizationProjectUserListResponse,
  type OrganizationProjectUserUpdateParams,
  type OrganizationProjectUpdateParams,
  type OrganizationUser,
  type OrganizationUserDeleted,
  type OrganizationUserListResponse,
  type OrganizationUserUpdateParams,
  type RealtimeClientSecretCreateParams,
  type RealtimeTranscriptionSessionCreateParams,
  type ThreadCreateParams,
  type ThreadMessage,
  type ThreadMessageListResponse,
  type ThreadRun,
  type ThreadRunListResponse,
  type VectorStoreCreateParams,
  type VideoCreateParams,
  type VideoDeleted,
  type VideoEditParams,
  type VideoExtendParams,
  type VideoJob,
  type VideoListResponse,
  type VideoRemixParams,
} from '../../Index';

class FakeTransport implements OpenAITransport {
  latestUrl: string = '';
  latestMethod: string = '';
  latestHeaders: Record<string, string> = {};
  latestBody: string = '';
  latestMultipartCount: number = 0;
  latestResponseDataType: string = '';
  latestReadTimeout: number = 0;
  latestConnectTimeout: number = 0;
  latestStreamChunkCount: number = 0;
  nextBody: string = '{"object":"list","data":[{"id":"gpt-4o","object":"model","created":1710000000,"owned_by":"openai"}]}';
  nextStatusCode: number = 200;
  requestCount: number = 0;
  responseBodies: Array<string> = [];
  responseStatusCodes: Array<number> = [];

  async request(options: OpenAIRequestOptions): Promise<OpenAIResponse> {
    const responseIndex = this.requestCount;
    this.requestCount += 1;
    this.latestUrl = options.url;
    this.latestMethod = options.method;
    this.latestHeaders = options.headers;
    this.latestBody = options.body === undefined ? '' : options.body;
    this.latestMultipartCount = options.multipart === undefined ? 0 : options.multipart.length;
    this.latestResponseDataType = options.responseDataType === undefined ? '' : options.responseDataType;
    this.latestReadTimeout = options.readTimeout;
    this.latestConnectTimeout = options.connectTimeout;
    const statusCode = responseIndex < this.responseStatusCodes.length ?
      this.responseStatusCodes[responseIndex] : this.nextStatusCode;
    const body = responseIndex < this.responseBodies.length ? this.responseBodies[responseIndex] : this.nextBody;
    return {
      statusCode: statusCode,
      body: body,
    };
  }

  stream(options: OpenAIRequestOptions, onChunk: OpenAIStreamChunkHandler): OpenAIStream {
    this.request(options);
    this.latestStreamChunkCount += 1;
    onChunk(this.nextBody);
    return new FakeOpenAIStream(this);
  }
}

class FakeOpenAIStream implements OpenAIStream {
  private transport: FakeTransport;
  closed: boolean = false;

  constructor(transport: FakeTransport) {
    this.transport = transport;
  }

  close(): void {
    this.closed = true;
    this.transport.latestStreamChunkCount += 1;
  }
}

class FakeFileContentWriter implements FileContentWriter {
  path: string = '';
  content: string = '';

  write(destinationPath: string, contentBody: string): number {
    this.path = destinationPath;
    this.content = contentBody;
    return contentBody.length;
  }
}

class CollectAssistantStreamHandlers implements AssistantStreamHandlers {
  events: Array<AssistantStreamEvent> = [];

  onEvent(event: AssistantStreamEvent): void {
    this.events.push(event);
  }
}

export default function modelsUnitTest() {
  describe('modelsUnitTest', () => {
    it('constructsCoreOpenAIRequests', 0, () => {
      const responseRequest: ResponseCreateParams = {
        model: 'gpt-5.4',
        input: '你好',
      };
      const chatRequest: ChatCompletionCreateParams = {
        model: 'gpt-5.4',
        messages: [{ role: 'user', content: '你好' }],
      };
      const embeddingRequest: EmbeddingCreateParams = {
        model: 'text-embedding-3-small',
        input: '鸿蒙 OpenAI SDK',
      };
      const imageRequest: ImageGenerateParams = {
        prompt: 'A clean SDK logo',
        model: 'gpt-image-1',
        stream: true,
        partial_images: 2,
      };
      const speechRequest: SpeechCreateParams = {
        model: 'gpt-4o-mini-tts',
        input: '你好',
        voice: 'alloy',
      };
      const transcriptionRequest: TranscriptionCreateParams = {
        file: 'file://audio.wav',
        model: 'gpt-4o-transcribe',
      };
      const fileRequest: FileCreateParams = {
        file: 'file://batch.jsonl',
        purpose: 'batch',
      };
      const batchRequest: BatchCreateParams = {
        input_file_id: 'file_123',
        endpoint: '/v1/responses',
        completion_window: '24h',
      };
      const moderationRequest: ModerationCreateParams = {
        input: '需要审核的内容',
      };

      expect(responseRequest.input).assertEqual('你好');
      expect(chatRequest.messages.length).assertEqual(1);
      expect(embeddingRequest.model).assertEqual('text-embedding-3-small');
      expect(imageRequest.prompt).assertContain('SDK');
      expect(imageRequest.partial_images).assertEqual(2);
      expect(speechRequest.voice).assertEqual('alloy');
      expect(transcriptionRequest.file).assertContain('audio.wav');
      expect(fileRequest.purpose).assertEqual('batch');
      expect(batchRequest.completion_window).assertEqual('24h');
      expect(moderationRequest.input).assertEqual('需要审核的内容');
    });

    it('parsesWebhookEventsWithOpenAIClient', 0, () => {
      const payload = '{"id":"evt_abc123","type":"response.completed","created_at":1719168000,"object":"event","data":{"id":"resp_abc123"}}';
      const client = new OpenAI({ apiKey: 'sk-test', webhookSecret: 'whsec_test' });

      const event: OpenAIWebhookEvent = client.webhooks.parse(payload);
      const resourceEvent = event as OpenAIWebhookResourceEvent;

      expect(event.id).assertEqual('evt_abc123');
      expect(event.type).assertEqual('response.completed');
      expect(resourceEvent.data.id).assertEqual('resp_abc123');

      let failed = false;
      try {
        client.webhooks.unwrap(payload, {}, 'whsec_test', { toleranceInSeconds: 0 });
      } catch (error) {
        failed = error instanceof OpenAIWebhookSignatureError;
      }
      expect(failed).assertEqual(true);
    });

    it('parsesServerSentEventsIncrementally', 0, () => {
      const parser = new OpenAISSEParser();

      const firstEvents: Array<OpenAISSEEvent> = parser.push('event: response.created\ndata: {"id":"resp_123"}');
      const secondEvents: Array<OpenAISSEEvent> = parser.push('\n\ndata: [DONE]\n\n');

      expect(firstEvents.length).assertEqual(0);
      expect(secondEvents.length).assertEqual(2);
      expect(secondEvents[0].event).assertEqual('response.created');
      expect(secondEvents[0].data).assertContain('resp_123');
      expect(secondEvents[1].data).assertEqual('[DONE]');
    });

    it('requestsModelsListWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      const client = new OpenAI({
        apiKey: 'sk-test',
        baseURL: 'https://example.test/v1',
        organization: 'org_test',
        project: 'proj_test',
        transport: transport,
      });

      const response = await client.models.list();

      expect(transport.latestUrl).assertEqual('https://example.test/v1/models');
      expect(transport.latestMethod).assertEqual('GET');
      expect(transport.latestHeaders['Authorization']).assertEqual('Bearer sk-test');
      expect(transport.latestHeaders['OpenAI-Organization']).assertEqual('org_test');
      expect(transport.latestHeaders['OpenAI-Project']).assertEqual('proj_test');
      expect(response.object).assertEqual('list');
      expect(response.data[0].id).assertEqual('gpt-4o');
    });

    it('retriesTransientServerErrorsWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.responseStatusCodes = [500, 200];
      transport.responseBodies = [
        '{"error":{"message":"temporary"}}',
        '{"object":"list","data":[{"id":"gpt-4o-mini","object":"model","created":1710000000,"owned_by":"openai"}]}',
      ];
      const client = new OpenAI({
        apiKey: 'sk-test',
        baseURL: 'https://example.test/v1',
        maxRetries: 1,
        transport: transport,
      });

      const response = await client.models.list();

      expect(transport.requestCount).assertEqual(2);
      expect(response.data[0].id).assertEqual('gpt-4o-mini');
    });

    it('appliesRequestControlsWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      const cancelToken = new OpenAICancelToken();
      const defaultHeaders: Record<string, string> = {
        'X-SDK-Test': 'default',
      };
      const clientOptions: OpenAIClientOptions = {
        apiKey: 'sk-test',
        baseURL: 'https://example.test/v1',
        readTimeout: 12000,
        connectTimeout: 3000,
        defaultHeaders: defaultHeaders,
        transport: transport,
      };
      const client = new OpenAI(clientOptions);
      const requestHeaders: Record<string, string> = {
        'X-SDK-Test': 'override',
      };
      const requestOptions: OpenAIRequestSettings = {
        readTimeout: 5000,
        connectTimeout: 1500,
        headers: requestHeaders,
        cancelToken: cancelToken,
      };

      const response = await client.models.list(requestOptions);

      expect(response.object).assertEqual('list');
      expect(transport.latestReadTimeout).assertEqual(5000);
      expect(transport.latestConnectTimeout).assertEqual(1500);
      expect(transport.latestHeaders['X-SDK-Test']).assertEqual('override');
      expect(cancelToken.isCancelled()).assertEqual(false);
      cancelToken.cancel();
      expect(cancelToken.isCancelled()).assertEqual(true);
    });

    it('createsResponseWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"resp_123","object":"response","created_at":1710000000,"status":"completed","output_text":"你好","model":"gpt-5.4","output":[],"error":null,"incomplete_details":null,"metadata":null}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: ResponseObject = await client.responses.create({
        model: 'gpt-5.4',
        input: '你好',
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/responses');
      expect(transport.latestMethod).assertEqual('POST');
      expect(transport.latestBody).assertContain('"input":"你好"');
      expect(response.id).assertEqual('resp_123');
      expect(response.output_text).assertEqual('你好');
    });

    it('constructsResponsesAdvancedTools', 0, () => {
      const request: ResponseCreateParams = {
        model: 'gpt-5.4',
        input: 'Analyze the spreadsheet and create a chart',
        tools: [
          {
            type: 'code_interpreter',
            container: {
              type: 'auto',
              memory_limit: '4g',
              file_ids: ['file_123'],
            },
          },
          {
            type: 'image_generation',
            partial_images: 2,
            quality: 'high',
            size: '1024x1024',
          },
          {
            type: 'mcp',
            server_label: 'drive',
            connector_id: 'connector_google_drive',
            require_approval: 'never',
          },
          {
            type: 'apply_patch',
          },
          {
            type: 'local_shell',
          },
        ],
      };
      const outputItem: ResponseOutputItem = {
        type: 'reasoning',
        encrypted_content: 'encrypted',
      };

      expect(request.tools![0].type).assertEqual('code_interpreter');
      expect(outputItem.type).assertEqual('reasoning');
    });

    it('createsChatCompletionWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"chatcmpl_123","object":"chat.completion","created":1710000000,"model":"gpt-5.4","choices":[{"index":0,"finish_reason":"stop","message":{"role":"assistant","content":"你好"}}]}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: ChatCompletion = await client.chat.completions.create({
        model: 'gpt-5.4',
        messages: [{ role: 'user', content: '你好' }],
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/chat/completions');
      expect(transport.latestMethod).assertEqual('POST');
      expect(transport.latestBody).assertContain('"messages"');
      expect(response.choices[0].message.content).assertEqual('你好');
    });

    it('listsAndDeletesStoredChatCompletionWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"object":"list","data":[{"id":"chatcmpl_123","object":"chat.completion","created":1710000000,"model":"gpt-5.4","choices":[]}]}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const listResponse: ChatCompletionListResponse = await client.chat.completions.list({
        model: 'gpt-5.4',
        limit: 10,
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/chat/completions?model=gpt-5.4&limit=10');
      expect(listResponse.data[0].id).assertEqual('chatcmpl_123');

      transport.nextBody = '{"id":"chatcmpl_123","object":"chat.completion.deleted","deleted":true}';
      const deleted: ChatCompletionDeleted = await client.chat.completions.delete('chatcmpl_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/chat/completions/chatcmpl_123');
      expect(transport.latestMethod).assertEqual('DELETE');
      expect(deleted.deleted).assertEqual(true);
    });

    it('createsEmbeddingWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"object":"list","data":[{"object":"embedding","embedding":[0.1,0.2],"index":0}],"model":"text-embedding-3-small","usage":{"prompt_tokens":3,"total_tokens":3}}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: CreateEmbeddingResponse = await client.embeddings.create({
        model: 'text-embedding-3-small',
        input: '鸿蒙 OpenAI SDK',
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/embeddings');
      expect(transport.latestMethod).assertEqual('POST');
      expect(response.data[0].index).assertEqual(0);
      expect(response.usage.total_tokens).assertEqual(3);
    });

    it('createsModerationWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"modr_123","model":"omni-moderation-latest","results":[{"flagged":false,"categories":{"violence":false},"category_scores":{"violence":0.01}}]}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: ModerationCreateResponse = await client.moderations.create({
        input: '需要审核的内容',
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/moderations');
      expect(transport.latestMethod).assertEqual('POST');
      expect(response.id).assertEqual('modr_123');
      expect(response.results[0].flagged).assertEqual(false);
    });

    it('createsBatchWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"batch_123","object":"batch","endpoint":"/v1/responses","input_file_id":"file_123","completion_window":"24h","status":"validating","created_at":1710000000}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: BatchObject = await client.batches.create({
        input_file_id: 'file_123',
        endpoint: '/v1/responses',
        completion_window: '24h',
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/batches');
      expect(transport.latestMethod).assertEqual('POST');
      expect(response.id).assertEqual('batch_123');
      expect(response.endpoint).assertEqual('/v1/responses');
    });

    it('createsLegacyCompletionWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"cmpl_123","object":"text_completion","created":1710000000,"model":"gpt-3.5-turbo-instruct","choices":[{"text":" world","index":0,"finish_reason":"stop"}]}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: Completion = await client.completions.create({
        model: 'gpt-3.5-turbo-instruct',
        prompt: 'hello',
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/completions');
      expect(transport.latestMethod).assertEqual('POST');
      expect(response.choices[0].text).assertEqual(' world');
    });

    it('generatesImageWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"created":1710000000,"data":[{"b64_json":"abc123"}],"output_format":"png","size":"1024x1024"}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: ImagesResponse = await client.images.generate({
        model: 'gpt-image-1',
        prompt: 'A clean SDK logo',
        stream: true,
        partial_images: 2,
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/images/generations');
      expect(transport.latestMethod).assertEqual('POST');
      expect(transport.latestBody).assertContain('"partial_images":2');
      expect(response.data![0].b64_json).assertEqual('abc123');
    });

    it('modelsImageStreamingEvents', 0, () => {
      const partialEvent: ImageStreamingEvent = {
        type: 'image_generation.partial_image',
        b64_json: 'partial',
        created_at: 1710000000,
        size: '1024x1024',
        quality: 'high',
        background: 'transparent',
        output_format: 'png',
        partial_image_index: 0,
      };
      const completedEvent: ImageStreamingEvent = {
        type: 'image_edit.completed',
        b64_json: 'final',
        created_at: 1710000001,
        size: '1024x1024',
        quality: 'high',
        background: 'transparent',
        output_format: 'png',
        usage: {
          input_tokens: 50,
          output_tokens: 50,
          total_tokens: 100,
        },
      };

      expect(partialEvent.type).assertEqual('image_generation.partial_image');
      expect(completedEvent.usage!.total_tokens).assertEqual(100);
    });

    it('retrievesModelWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"gpt-4o","object":"model","created":1710000000,"owned_by":"openai"}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: ModelObject = await client.models.retrieve('gpt-4o');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/models/gpt-4o');
      expect(transport.latestMethod).assertEqual('GET');
      expect(response.id).assertEqual('gpt-4o');
    });

    it('listsFilesWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"object":"list","data":[{"id":"file_123","object":"file","bytes":10,"created_at":1710000000,"filename":"input.jsonl","purpose":"batch"}]}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: FileListResponse = await client.files.list({
        purpose: 'batch',
        limit: 20,
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/files?purpose=batch&limit=20');
      expect(transport.latestMethod).assertEqual('GET');
      expect(response.data[0].id).assertEqual('file_123');
    });

    it('createsFileWithMultipartOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"file_123","object":"file","bytes":10,"created_at":1710000000,"filename":"input.jsonl","purpose":"batch"}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: FileObject = await client.files.create({
        file: 'file://input.jsonl',
        purpose: 'batch',
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/files');
      expect(transport.latestMethod).assertEqual('POST');
      expect(transport.latestMultipartCount).assertEqual(2);
      expect(response.id).assertEqual('file_123');
    });

    it('createsSpeechWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = 'base64-audio';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: SpeechResponse = await client.audio.speech.create({
        model: 'gpt-4o-mini-tts',
        input: '你好',
        voice: 'alloy',
        response_format: 'mp3',
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/audio/speech');
      expect(transport.latestMethod).assertEqual('POST');
      expect(transport.latestResponseDataType).assertEqual('arraybuffer');
      expect(response.data).assertEqual('base64-audio');
      expect(response.response_format).assertEqual('mp3');
    });

    it('createsAudioTranscriptionWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"text":"hello"}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: Transcription = await client.audio.transcriptions.create({
        file: 'file://audio.wav',
        model: 'gpt-4o-transcribe',
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/audio/transcriptions');
      expect(transport.latestMethod).assertEqual('POST');
      expect(transport.latestMultipartCount).assertEqual(2);
      expect(response.text).assertEqual('hello');
    });

    it('createsAudioTranslationWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"text":"hello"}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: Transcription = await client.audio.translations.create({
        file: 'file://audio.wav',
        model: 'whisper-1',
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/audio/translations');
      expect(transport.latestMethod).assertEqual('POST');
      expect(transport.latestMultipartCount).assertEqual(2);
      expect(response.text).assertEqual('hello');
    });

    it('editsImageWithMultipartOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"created":1710000000,"data":[{"b64_json":"edited"}]}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: ImagesResponse = await client.images.edit({
        image: 'file://image.png',
        input_fidelity: 'high',
        model: 'gpt-image-1',
        partial_images: 1,
        prompt: 'Edit image',
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/images/edits');
      expect(transport.latestMethod).assertEqual('POST');
      expect(transport.latestMultipartCount).assertEqual(5);
      expect(response.data![0].b64_json).assertEqual('edited');
    });

    it('createsImageVariationWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"created":1710000000,"data":[{"url":"https://example.test/image.png"}]}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: ImagesResponse = await client.images.createVariation({
        image: 'file://image.png',
        model: 'dall-e-2',
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/images/variations');
      expect(transport.latestMethod).assertEqual('POST');
      expect(transport.latestMultipartCount).assertEqual(2);
      expect(response.data![0].url).assertEqual('https://example.test/image.png');
    });

    it('readsFileContentWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"custom_id":"row-1"}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: string = await client.files.content('file_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/files/file_123/content');
      expect(transport.latestMethod).assertEqual('GET');
      expect(response).assertContain('row-1');
    });

    it('downloadsFileContentWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"custom_id":"row-1"}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });
      const writer = new FakeFileContentWriter();
      const downloadOptions: FileDownloadOptions = {
        writer: writer,
      };

      const downloaded = await client.files.download('file_123', '/tmp/openai-output.jsonl', downloadOptions);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/files/file_123/content');
      expect(writer.path).assertEqual('/tmp/openai-output.jsonl');
      expect(writer.content).assertContain('row-1');
      expect(downloaded.path).assertEqual('/tmp/openai-output.jsonl');
      expect(downloaded.bytes).assertEqual(writer.content.length);
    });

    it('cancelsBatchWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"batch_123","object":"batch","endpoint":"/v1/responses","input_file_id":"file_123","completion_window":"24h","status":"cancelling","created_at":1710000000}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const response: BatchObject = await client.batches.cancel('batch_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/batches/batch_123/cancel');
      expect(transport.latestMethod).assertEqual('POST');
      expect(response.status).assertEqual('cancelling');
    });

    it('managesVectorStoresWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"vs_123","object":"vector_store","created_at":1710000000,"name":"Docs","usage_bytes":0,"file_counts":{"in_progress":0,"completed":0,"failed":0,"cancelled":0,"total":0},"status":"completed"}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });
      const request: VectorStoreCreateParams = {
        name: 'Docs',
        file_ids: ['file_123'],
      };

      const created: VectorStore = await client.vectorStores.create(request);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/vector_stores');
      expect(transport.latestMethod).assertEqual('POST');
      expect(transport.latestBody).assertContain('"file_ids"');
      expect(created.id).assertEqual('vs_123');

      transport.nextBody = '{"id":"vs_123","object":"vector_store.deleted","deleted":true}';
      const deleted: VectorStoreDeleted = await client.vectorStores.delete('vs_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/vector_stores/vs_123');
      expect(transport.latestMethod).assertEqual('DELETE');
      expect(deleted.deleted).assertEqual(true);
    });

    it('managesVectorStoreFilesAndBatchesWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"file_123","object":"vector_store.file","created_at":1710000000,"vector_store_id":"vs_123","status":"completed","usage_bytes":100}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });

      const file: VectorStoreFile = await client.vectorStores.files.create('vs_123', { file_id: 'file_123' });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/vector_stores/vs_123/files');
      expect(transport.latestMethod).assertEqual('POST');
      expect(file.id).assertEqual('file_123');

      transport.nextBody = '{"id":"vsfb_123","object":"vector_store.file_batch","created_at":1710000000,"vector_store_id":"vs_123","status":"in_progress","file_counts":{"in_progress":1,"completed":0,"failed":0,"cancelled":0,"total":1}}';
      const batch: VectorStoreFileBatch = await client.vectorStores.fileBatches.create('vs_123', {
        file_ids: ['file_123'],
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/vector_stores/vs_123/file_batches');
      expect(batch.file_counts.total).assertEqual(1);

      transport.nextBody = '{"object":"vector_store.search_results.page","data":[{"file_id":"file_123","filename":"doc.md","score":0.9,"attributes":{},"content":[{"type":"text","text":"hello"}]}],"has_more":false}';
      const search: VectorStoreSearchResponse = await client.vectorStores.search('vs_123', {
        query: 'hello',
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/vector_stores/vs_123/search');
      expect(search.data[0].file_id).assertEqual('file_123');
    });

    it('managesFineTuningJobsWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"ftjob_123","object":"fine_tuning.job","model":"gpt-4o-mini","created_at":1710000000,"fine_tuned_model":null,"organization_id":"org_123","result_files":[],"status":"queued","validation_file":null,"training_file":"file_123","hyperparameters":{"n_epochs":"auto"},"trained_tokens":null,"error":null}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });
      const request: FineTuningJobCreateParams = {
        model: 'gpt-4o-mini',
        training_file: 'file_123',
      };

      const job: FineTuningJob = await client.fineTuning.jobs.create(request);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/fine_tuning/jobs');
      expect(transport.latestMethod).assertEqual('POST');
      expect(job.id).assertEqual('ftjob_123');

      transport.nextBody = '{"object":"list","data":[{"id":"ft-event-123","object":"fine_tuning.job.event","created_at":1710000001,"level":"info","message":"created","data":null,"type":"message"}],"has_more":false}';
      const events: FineTuningJobEventListResponse = await client.fineTuning.jobs.listEvents('ftjob_123', { limit: 1 });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/fine_tuning/jobs/ftjob_123/events?limit=1');
      expect(events.data[0].message).assertEqual('created');

      transport.nextBody = '{"object":"list","data":[{"id":"ftckpt_123","object":"fine_tuning.job.checkpoint","created_at":1710000002,"fine_tuned_model_checkpoint":"ft:gpt-4o-mini:org:test:ckpt-step-10","fine_tuning_job_id":"ftjob_123","metrics":{"step":10,"train_loss":0.1},"step_number":10}],"has_more":false}';
      const checkpoints: FineTuningJobCheckpointListResponse = await client.fineTuning.jobs.listCheckpoints('ftjob_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/fine_tuning/jobs/ftjob_123/checkpoints');
      expect(checkpoints.data[0].step_number).assertEqual(10);

      transport.nextBody = '{"id":"ftjob_123","object":"fine_tuning.job","model":"gpt-4o-mini","created_at":1710000000,"fine_tuned_model":null,"organization_id":"org_123","result_files":[],"status":"cancelled","validation_file":null,"training_file":"file_123","hyperparameters":{"n_epochs":"auto"},"trained_tokens":null,"error":null}';
      const cancelled: FineTuningJob = await client.fineTuning.jobs.cancel('ftjob_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/fine_tuning/jobs/ftjob_123/cancel');
      expect(cancelled.status).assertEqual('cancelled');

      transport.nextBody = '{"id":"ftjob_123","object":"fine_tuning.job","model":"gpt-4o-mini","created_at":1710000000,"fine_tuned_model":null,"organization_id":"org_123","result_files":[],"status":"running","validation_file":null,"training_file":"file_123","hyperparameters":{"n_epochs":"auto"},"trained_tokens":null,"error":null}';
      const paused: FineTuningJob = await client.fineTuning.jobs.pause('ftjob_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/fine_tuning/jobs/ftjob_123/pause');
      expect(paused.id).assertEqual('ftjob_123');

      transport.nextBody = '{"id":"ftjob_123","object":"fine_tuning.job","model":"gpt-4o-mini","created_at":1710000000,"fine_tuned_model":null,"organization_id":"org_123","result_files":[],"status":"running","validation_file":null,"training_file":"file_123","hyperparameters":{"n_epochs":"auto"},"trained_tokens":null,"error":null}';
      const resumed: FineTuningJob = await client.fineTuning.jobs.resume('ftjob_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/fine_tuning/jobs/ftjob_123/resume');
      expect(resumed.id).assertEqual('ftjob_123');

      transport.nextBody = '{"object":"list","data":[{"object":"checkpoint.permission","id":"cp_123","created_at":1710000003,"project_id":"proj_123"}],"has_more":false}';
      const permissions: FineTuningCheckpointPermissionListResponse =
        await client.fineTuning.checkpointPermissions.list('ft:gpt-4o-mini:org:test:ckpt-step-10', {
          project_id: 'proj_123',
          limit: 10,
        });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/fine_tuning/checkpoints/ft%3Agpt-4o-mini%3Aorg%3Atest%3Ackpt-step-10/permissions?project_id=proj_123&limit=10');
      expect(permissions.data[0].project_id).assertEqual('proj_123');

      transport.nextBody = '{"object":"list","data":[{"object":"checkpoint.permission","id":"cp_456","created_at":1710000004,"project_id":"proj_456"}],"has_more":false}';
      const permissionRequest: FineTuningCheckpointPermissionCreateParams = {
        project_ids: ['proj_456'],
      };
      const createdPermissions: FineTuningCheckpointPermissionListResponse =
        await client.fineTuning.checkpointPermissions.create('ft:gpt-4o-mini:org:test:ckpt-step-10', permissionRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/fine_tuning/checkpoints/ft%3Agpt-4o-mini%3Aorg%3Atest%3Ackpt-step-10/permissions');
      expect(transport.latestBody).assertContain('"project_ids"');
      expect(createdPermissions.data[0].id).assertEqual('cp_456');

      transport.nextBody = '{"object":"checkpoint.permission","id":"cp_456","deleted":true}';
      const deletedPermission: FineTuningCheckpointPermissionDeleted =
        await client.fineTuning.checkpointPermissions.delete('ft:gpt-4o-mini:org:test:ckpt-step-10', 'cp_456');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/fine_tuning/checkpoints/ft%3Agpt-4o-mini%3Aorg%3Atest%3Ackpt-step-10/permissions/cp_456');
      expect(deletedPermission.deleted).assertEqual(true);

      const permission: FineTuningCheckpointPermission = permissions.data[0];
      expect(permission.id).assertEqual('cp_123');

      transport.nextBody = '{"grader":{"type":"string_check","name":"contains","input":"{{sample.output_text}}","reference":"{{item.label}}","operation":"eq"}}';
      const grader: EvalStringCheckGrader = {
        type: 'string_check',
        name: 'contains',
        input: '{{sample.output_text}}',
        reference: '{{item.label}}',
        operation: 'eq',
      };
      const validateResponse: FineTuningGraderValidateResponse =
        await client.fineTuning.alpha.graders.validate({ grader: grader });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/fine_tuning/alpha/graders/validate');
      expect(validateResponse.grader.name).assertEqual('contains');

      transport.nextBody = '{"reward":1,"passed":true,"metadata":{"grader":"contains"}}';
      const runRequest: FineTuningGraderRunParams = {
        grader: grader,
        model_sample: 'yes',
      };
      const runResponse: FineTuningGraderRunResponse = await client.fineTuning.alpha.graders.run(runRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/fine_tuning/alpha/graders/run');
      expect(runResponse.reward).assertEqual(1);
    });

    it('managesUploadsWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"upload_123","object":"upload","bytes":1024,"created_at":1710000000,"filename":"input.jsonl","purpose":"fine-tune","status":"pending","expires_at":1710003600}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });
      const request: UploadCreateParams = {
        bytes: 1024,
        filename: 'input.jsonl',
        mime_type: 'text/jsonl',
        purpose: 'fine-tune',
      };

      const upload: Upload = await client.uploads.create(request);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/uploads');
      expect(transport.latestMethod).assertEqual('POST');
      expect(upload.id).assertEqual('upload_123');

      transport.nextBody = '{"id":"part_123","object":"upload.part","created_at":1710000001,"upload_id":"upload_123"}';
      const part: UploadPart = await client.uploads.parts.create('upload_123', { data: 'file://chunk.bin' });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/uploads/upload_123/parts');
      expect(transport.latestMultipartCount).assertEqual(1);
      expect(part.upload_id).assertEqual('upload_123');

      transport.nextBody = '{"id":"upload_123","object":"upload","bytes":1024,"created_at":1710000000,"filename":"input.jsonl","purpose":"fine-tune","status":"completed","expires_at":1710003600,"file":{"id":"file_123","object":"file","bytes":1024,"created_at":1710000002,"filename":"input.jsonl","purpose":"fine-tune"}}';
      const completed: Upload = await client.uploads.complete('upload_123', { part_ids: ['part_123'] });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/uploads/upload_123/complete');
      expect(completed.status).assertEqual('completed');

      transport.nextBody = '{"id":"upload_123","object":"upload","bytes":1024,"created_at":1710000000,"filename":"input.jsonl","purpose":"fine-tune","status":"cancelled","expires_at":1710003600}';
      const cancelled: Upload = await client.uploads.cancel('upload_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/uploads/upload_123/cancel');
      expect(cancelled.status).assertEqual('cancelled');
    });

    it('managesContainersAndFilesWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"cntr_123","object":"container","created_at":1710000000,"status":"running","name":"My Container","memory_limit":"4g"}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });
      const request: ContainerCreateParams = {
        name: 'My Container',
        memory_limit: '4g',
      };

      const container: Container = await client.containers.create(request);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/containers');
      expect(transport.latestMethod).assertEqual('POST');
      expect(container.id).assertEqual('cntr_123');

      transport.nextBody = '{"object":"list","data":[{"id":"cfile_123","object":"container.file","created_at":1710000001,"bytes":10,"container_id":"cntr_123","path":"/mnt/data/input.txt","source":"user"}],"has_more":false}';
      const files: ContainerFileListResponse = await client.containers.files.list('cntr_123', { limit: 20 });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/containers/cntr_123/files?limit=20');
      expect(files.data[0].id).assertEqual('cfile_123');

      transport.nextBody = '{"id":"cfile_123","object":"container.file","created_at":1710000001,"bytes":10,"container_id":"cntr_123","path":"/mnt/data/input.txt","source":"user"}';
      const fileRequest: ContainerFileCreateParams = {
        file: 'file://input.txt',
      };
      const file: ContainerFile = await client.containers.files.create('cntr_123', fileRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/containers/cntr_123/files');
      expect(transport.latestMultipartCount).assertEqual(1);
      expect(file.path).assertContain('input.txt');

      transport.nextBody = 'hello container';
      const content: string = await client.containers.files.content('cntr_123', 'cfile_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/containers/cntr_123/files/cfile_123/content');
      expect(content).assertEqual('hello container');

      transport.nextBody = '{"id":"cfile_123","object":"container.file.deleted","deleted":true}';
      const deletedFile: ContainerFileDeleted = await client.containers.files.delete('cntr_123', 'cfile_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/containers/cntr_123/files/cfile_123');
      expect(deletedFile.deleted).assertEqual(true);

      transport.nextBody = '{"id":"cntr_123","object":"container.deleted","deleted":true}';
      const deleted: ContainerDeleted = await client.containers.delete('cntr_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/containers/cntr_123');
      expect(deleted.deleted).assertEqual(true);
    });

    it('managesConversationsAndItemsWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"conv_123","object":"conversation","created_at":1710000000,"metadata":{"topic":"demo"}}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });
      const request: ConversationCreateParams = {
      };

      const conversation: Conversation = await client.conversations.create(request);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/conversations');
      expect(transport.latestMethod).assertEqual('POST');
      expect(conversation.id).assertEqual('conv_123');

      transport.nextBody = '{"type":"message","id":"msg_123","status":"completed","role":"user","content":[{"type":"input_text","text":"Hello"}]}';
      const itemRequest: ConversationItemCreateParams = {
        item: {
          type: 'message',
          role: 'user',
          content: [{ type: 'input_text', text: 'Hello' }],
        },
      };
      const item: ConversationItem = await client.conversations.items.create('conv_123', itemRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/conversations/conv_123/items');
      expect(item.id).assertEqual('msg_123');

      transport.nextBody = '{"object":"list","data":[{"type":"message","id":"msg_123","status":"completed","role":"user","content":[{"type":"input_text","text":"Hello"}]}],"has_more":false}';
      const items: ConversationItemListResponse = await client.conversations.items.list('conv_123', {
        limit: 20,
        include: ['file_search_call.results'],
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/conversations/conv_123/items?limit=20&include[]=file_search_call.results');
      expect(items.data[0].id).assertEqual('msg_123');

      transport.nextBody = '{"id":"conv_123","object":"conversation.deleted","deleted":true}';
      const deleted: ConversationDeleted = await client.conversations.delete('conv_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/conversations/conv_123');
      expect(deleted.deleted).assertEqual(true);
    });

    it('createsRealtimeClientSecretsAndTranscriptionSessionsWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"value":"ek_123","expires_at":1710000600,"session":{"object":"realtime.session","type":"realtime","id":"sess_123","model":"gpt-realtime","expires_at":1710000600,"output_modalities":["audio"]}}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });
      const secretRequest: RealtimeClientSecretCreateParams = {
        expires_after: {
          anchor: 'created_at',
          seconds: 600,
        },
        session: {
          type: 'realtime',
          model: 'gpt-realtime',
          instructions: 'Be concise.',
        },
      };

      const secret: RealtimeClientSecret = await client.realtime.clientSecrets.create(secretRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/realtime/client_secrets');
      expect(transport.latestMethod).assertEqual('POST');
      expect(secret.value).assertEqual('ek_123');

      transport.nextBody = '{"object":"realtime.session","type":"transcription","id":"sess_trans_123","expires_at":1710000600,"include":["item.input_audio_transcription.logprobs"],"client_secret":{"value":"ek_trans","expires_at":1710000600}}';
      const transcriptionRequest: RealtimeTranscriptionSessionCreateParams = {
        include: ['item.input_audio_transcription.logprobs'],
        input_audio_format: 'pcm16',
        input_audio_transcription: {
          model: 'gpt-4o-transcribe',
          language: 'zh',
        },
      };

      const session: RealtimeTranscriptionSession = await client.realtime.transcriptionSessions.create(transcriptionRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/realtime/transcription_sessions');
      expect(session.client_secret!.value).assertEqual('ek_trans');
    });

    it('createsRealtimeTransportOptionsWithOpenAIClient', 0, () => {
      const realtimeHeaders: Record<string, string> = {
        'OpenAI-Beta': 'realtime=v1',
      };
      const wsOptions: RealtimeWebSocketOptions = {
        model: 'gpt-realtime',
        url: 'wss://example.test/v1/realtime?model=gpt-realtime',
        apiKey: 'ek_123',
        headers: realtimeHeaders,
      };
      const rtcOptions: RealtimeWebRTCOptions = {
        model: 'gpt-realtime',
        apiKey: 'ek_123',
        localSdp: 'v=0',
        includeAudio: true,
      };
      const permissions = OpenAI.realtimeRequiredPermissions();

      expect(wsOptions.url).assertContain('realtime');
      expect(wsOptions.headers!['OpenAI-Beta']).assertEqual('realtime=v1');
      expect(rtcOptions.includeAudio).assertEqual(true);
      expect(permissions[0]).assertEqual('ohos.permission.MICROPHONE');
    });

    it('modelsRealtimeClientAndServerEvents', 0, () => {
      const createItemEvent: RealtimeClientEvent = {
        type: 'conversation.item.create',
        event_id: 'evt_client_1',
        item: {
          type: 'message',
          role: 'user',
          content: [
            {
              type: 'input_text',
              text: '你好',
            },
          ],
        },
      };
      const appendAudioEvent: RealtimeClientEvent = {
        type: 'input_audio_buffer.append',
        audio: 'AAAA',
      };
      const textDeltaEvent: RealtimeServerEvent = {
        type: 'response.text.delta',
        event_id: 'evt_server_1',
        response_id: 'resp_123',
        item_id: 'item_123',
        output_index: 0,
        content_index: 0,
        delta: '你',
      };
      const completedTranscriptionEvent: RealtimeServerEvent = {
        type: 'conversation.item.input_audio_transcription.completed',
        event_id: 'evt_server_2',
        item_id: 'item_audio_123',
        content_index: 0,
        transcript: '你好',
      };

      expect(createItemEvent.type).assertEqual('conversation.item.create');
      expect(appendAudioEvent.type).assertEqual('input_audio_buffer.append');
      expect(textDeltaEvent.type).assertEqual('response.text.delta');
      expect(completedTranscriptionEvent.type).assertEqual('conversation.item.input_audio_transcription.completed');
    });

    it('managesChatKitSessionsAndThreadsWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"cksess_123","object":"chatkit.session","client_secret":"chatkit_token_123","expires_at":1710000600,"workflow":{"id":"workflow_alpha","version":"2024-10-01"},"user":"user_123","status":"active","max_requests_per_1_minute":60}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });
      const request: ChatKitSessionCreateParams = {
        user: 'user_123',
        workflow: {
          id: 'workflow_alpha',
          version: '2024-10-01',
        },
      };

      const session: ChatKitSession = await client.chatkit.sessions.create(request);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/chatkit/sessions');
      expect(transport.latestHeaders['OpenAI-Beta']).assertEqual('chatkit_beta=v1');
      expect(session.client_secret).assertEqual('chatkit_token_123');

      transport.nextBody = '{"id":"cksess_123","object":"chatkit.session","client_secret":"chatkit_token_123","expires_at":1710000600,"workflow":{"id":"workflow_alpha"},"user":"user_123","status":"cancelled","cancelled_at":1710000010}';
      const cancelled: ChatKitSession = await client.chatkit.sessions.cancel('cksess_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/chatkit/sessions/cksess_123/cancel');
      expect(cancelled.status).assertEqual('cancelled');

      transport.nextBody = '{"object":"list","data":[{"id":"cthr_123","object":"chatkit.thread","created_at":1710000000,"title":"Demo","status":{"type":"active"},"user":"user_123"}],"has_more":false}';
      const threads: ChatKitThreadListResponse = await client.chatkit.threads.list({ user: 'user_123', limit: 2 });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/chatkit/threads?user=user_123&limit=2');
      expect(threads.data[0].id).assertEqual('cthr_123');

      transport.nextBody = '{"id":"cthr_123","object":"chatkit.thread","created_at":1710000000,"title":"Demo","status":{"type":"active"},"user":"user_123"}';
      const thread: ChatKitThread = await client.chatkit.threads.retrieve('cthr_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/chatkit/threads/cthr_123');
      expect(thread.title).assertEqual('Demo');

      transport.nextBody = '{"object":"list","data":[{"id":"cthi_123","object":"chatkit.thread_item","type":"user_message","content":[{"type":"input_text","text":"hello"}],"attachments":[]}],"has_more":false}';
      const items: ChatKitThreadItemListResponse = await client.chatkit.threads.items.list('cthr_123', { limit: 3 });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/chatkit/threads/cthr_123/items?limit=3');
      expect(items.data[0].id).assertEqual('cthi_123');

      transport.nextBody = '{"id":"cthr_123","object":"chatkit.thread.deleted","deleted":true}';
      const deleted: ChatKitThreadDeleted = await client.chatkit.threads.delete('cthr_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/chatkit/threads/cthr_123');
      expect(deleted.deleted).assertEqual(true);
    });

    it('modelsChatKitUploadConfigurationAndAnnotations', 0, () => {
      const request: ChatKitSessionCreateParams = {
        user: 'user_123',
        workflow: {
          id: 'workflow_alpha',
        },
        chatkit_configuration: {
          file_upload: {
            enabled: true,
            max_file_size: 128,
            max_files: 4,
          },
        },
      };
      const strategy: ChatKitUploadStrategy = {
        type: 'frontend',
        description: 'ChatKit 前端负责文件上传，服务端 SDK 只创建 session 和读取附件 metadata。',
      };
      const source: ChatKitResponseOutputTextFileSource = {
        type: 'file',
        filename: 'guide.pdf',
      };
      const annotation: ChatKitResponseOutputTextFileAnnotation = {
        type: 'file',
        source: source,
      };

      expect(request.chatkit_configuration!.file_upload!.enabled).assertEqual(true);
      expect(strategy.type).assertEqual('frontend');
      expect(annotation.source.filename).assertEqual('guide.pdf');
    });

    it('managesAudioVoicesAndConsentsWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"object":"audio.voice_consent","id":"cons_123","name":"John Doe","language":"en-US","created_at":1710000000}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });
      const consentRequest: VoiceConsentCreateParams = {
        name: 'John Doe',
        language: 'en-US',
        recording: 'file://consent.wav',
      };

      const consent: VoiceConsent = await client.audio.voiceConsents.create(consentRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/audio/voice_consents');
      expect(transport.latestMultipartCount).assertEqual(3);
      expect(consent.id).assertEqual('cons_123');

      transport.nextBody = '{"object":"list","data":[{"object":"audio.voice_consent","id":"cons_123","name":"John Doe","language":"en-US","created_at":1710000000}],"has_more":false}';
      const consents: VoiceConsentListResponse = await client.audio.voiceConsents.list({ limit: 20 });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/audio/voice_consents?limit=20');
      expect(consents.data[0].id).assertEqual('cons_123');

      transport.nextBody = '{"object":"audio.voice_consent","id":"cons_123","name":"Jane Doe","language":"en-US","created_at":1710000000}';
      const updated: VoiceConsent = await client.audio.voiceConsents.update('cons_123', { name: 'Jane Doe' });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/audio/voice_consents/cons_123');
      expect(updated.name).assertEqual('Jane Doe');

      transport.nextBody = '{"object":"audio.voice_consent","id":"cons_123","deleted":true}';
      const deleted: VoiceConsentDeleted = await client.audio.voiceConsents.delete('cons_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/audio/voice_consents/cons_123');
      expect(deleted.deleted).assertEqual(true);

      transport.nextBody = '{"object":"audio.voice","id":"voice_123","name":"My voice","created_at":1710000001}';
      const voiceRequest: VoiceCreateParams = {
        name: 'My voice',
        consent: 'cons_123',
        audio_sample: 'file://sample.wav',
      };
      const voice: Voice = await client.audio.voices.create(voiceRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/audio/voices');
      expect(transport.latestMultipartCount).assertEqual(3);
      expect(voice.id).assertEqual('voice_123');
    });

    it('managesEvalsRunsAndOutputItemsWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"eval_123","object":"eval","name":"Quality eval","created_at":1710000000,"data_source_config":{"type":"custom"},"testing_criteria":[{"type":"string_check","name":"contains","input":"{{sample.output_text}}","reference":"{{item.label}}","operation":"eq"}],"metadata":{}}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });
      const criterion: EvalStringCheckGrader = {
        type: 'string_check',
        name: 'contains',
        input: '{{sample.output_text}}',
        reference: '{{item.label}}',
        operation: 'eq',
      };
      const request: EvalCreateParams = {
        name: 'Quality eval',
        data_source_config: { type: 'custom' },
        testing_criteria: [criterion],
      };

      const evalObject: EvalObject = await client.evals.create(request);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/evals');
      expect(transport.latestMethod).assertEqual('POST');
      expect(evalObject.id).assertEqual('eval_123');

      transport.nextBody = '{"id":"evalrun_123","object":"eval.run","eval_id":"eval_123","name":"Run 1","status":"queued","created_at":1710000001,"data_source":{"type":"jsonl","source":{"type":"file_id","id":"file_123"}}}';
      const runRequest: EvalRunCreateParams = {
        name: 'Run 1',
        data_source: {
          type: 'jsonl',
          source: { type: 'file_id', id: 'file_123' },
        },
      };
      const run: EvalRun = await client.evals.runs.create('eval_123', runRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/evals/eval_123/runs');
      expect(run.id).assertEqual('evalrun_123');

      transport.nextBody = '{"object":"list","data":[{"id":"evalrun_123","object":"eval.run","eval_id":"eval_123","status":"completed","created_at":1710000001,"data_source":{"type":"jsonl"}}],"has_more":false}';
      const runs: EvalRunListResponse = await client.evals.runs.list('eval_123', { status: 'completed', limit: 20 });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/evals/eval_123/runs?status=completed&limit=20');
      expect(runs.data[0].status).assertEqual('completed');

      transport.nextBody = '{"object":"list","data":[{"id":"output_123","object":"eval.run.output_item","run_id":"evalrun_123","eval_id":"eval_123","created_at":1710000002,"status":"pass","datasource_item_id":1,"results":[]}],"has_more":false}';
      const outputItems: EvalRunOutputItemListResponse = await client.evals.runs.outputItems.list('eval_123', 'evalrun_123', { status: 'pass' });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/evals/eval_123/runs/evalrun_123/output_items?status=pass');
      expect(outputItems.data[0].id).assertEqual('output_123');

      transport.nextBody = '{"id":"output_123","object":"eval.run.output_item","run_id":"evalrun_123","eval_id":"eval_123","created_at":1710000002,"status":"pass","datasource_item_id":1,"results":[]}';
      const outputItem: EvalRunOutputItem = await client.evals.runs.outputItems.retrieve('eval_123', 'evalrun_123', 'output_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/evals/eval_123/runs/evalrun_123/output_items/output_123');
      expect(outputItem.status).assertEqual('pass');

      transport.nextBody = '{"object":"eval.deleted","deleted":true,"id":"eval_123"}';
      const deleted: EvalDeleted = await client.evals.delete('eval_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/evals/eval_123');
      expect(deleted.id).assertEqual('eval_123');
      expect(deleted.deleted).assertEqual(true);
    });

    it('managesAssistantsThreadsMessagesRunsAndStepsWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"asst_123","object":"assistant","created_at":1710000000,"name":"Helper","model":"gpt-4o-mini","instructions":"Help.","tools":[],"metadata":{}}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });
      const assistantRequest: AssistantCreateParams = {
        model: 'gpt-4o-mini',
        name: 'Helper',
        instructions: 'Help.',
      };

      const assistant: AssistantObject = await client.beta.assistants.create(assistantRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/assistants');
      expect(transport.latestHeaders['OpenAI-Beta']).assertEqual('assistants=v2');
      expect(assistant.id).assertEqual('asst_123');

      transport.nextBody = '{"id":"thread_123","object":"thread","created_at":1710000001,"metadata":{},"tool_resources":{}}';
      const threadRequest: ThreadCreateParams = {};
      const thread: AssistantThread = await client.beta.threads.create(threadRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/threads');
      expect(thread.id).assertEqual('thread_123');

      transport.nextBody = '{"id":"msg_123","object":"thread.message","created_at":1710000002,"thread_id":"thread_123","role":"user","content":[{"type":"text","text":{"value":"Hello","annotations":[]}}],"attachments":[],"metadata":{}}';
      const messageRequest: MessageCreateParams = {
        role: 'user',
        content: 'Hello',
      };
      const message: ThreadMessage = await client.beta.threads.messages.create('thread_123', messageRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/threads/thread_123/messages');
      expect(message.id).assertEqual('msg_123');

      transport.nextBody = '{"object":"list","data":[{"id":"msg_123","object":"thread.message","created_at":1710000002,"thread_id":"thread_123","role":"user","content":[]}],"has_more":false}';
      const messages: ThreadMessageListResponse = await client.beta.threads.messages.list('thread_123', { limit: 10 });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/threads/thread_123/messages?limit=10');
      expect(messages.data[0].id).assertEqual('msg_123');

      transport.nextBody = '{"id":"run_123","object":"thread.run","created_at":1710000003,"thread_id":"thread_123","assistant_id":"asst_123","status":"queued","model":"gpt-4o-mini","instructions":"Help.","tools":[]}';
      const runRequest: RunCreateParams = {
        assistant_id: 'asst_123',
      };
      const run: ThreadRun = await client.beta.threads.runs.create('thread_123', runRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/threads/thread_123/runs');
      expect(run.id).assertEqual('run_123');

      transport.nextBody = '{"object":"list","data":[{"id":"run_123","object":"thread.run","created_at":1710000003,"thread_id":"thread_123","assistant_id":"asst_123","status":"completed","model":"gpt-4o-mini","instructions":"Help.","tools":[]}],"has_more":false}';
      const runs: ThreadRunListResponse = await client.beta.threads.runs.list('thread_123', { limit: 5 });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/threads/thread_123/runs?limit=5');
      expect(runs.data[0].status).assertEqual('completed');

      transport.nextBody = '{"object":"list","data":[{"id":"step_123","object":"thread.run.step","created_at":1710000004,"assistant_id":"asst_123","thread_id":"thread_123","run_id":"run_123","type":"message_creation","status":"completed","step_details":{"type":"message_creation","message_creation":{"message_id":"msg_456"}}}],"has_more":false}';
      const steps: RunStepListResponse = await client.beta.threads.runs.steps.list('thread_123', 'run_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/threads/thread_123/runs/run_123/steps');
      expect(steps.data[0].id).assertEqual('step_123');

      transport.nextBody = '{"id":"step_123","object":"thread.run.step","created_at":1710000004,"assistant_id":"asst_123","thread_id":"thread_123","run_id":"run_123","type":"message_creation","status":"completed","step_details":{"type":"message_creation","message_creation":{"message_id":"msg_456"}}}';
      const step: RunStep = await client.beta.threads.runs.steps.retrieve('thread_123', 'run_123', 'step_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/threads/thread_123/runs/run_123/steps/step_123');
      expect(step.status).assertEqual('completed');

      transport.nextBody = '{"id":"thread_123","object":"thread.deleted","deleted":true}';
      const deletedThread: AssistantThreadDeleted = await client.beta.threads.delete('thread_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/threads/thread_123');
      expect(deletedThread.deleted).assertEqual(true);

      transport.nextBody = '{"id":"asst_123","object":"assistant.deleted","deleted":true}';
      const deletedAssistant: AssistantDeleted = await client.beta.assistants.delete('asst_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/assistants/asst_123');
      expect(deletedAssistant.deleted).assertEqual(true);
    });

    it('streamsAssistantRunEventsWithOpenAIClient', 0, () => {
      const transport = new FakeTransport();
      transport.nextBody = 'event: thread.run.created\ndata: {"id":"run_123","object":"thread.run","created_at":1710000003,"thread_id":"thread_123","assistant_id":"asst_123","status":"queued","model":"gpt-4o-mini","instructions":"Help.","tools":[]}\n\ndata: [DONE]\n\n';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });
      const runRequest: RunCreateParams = {
        assistant_id: 'asst_123',
      };
      const handlers = new CollectAssistantStreamHandlers();

      const stream = client.beta.threads.runs.createStream('thread_123', runRequest, handlers);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/threads/thread_123/runs');
      expect(transport.latestHeaders['Accept']).assertEqual('text/event-stream');
      expect(transport.latestBody).assertContain('"stream":true');
      expect(handlers.events[0].event).assertEqual('thread.run.created');
      const eventData = handlers.events[0].data as JsonObject;
      expect(eventData['id']).assertEqual('run_123');
      stream.close();
      expect(transport.latestStreamChunkCount).assertEqual(2);
    });

    it('managesVideosWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"id":"video_123","object":"video","model":"sora-2","status":"queued","progress":0,"created_at":1712697600,"size":"720x1280","seconds":"4","quality":"standard"}';
      const client = new OpenAI({ apiKey: 'sk-test', baseURL: 'https://example.test/v1', transport: transport });
      const createRequest: VideoCreateParams = {
        prompt: 'A calico cat playing a piano on stage',
        model: 'sora-2',
        input_reference: 'file://cat.png',
        seconds: '4',
        size: '720x1280',
      };

      const created: VideoJob = await client.videos.create(createRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/videos');
      expect(transport.latestMethod).assertEqual('POST');
      expect(transport.latestMultipartCount).assertEqual(5);
      expect(created.id).assertEqual('video_123');

      transport.nextBody = '{"object":"list","data":[{"id":"video_123","object":"video","model":"sora-2","status":"completed","created_at":1712697600}],"has_more":false}';
      const videos: VideoListResponse = await client.videos.list({ after: 'video_100', limit: 3, order: 'desc' });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/videos?limit=3&after=video_100&order=desc');
      expect(videos.data[0].status).assertEqual('completed');

      transport.nextBody = '{"id":"video_123","object":"video","model":"sora-2","status":"completed","created_at":1712697600,"prompt":"A cat"}';
      const retrieved: VideoJob = await client.videos.retrieve('video_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/videos/video_123');
      expect(retrieved.prompt).assertEqual('A cat');

      transport.nextBody = 'AAAA';
      const content: string = await client.videos.downloadContent('video_123', { variant: 'thumbnail' });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/videos/video_123/content?variant=thumbnail');
      expect(transport.latestResponseDataType).assertEqual('arraybuffer');
      expect(content).assertEqual('AAAA');

      transport.nextBody = '{"id":"video_456","object":"video","model":"sora-2","status":"queued","created_at":1712698600,"remixed_from_video_id":"video_123"}';
      const remixRequest: VideoRemixParams = {
        prompt: 'Extend the scene with the cat taking a bow',
      };
      const remixed: VideoJob = await client.videos.remix('video_123', remixRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/videos/video_123/remix');
      expect(transport.latestBody).assertContain('"prompt"');
      expect(remixed.remixed_from_video_id).assertEqual('video_123');

      transport.nextBody = '{"id":"video_789","object":"video","model":"sora-2","status":"queued","created_at":1712698700,"prompt":"Add stage lights"}';
      const editRequest: VideoEditParams = {
        prompt: 'Add stage lights',
        video: {
          id: 'video_123',
        },
      };
      const edited: VideoJob = await client.videos.edit(editRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/videos/edits');
      expect(transport.latestBody).assertContain('"video":{"id":"video_123"}');
      expect(edited.id).assertEqual('video_789');

      transport.nextBody = '{"id":"video_999","object":"video","model":"sora-2","status":"queued","created_at":1712698800,"prompt":"The cat exits","seconds":"8"}';
      const extendRequest: VideoExtendParams = {
        prompt: 'The cat exits',
        seconds: '8',
        video: {
          id: 'video_789',
        },
      };
      const extended: VideoJob = await client.videos.extend(extendRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/videos/extensions');
      expect(transport.latestBody).assertContain('"seconds":"8"');
      expect(extended.seconds).assertEqual('8');

      transport.nextBody = '{"id":"char_123","created_at":1712698900,"name":"Pianist Cat"}';
      const characterRequest: VideoCharacterCreateParams = {
        name: 'Pianist Cat',
        video: 'file://character.mp4',
      };
      const character: VideoCharacter = await client.videos.characters.create(characterRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/videos/characters');
      expect(transport.latestMethod).assertEqual('POST');
      expect(transport.latestMultipartCount).assertEqual(2);
      expect(character.id).assertEqual('char_123');

      transport.nextBody = '{"id":"char_123","created_at":1712698900,"name":"Pianist Cat"}';
      const retrievedCharacter: VideoCharacter = await client.videos.characters.retrieve('char_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/videos/characters/char_123');
      expect(retrievedCharacter.name).assertEqual('Pianist Cat');

      transport.nextBody = '{"id":"video_456","object":"video.deleted","deleted":true}';
      const deleted: VideoDeleted = await client.videos.delete('video_456');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/videos/video_456');
      expect(transport.latestMethod).assertEqual('DELETE');
      expect(deleted.id).assertEqual('video_456');
      expect(deleted.deleted).assertEqual(true);
    });

    it('managesOrganizationProjectsWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"object":"list","data":[{"id":"proj_123","object":"organization.project","name":"Project A","created_at":1711471533,"archived_at":null,"status":"active"}],"first_id":"proj_123","last_id":"proj_123","has_more":false}';
      const client = new OpenAI({ apiKey: 'sk-admin', baseURL: 'https://example.test/v1', transport: transport });

      const projects: OrganizationProjectListResponse = await client.organization.projects.list({
        after: 'proj_100',
        limit: 20,
        include_archived: false,
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects?after=proj_100&limit=20&include_archived=false');
      expect(projects.data[0].id).assertEqual('proj_123');

      transport.nextBody = '{"id":"proj_456","object":"organization.project","name":"Project B","created_at":1711471534,"archived_at":null,"status":"active"}';
      const createRequest: OrganizationProjectCreateParams = {
        name: 'Project B',
      };
      const created: OrganizationProject = await client.organization.projects.create(createRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects');
      expect(transport.latestBody).assertContain('"name":"Project B"');
      expect(created.name).assertEqual('Project B');

      transport.nextBody = '{"id":"proj_456","object":"organization.project","name":"Project B","created_at":1711471534,"archived_at":null,"status":"active"}';
      const retrieved: OrganizationProject = await client.organization.projects.retrieve('proj_456');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456');
      expect(retrieved.status).assertEqual('active');

      transport.nextBody = '{"id":"proj_456","object":"organization.project","name":"Project C","created_at":1711471534,"archived_at":null,"status":"active"}';
      const updateRequest: OrganizationProjectUpdateParams = {
        name: 'Project C',
      };
      const updated: OrganizationProject = await client.organization.projects.update('proj_456', updateRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456');
      expect(updated.name).assertEqual('Project C');

      transport.nextBody = '{"id":"proj_456","object":"organization.project","name":"Project C","created_at":1711471534,"archived_at":1711471600,"status":"archived"}';
      const archived: OrganizationProject = await client.organization.projects.archive('proj_456');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/archive');
      expect(archived.status).assertEqual('archived');

      transport.nextBody = '{"object":"list","data":[{"object":"organization.project.user","id":"user_123","name":"Ada","email":"ada@example.com","role":"member","added_at":1711471533}],"has_more":false}';
      const users: OrganizationProjectUserListResponse = await client.organization.projects.users.list('proj_456', {
        after: 'user_100',
        limit: 20,
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/users?after=user_100&limit=20');
      expect(users.data[0].email).assertEqual('ada@example.com');

      transport.nextBody = '{"object":"organization.project.user","id":"user_123","name":"Ada","email":"ada@example.com","role":"owner","added_at":1711471533}';
      const userRequest: OrganizationProjectUserCreateParams = {
        user_id: 'user_123',
        role: 'member',
      };
      const user: OrganizationProjectUser = await client.organization.projects.users.create('proj_456', userRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/users');
      expect(transport.latestBody).assertContain('"user_id":"user_123"');
      expect(user.id).assertEqual('user_123');

      transport.nextBody = '{"object":"organization.project.user","id":"user_123","name":"Ada","email":"ada@example.com","role":"owner","added_at":1711471533}';
      const updateUserRequest: OrganizationProjectUserUpdateParams = {
        role: 'owner',
      };
      const updatedUser: OrganizationProjectUser = await client.organization.projects.users.update('proj_456', 'user_123', updateUserRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/users/user_123');
      expect(updatedUser.role).assertEqual('owner');

      transport.nextBody = '{"object":"organization.project.user.deleted","id":"user_123","deleted":true}';
      const deletedUser: OrganizationProjectUserDeleted = await client.organization.projects.users.delete('proj_456', 'user_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/users/user_123');
      expect(deletedUser.deleted).assertEqual(true);

      transport.nextBody = '{"object":"list","data":[{"object":"project.group","project_id":"proj_456","group_id":"group_123","group_name":"Support","created_at":1711471533}],"has_more":false,"next":null}';
      const groups: OrganizationProjectGroupListResponse = await client.organization.projects.groups.list('proj_456', {
        limit: 10,
        order: 'asc',
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/groups?limit=10&order=asc');
      expect(groups.data[0].group_name).assertEqual('Support');

      transport.nextBody = '{"object":"project.group","project_id":"proj_456","group_id":"group_123","group_name":"Support","created_at":1711471533}';
      const groupRequest: OrganizationProjectGroupCreateParams = {
        group_id: 'group_123',
        role: 'role_123',
      };
      const group: OrganizationProjectGroup = await client.organization.projects.groups.create('proj_456', groupRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/groups');
      expect(transport.latestBody).assertContain('"role":"role_123"');
      expect(group.group_id).assertEqual('group_123');

      transport.nextBody = '{"object":"project.group.deleted","deleted":true}';
      const deletedGroup: OrganizationProjectGroupDeleted = await client.organization.projects.groups.delete('proj_456', 'group_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/groups/group_123');
      expect(deletedGroup.deleted).assertEqual(true);

      transport.nextBody = '{"object":"list","data":[{"object":"organization.project.api_key","redacted_value":"sk-abc...def","name":"Key A","created_at":1711471533,"last_used_at":1711471534,"id":"key_123","owner":{"type":"user","user":{"object":"organization.project.user","id":"user_123","name":"Ada","email":"ada@example.com","role":"owner","added_at":1711471533}}}],"has_more":false}';
      const apiKeys: OrganizationProjectApiKeyListResponse = await client.organization.projects.apiKeys.list('proj_456', {
        after: 'key_100',
        limit: 20,
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/api_keys?after=key_100&limit=20');
      expect(apiKeys.data[0].redacted_value).assertEqual('sk-abc...def');

      transport.nextBody = '{"object":"organization.project.api_key","redacted_value":"sk-abc...def","name":"Key A","created_at":1711471533,"last_used_at":1711471534,"id":"key_123","owner":{"type":"user","user":{"object":"organization.project.user","id":"user_123","name":"Ada","email":"ada@example.com","role":"owner","added_at":1711471533}}}';
      const apiKey: OrganizationProjectApiKey = await client.organization.projects.apiKeys.retrieve('proj_456', 'key_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/api_keys/key_123');
      expect(apiKey.name).assertEqual('Key A');

      transport.nextBody = '{"object":"organization.project.api_key.deleted","id":"key_123","deleted":true}';
      const deletedApiKey: OrganizationProjectApiKeyDeleted = await client.organization.projects.apiKeys.delete('proj_456', 'key_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/api_keys/key_123');
      expect(deletedApiKey.deleted).assertEqual(true);

      transport.nextBody = '{"object":"list","data":[{"object":"organization.project.service_account","id":"svc_123","name":"Worker","role":"member","created_at":1711471533}],"has_more":false}';
      const serviceAccounts: OrganizationProjectServiceAccountListResponse =
        await client.organization.projects.serviceAccounts.list('proj_456', { after: 'svc_100', limit: 20 });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/service_accounts?after=svc_100&limit=20');
      expect(serviceAccounts.data[0].name).assertEqual('Worker');

      transport.nextBody = '{"object":"organization.project.service_account","id":"svc_456","name":"Worker 2","role":"member","created_at":1711471534,"api_key":{"object":"organization.project.service_account.api_key","value":"sk-service","name":"Secret Key","created_at":1711471534,"id":"key_svc"}}';
      const serviceAccountRequest: OrganizationProjectServiceAccountCreateParams = {
        name: 'Worker 2',
      };
      const serviceAccount: OrganizationProjectServiceAccount =
        await client.organization.projects.serviceAccounts.create('proj_456', serviceAccountRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/service_accounts');
      expect(serviceAccount.api_key!.value).assertEqual('sk-service');

      transport.nextBody = '{"object":"organization.project.service_account","id":"svc_456","name":"Worker 2","role":"member","created_at":1711471534}';
      const retrievedServiceAccount: OrganizationProjectServiceAccount =
        await client.organization.projects.serviceAccounts.retrieve('proj_456', 'svc_456');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/service_accounts/svc_456');
      expect(retrievedServiceAccount.id).assertEqual('svc_456');

      transport.nextBody = '{"object":"organization.project.service_account.deleted","id":"svc_456","deleted":true}';
      const deletedServiceAccount: OrganizationProjectServiceAccountDeleted =
        await client.organization.projects.serviceAccounts.delete('proj_456', 'svc_456');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/service_accounts/svc_456');
      expect(deletedServiceAccount.deleted).assertEqual(true);

      transport.nextBody = '{"object":"list","data":[{"object":"project.rate_limit","id":"rl_ada","model":"ada","max_requests_per_1_minute":600,"max_tokens_per_1_minute":150000,"max_images_per_1_minute":10}],"has_more":false}';
      const rateLimits: OrganizationProjectRateLimitListResponse =
        await client.organization.projects.rateLimits.list('proj_456', { after: 'rl_100', before: 'rl_200', limit: 20 });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/rate_limits?after=rl_100&before=rl_200&limit=20');
      expect(rateLimits.data[0].model).assertEqual('ada');

      transport.nextBody = '{"object":"project.rate_limit","id":"rl_ada","model":"ada","max_requests_per_1_minute":500,"max_tokens_per_1_minute":150000,"max_images_per_1_minute":10}';
      const rateLimitRequest: OrganizationProjectRateLimitUpdateParams = {
        max_requests_per_1_minute: 500,
      };
      const rateLimit: OrganizationProjectRateLimit =
        await client.organization.projects.rateLimits.update('proj_456', 'rl_ada', rateLimitRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/rate_limits/rl_ada');
      expect(rateLimit.max_requests_per_1_minute).assertEqual(500);
    });

    it('managesOrganizationGroupsWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"object":"list","data":[{"object":"group","id":"group_123","name":"Support","created_at":1711471533,"is_scim_managed":false}],"has_more":false,"next":null}';
      const client = new OpenAI({ apiKey: 'sk-admin', baseURL: 'https://example.test/v1', transport: transport });

      const groups: OrganizationGroupListResponse = await client.organization.groups.list({ limit: 20, order: 'asc' });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/groups?limit=20&order=asc');
      expect(groups.data[0].name).assertEqual('Support');

      transport.nextBody = '{"object":"group","id":"group_456","name":"Escalations","created_at":1711471534,"is_scim_managed":false}';
      const createRequest: OrganizationGroupCreateParams = {
        name: 'Escalations',
      };
      const created: OrganizationGroup = await client.organization.groups.create(createRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/groups');
      expect(created.id).assertEqual('group_456');

      transport.nextBody = '{"object":"group","id":"group_456","name":"Tier 2","created_at":1711471534,"is_scim_managed":false}';
      const updateRequest: OrganizationGroupUpdateParams = {
        name: 'Tier 2',
      };
      const updated: OrganizationGroup = await client.organization.groups.update('group_456', updateRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/groups/group_456');
      expect(updated.name).assertEqual('Tier 2');

      transport.nextBody = '{"object":"list","data":[{"object":"organization.user","id":"user_123","name":"Ada","email":"ada@example.com","role":"owner","added_at":1711471533}],"has_more":false,"next":null}';
      const users: OrganizationGroupUserListResponse = await client.organization.groups.users.list('group_456', {
        limit: 10,
        order: 'desc',
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/groups/group_456/users?limit=10&order=desc');
      expect(users.data[0].email).assertEqual('ada@example.com');

      transport.nextBody = '{"object":"group.user","user_id":"user_123","group_id":"group_456"}';
      const userRequest: OrganizationGroupUserCreateParams = {
        user_id: 'user_123',
      };
      const addedUser: OrganizationGroupUser = await client.organization.groups.users.create('group_456', userRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/groups/group_456/users');
      expect(addedUser.group_id).assertEqual('group_456');

      transport.nextBody = '{"object":"group.user.deleted","deleted":true}';
      const deletedUser: OrganizationGroupUserDeleted = await client.organization.groups.users.delete('group_456', 'user_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/groups/group_456/users/user_123');
      expect(deletedUser.deleted).assertEqual(true);

      transport.nextBody = '{"object":"group.deleted","id":"group_456","deleted":true}';
      const deleted: OrganizationGroupDeleted = await client.organization.groups.delete('group_456');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/groups/group_456');
      expect(deleted.deleted).assertEqual(true);
    });

    it('managesOrganizationUsersAndInvitesWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"object":"list","data":[{"object":"organization.user","id":"user_123","name":"Ada","email":"ada@example.com","role":"reader","added_at":1711471533}],"has_more":false}';
      const client = new OpenAI({ apiKey: 'sk-admin', baseURL: 'https://example.test/v1', transport: transport });

      const users: OrganizationUserListResponse = await client.organization.users.list({ after: 'user_100', limit: 20 });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/users?after=user_100&limit=20');
      expect(users.data[0].role).assertEqual('reader');

      transport.nextBody = '{"object":"organization.user","id":"user_123","name":"Ada","email":"ada@example.com","role":"owner","added_at":1711471533}';
      const user: OrganizationUser = await client.organization.users.retrieve('user_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/users/user_123');
      expect(user.email).assertEqual('ada@example.com');

      transport.nextBody = '{"object":"organization.user","id":"user_123","name":"Ada","email":"ada@example.com","role":"owner","added_at":1711471533}';
      const updateUserRequest: OrganizationUserUpdateParams = {
        role: 'owner',
      };
      const updatedUser: OrganizationUser = await client.organization.users.update('user_123', updateUserRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/users/user_123');
      expect(updatedUser.role).assertEqual('owner');

      transport.nextBody = '{"object":"organization.user.deleted","id":"user_123","deleted":true}';
      const deletedUser: OrganizationUserDeleted = await client.organization.users.delete('user_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/users/user_123');
      expect(deletedUser.deleted).assertEqual(true);

      transport.nextBody = '{"object":"list","data":[{"object":"organization.invite","id":"invite_123","email":"new@example.com","role":"reader","status":"pending","invited_at":1711471533,"expires_at":1711475133,"accepted_at":null}],"has_more":false}';
      const invites: OrganizationInviteListResponse = await client.organization.invites.list({ after: 'invite_100', limit: 20 });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/invites?after=invite_100&limit=20');
      expect(invites.data[0].status).assertEqual('pending');

      transport.nextBody = '{"object":"organization.invite","id":"invite_456","email":"new@example.com","role":"reader","status":"pending","invited_at":1711471533,"expires_at":1711475133,"accepted_at":null,"projects":[{"id":"proj_456","role":"member"}]}';
      const inviteProjects: Array<OrganizationInviteProject> = [{ id: 'proj_456', role: 'member' }];
      const inviteRequest: OrganizationInviteCreateParams = {
        email: 'new@example.com',
        role: 'reader',
        projects: inviteProjects,
      };
      const invite: OrganizationInvite = await client.organization.invites.create(inviteRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/invites');
      expect(transport.latestBody).assertContain('"projects"');
      expect(invite.id).assertEqual('invite_456');

      transport.nextBody = '{"object":"organization.invite","id":"invite_456","email":"new@example.com","role":"reader","status":"pending","invited_at":1711471533,"expires_at":1711475133,"accepted_at":null}';
      const retrievedInvite: OrganizationInvite = await client.organization.invites.retrieve('invite_456');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/invites/invite_456');
      expect(retrievedInvite.email).assertEqual('new@example.com');

      transport.nextBody = '{"object":"organization.invite.deleted","id":"invite_456","deleted":true}';
      const deletedInvite: OrganizationInviteDeleted = await client.organization.invites.delete('invite_456');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/invites/invite_456');
      expect(deletedInvite.deleted).assertEqual(true);

      transport.nextBody = '{"object":"list","data":[{"object":"organization.admin_api_key","id":"key_admin_123","name":"Main Admin Key","redacted_value":"sk-admin...xyz","created_at":1711471533,"last_used_at":1711471534,"owner":{"type":"user","object":"organization.user","id":"user_123","name":"Ada","created_at":1711471533,"role":"owner"}}],"has_more":false}';
      const adminKeys: OrganizationAdminApiKeyListResponse = await client.organization.adminApiKeys.list({
        after: 'key_admin_100',
        limit: 20,
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/admin_api_keys?after=key_admin_100&limit=20');
      expect(adminKeys.data[0].redacted_value).assertEqual('sk-admin...xyz');

      transport.nextBody = '{"object":"organization.admin_api_key","id":"key_admin_456","name":"Automation","redacted_value":"sk-admin...abc","value":"sk-admin-secret","created_at":1711471535,"owner":{"type":"user","object":"organization.user","id":"user_123","name":"Ada","created_at":1711471533,"role":"owner"}}';
      const adminKeyRequest: OrganizationAdminApiKeyCreateParams = {
        name: 'Automation',
      };
      const adminKey: OrganizationAdminApiKey = await client.organization.adminApiKeys.create(adminKeyRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/admin_api_keys');
      expect(adminKey.value).assertEqual('sk-admin-secret');

      transport.nextBody = '{"object":"organization.admin_api_key","id":"key_admin_456","name":"Automation","redacted_value":"sk-admin...abc","created_at":1711471535,"owner":{"type":"user","object":"organization.user","id":"user_123","name":"Ada","created_at":1711471533,"role":"owner"}}';
      const retrievedAdminKey: OrganizationAdminApiKey = await client.organization.adminApiKeys.retrieve('key_admin_456');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/admin_api_keys/key_admin_456');
      expect(retrievedAdminKey.name).assertEqual('Automation');

      transport.nextBody = '{"object":"organization.admin_api_key.deleted","id":"key_admin_456","deleted":true}';
      const deletedAdminKey: OrganizationAdminApiKeyDeleted = await client.organization.adminApiKeys.delete('key_admin_456');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/admin_api_keys/key_admin_456');
      expect(deletedAdminKey.deleted).assertEqual(true);
    });

    it('managesOrganizationAndProjectRolesWithOpenAIClient', 0, async () => {
      const transport = new FakeTransport();
      transport.nextBody = '{"object":"list","data":[{"object":"role","id":"role_org_123","name":"API Group Manager","description":"Manage groups","permissions":["api.groups.read"],"resource_type":"api.organization","predefined_role":false}],"has_more":false,"next":null}';
      const client = new OpenAI({ apiKey: 'sk-admin', baseURL: 'https://example.test/v1', transport: transport });

      const orgRoles: OrganizationRoleListResponse = await client.organization.roles.list({
        limit: 20,
        order: 'asc',
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/roles?limit=20&order=asc');
      expect(orgRoles.data[0].id).assertEqual('role_org_123');

      transport.nextBody = '{"object":"role","id":"role_org_456","name":"API Group Writer","description":"Write groups","permissions":["api.groups.write"],"resource_type":"api.organization","predefined_role":false}';
      const orgPermissions: Array<string> = ['api.groups.write'];
      const createRoleRequest: OrganizationRoleCreateParams = {
        role_name: 'API Group Writer',
        permissions: orgPermissions,
        description: 'Write groups',
      };
      const createdRole: OrganizationRole = await client.organization.roles.create(createRoleRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/roles');
      expect(createdRole.name).assertEqual('API Group Writer');

      transport.nextBody = '{"object":"role","id":"role_org_456","name":"API Group Writer","description":"Read and write groups","permissions":["api.groups.read","api.groups.write"],"resource_type":"api.organization","predefined_role":false}';
      const updatePermissions: Array<string> = ['api.groups.read', 'api.groups.write'];
      const updateRoleRequest: OrganizationRoleUpdateParams = {
        permissions: updatePermissions,
        description: 'Read and write groups',
      };
      const updatedRole: OrganizationRole = await client.organization.roles.update('role_org_456', updateRoleRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/roles/role_org_456');
      expect(updatedRole.permissions.length).assertEqual(2);

      transport.nextBody = '{"object":"role.deleted","id":"role_org_456","deleted":true}';
      const deletedRole: OrganizationRoleDeleted = await client.organization.roles.delete('role_org_456');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/roles/role_org_456');
      expect(deletedRole.deleted).assertEqual(true);

      transport.nextBody = '{"object":"list","data":[{"object":"role","id":"role_proj_123","name":"API Key Manager","description":"Manage keys","permissions":["api.organization.projects.api_keys.read"],"resource_type":"api.project","predefined_role":false}],"has_more":false,"next":null}';
      const projectRoles: OrganizationRoleListResponse = await client.organization.projects.roles.list('proj_456', {
        limit: 20,
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/projects/proj_456/roles?limit=20');
      expect(projectRoles.data[0].resource_type).assertEqual('api.project');

      transport.nextBody = '{"object":"role","id":"role_proj_456","name":"API Key Writer","description":"Write keys","permissions":["api.organization.projects.api_keys.write"],"resource_type":"api.project","predefined_role":false}';
      const projectPermissions: Array<string> = ['api.organization.projects.api_keys.write'];
      const projectRoleRequest: OrganizationRoleCreateParams = {
        role_name: 'API Key Writer',
        permissions: projectPermissions,
      };
      const projectRole: OrganizationRole = await client.organization.projects.roles.create('proj_456', projectRoleRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/projects/proj_456/roles');
      expect(projectRole.id).assertEqual('role_proj_456');

      transport.nextBody = '{"object":"role.deleted","id":"role_proj_456","deleted":true}';
      const deletedProjectRole: OrganizationRoleDeleted = await client.organization.projects.roles.delete('proj_456', 'role_proj_456');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/projects/proj_456/roles/role_proj_456');
      expect(deletedProjectRole.deleted).assertEqual(true);

      transport.nextBody = '{"object":"list","data":[{"id":"req_123","type":"api_key.created","effective_at":1720804090,"actor":{"type":"session","session":{"user":{"id":"user_123","email":"ada@example.com"},"ip_address":"127.0.0.1"}},"project":{"id":"proj_456","name":"Project C"}}],"has_more":false}';
      const actorEmails: Array<string> = ['ada@example.com'];
      const eventTypes: Array<string> = ['api_key.created'];
      const projectIds: Array<string> = ['proj_456'];
      const auditLogs: OrganizationAuditLogListResponse = await client.organization.auditLogs.list({
        actor_emails: actorEmails,
        event_types: eventTypes,
        project_ids: projectIds,
        effective_at: { gte: 1720800000, lt: 1720810000 },
        limit: 20,
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/audit_logs?actor_emails[]=ada%40example.com&event_types[]=api_key.created&project_ids[]=proj_456&effective_at[gte]=1720800000&effective_at[lt]=1720810000&limit=20');
      expect(auditLogs.data[0].type).assertEqual('api_key.created');

      transport.nextBody = '{"object":"list","data":[{"object":"organization.certificate","id":"cert_123","name":"Cert A","active":true,"created_at":1234567,"certificate_details":{"valid_at":1234500,"expires_at":1239999}}],"has_more":false}';
      const certificates: OrganizationCertificateListResponse = await client.organization.certificates.list({ after: 'cert_100', limit: 20 });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/certificates?after=cert_100&limit=20');
      expect(certificates.data[0].id).assertEqual('cert_123');

      transport.nextBody = '{"object":"organization.certificate","id":"cert_456","name":"Cert B","active":false,"created_at":1234568,"certificate_details":{"valid_at":1234500,"expires_at":1239999}}';
      const certificateRequest: OrganizationCertificateCreateParams = {
        name: 'Cert B',
        certificate: '-----BEGIN CERTIFICATE-----\\nMIID\\n-----END CERTIFICATE-----',
      };
      const certificate: OrganizationCertificate = await client.organization.certificates.create(certificateRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/certificates');
      expect(certificate.active).assertEqual(false);

      transport.nextBody = '{"object":"organization.certificate","id":"cert_456","name":"Cert B","active":false,"created_at":1234568,"certificate_details":{"valid_at":1234500,"expires_at":1239999}}';
      const retrievedCertificate: OrganizationCertificate = await client.organization.certificates.retrieve('cert_456');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/certificates/cert_456');
      expect(retrievedCertificate.name).assertEqual('Cert B');

      transport.nextBody = '{"object":"organization.certificate","id":"cert_456","name":"Cert C","active":false,"created_at":1234568,"certificate_details":{"valid_at":1234500,"expires_at":1239999}}';
      const updateCertificateRequest: OrganizationCertificateUpdateParams = {
        name: 'Cert C',
      };
      const updatedCertificate: OrganizationCertificate = await client.organization.certificates.update('cert_456', updateCertificateRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/certificates/cert_456');
      expect(updatedCertificate.name).assertEqual('Cert C');

      transport.nextBody = '{"object":"organization.certificate.activation","data":[{"object":"organization.certificate","id":"cert_456","name":"Cert C","active":true,"created_at":1234568,"certificate_details":{"valid_at":1234500,"expires_at":1239999}}]}';
      const certificateIDs: Array<string> = ['cert_456'];
      const toggleRequest: OrganizationCertificateToggleParams = {
        certificate_ids: certificateIDs,
      };
      const activation: OrganizationCertificateActivationResponse = await client.organization.certificates.activate(toggleRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/certificates/activate');
      expect(activation.data[0].active).assertEqual(true);

      transport.nextBody = '{"object":"certificate.deleted","id":"cert_456"}';
      const deletedCertificate: OrganizationCertificateDeleted = await client.organization.certificates.delete('cert_456');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/certificates/cert_456');
      expect(deletedCertificate.id).assertEqual('cert_456');

      transport.nextBody = '{"object":"list","data":[{"object":"organization.project.certificate","id":"cert_456","name":"Cert C","active":true,"created_at":1234568,"certificate_details":{"valid_at":1234500,"expires_at":1239999}}],"has_more":false}';
      const projectCertificates: OrganizationCertificateListResponse = await client.organization.projects.certificates.list('proj_456');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/certificates');
      expect(projectCertificates.data[0].active).assertEqual(true);

      transport.nextBody = '{"object":"organization.project.certificate.deactivation","data":[{"object":"organization.project.certificate","id":"cert_456","name":"Cert C","active":false,"created_at":1234568,"certificate_details":{"valid_at":1234500,"expires_at":1239999}}]}';
      const projectDeactivation: OrganizationCertificateActivationResponse =
        await client.organization.projects.certificates.deactivate('proj_456', toggleRequest);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/organization/projects/proj_456/certificates/deactivate');
      expect(projectDeactivation.data[0].active).assertEqual(false);
    });
  });
}
