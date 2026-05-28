import { describe, it, expect } from '@ohos/hypium';
import {
  OpenAI,
  OpenAIAPIError,
  OpenAICancelToken,
  type OpenAIMultipartFormData,
  type OpenAIRequestOptions,
  type OpenAIResponse,
  type OpenAIStream,
  type OpenAIStreamChunkHandler,
  type OpenAITransport,
  type ResponseDeleted,
} from '../../Index';

class ReturnValueFakeTransport implements OpenAITransport {
  latestUrl: string = '';
  latestMethod: string = '';
  latestHeaders: Record<string, string> = {};
  latestBody: string = '';
  latestMultipart: Array<OpenAIMultipartFormData> = [];
  latestResponseDataType: string = '';
  latestReadTimeout: number = 0;
  latestConnectTimeout: number = 0;
  nextBody: string = '{"object":"list","data":[]}';
  nextStatusCode: number = 200;
  requestCount: number = 0;
  responseBodies: Array<string> = [];
  responseStatusCodes: Array<number> = [];

  async request(options: OpenAIRequestOptions): Promise<OpenAIResponse> {
    const responseIndex = this.captureRequest(options);
    const statusCode = responseIndex < this.responseStatusCodes.length ?
      this.responseStatusCodes[responseIndex] : this.nextStatusCode;
    const body = responseIndex < this.responseBodies.length ? this.responseBodies[responseIndex] : this.nextBody;
    return {
      statusCode: statusCode,
      body: body,
    };
  }

  stream(options: OpenAIRequestOptions, onChunk: OpenAIStreamChunkHandler): OpenAIStream {
    this.captureRequest(options);
    onChunk(this.nextBody);
    return new ReturnValueFakeStream();
  }

  private captureRequest(options: OpenAIRequestOptions): number {
    const responseIndex = this.requestCount;
    this.requestCount += 1;
    this.latestUrl = options.url;
    this.latestMethod = options.method;
    this.latestHeaders = options.headers;
    this.latestBody = options.body === undefined ? '' : options.body;
    this.latestMultipart = options.multipart === undefined ? [] : options.multipart;
    this.latestResponseDataType = options.responseDataType === undefined ? '' : options.responseDataType;
    this.latestReadTimeout = options.readTimeout;
    this.latestConnectTimeout = options.connectTimeout;
    return responseIndex;
  }
}

class ReturnValueFakeStream implements OpenAIStream {
  closed: boolean = false;
  close(): void {
    this.closed = true;
  }
}

export default function returnValuesUnitTest() {
  describe('returnValuesUnitTest', () => {
    it('usesDefaultHeadersUrlAndTimeoutsWithOpenAIClient', 0, async () => {
      const transport = new ReturnValueFakeTransport();
      const client = new OpenAI({
        apiKey: 'sk-test',
        transport: transport,
      });

      const response = await client.models.list();

      expect(transport.latestUrl).assertEqual('https://api.openai.com/v1/models');
      expect(transport.latestMethod).assertEqual('GET');
      expect(transport.latestHeaders['Authorization']).assertEqual('Bearer sk-test');
      expect(transport.latestHeaders['Accept']).assertEqual('application/json');
      expect(transport.latestHeaders['Content-Type']).assertEqual('application/json');
      expect(transport.latestReadTimeout).assertEqual(60000);
      expect(transport.latestConnectTimeout).assertEqual(60000);
      expect(response.object).assertEqual('list');
      expect(response.data.length).assertEqual(0);
    });

    it('keepsApiErrorStatusBodyAndDoesNotRetryClientErrors', 0, async () => {
      const transport = new ReturnValueFakeTransport();
      transport.nextStatusCode = 400;
      transport.nextBody = '{"error":{"message":"bad request","type":"invalid_request_error"}}';
      const client = new OpenAI({
        apiKey: 'sk-test',
        baseURL: 'https://example.test/v1',
        maxRetries: 3,
        transport: transport,
      });
      let failed = false;
      let statusCode = 0;
      let responseBody = '';

      try {
        await client.models.list();
      } catch (error) {
        if (error instanceof OpenAIAPIError) {
          failed = true;
          statusCode = error.statusCode;
          responseBody = error.responseBody;
        }
      }

      expect(failed).assertEqual(true);
      expect(statusCode).assertEqual(400);
      expect(responseBody).assertContain('bad request');
      expect(transport.requestCount).assertEqual(1);
    });

    it('returnsResponseDeleteConfirmationWithOpenAIClient', 0, async () => {
      const transport = new ReturnValueFakeTransport();
      transport.nextBody = '{"id":"resp_123","object":"response","deleted":true}';
      const client = new OpenAI({
        apiKey: 'sk-test',
        baseURL: 'https://example.test/v1',
        transport: transport,
      });

      const deleted: ResponseDeleted = await client.responses.delete('resp_123');

      expect(transport.latestUrl).assertEqual('https://example.test/v1/responses/resp_123');
      expect(transport.latestMethod).assertEqual('DELETE');
      expect(deleted.id).assertEqual('resp_123');
      expect(deleted.object).assertEqual('response');
      expect(deleted.deleted).assertEqual(true);
    });

    it('returnsBinaryDownloadContentAndRequestsArrayBuffer', 0, async () => {
      const transport = new ReturnValueFakeTransport();
      transport.nextBody = 'AAECAw==';
      const client = new OpenAI({
        apiKey: 'sk-test',
        baseURL: 'https://example.test/v1',
        transport: transport,
      });

      const content = await client.videos.downloadContent('video_123', { variant: 'thumbnail' });
      const headerKeys = Object.keys(transport.latestHeaders);

      expect(transport.latestUrl).assertEqual('https://example.test/v1/videos/video_123/content?variant=thumbnail');
      expect(transport.latestResponseDataType).assertEqual('arraybuffer');
      expect(headerKeys.indexOf('Content-Type')).assertEqual(-1);
      expect(content).assertEqual('AAECAw==');
    });

    it('keepsMultipartFieldsAndParsesImageEditResponse', 0, async () => {
      const transport = new ReturnValueFakeTransport();
      transport.nextBody = '{"created":1710000000,"data":[{"b64_json":"image-base64","revised_prompt":"blend"}]}';
      const client = new OpenAI({
        apiKey: 'sk-test',
        baseURL: 'https://example.test/v1',
        transport: transport,
      });

      const response = await client.images.edit({
        image: ['file://left.png', 'file://right.png'],
        prompt: 'Blend',
        mask: 'file://mask.png',
        model: 'gpt-image-1',
        n: 2,
        size: '1024x1024',
      });

      expect(transport.latestUrl).assertEqual('https://example.test/v1/images/edits');
      expect(transport.latestMultipart.length).assertEqual(7);
      expect(transport.latestMultipart[0].name).assertEqual('image');
      expect(transport.latestMultipart[0].remoteFileName).assertEqual('left.png');
      expect(transport.latestMultipart[1].remoteFileName).assertEqual('right.png');
      expect(transport.latestMultipart[2].name).assertEqual('prompt');
      expect(transport.latestMultipart[2].data).assertEqual('Blend');
      expect(transport.latestMultipart[3].name).assertEqual('mask');
      expect(transport.latestMultipart[4].data).assertEqual('gpt-image-1');
      expect(transport.latestMultipart[5].data).assertEqual('2');
      expect(transport.latestMultipart[6].data).assertEqual('1024x1024');
      expect(response.created).assertEqual(1710000000);
      expect(response.data![0].b64_json).assertEqual('image-base64');
    });

    it('callsCancelCallbacksOnceAndImmediatelyAfterCancel', 0, () => {
      const token = new OpenAICancelToken();
      let callbackCount = 0;

      token.onCancel(() => {
        callbackCount += 1;
      });
      token.cancel();
      token.cancel();
      token.onCancel(() => {
        callbackCount += 1;
      });

      expect(token.isCancelled()).assertEqual(true);
      expect(callbackCount).assertEqual(2);
    });
  });
}
