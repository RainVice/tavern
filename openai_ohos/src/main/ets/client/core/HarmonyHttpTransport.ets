import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { OpenAINetworkError } from './OpenAIAPIError';
import type {
  OpenAIHttpMethod,
  OpenAIMultipartFormData,
  OpenAIRequestOptions,
  OpenAIResponse,
  OpenAIStream,
  OpenAIStreamChunkHandler,
  OpenAIStreamDoneHandler,
  OpenAIStreamErrorHandler,
  OpenAITransport,
} from './Types';

/**
 * HarmonyOS 默认 HTTP transport。
 *
 * API：所有 OpenAI REST API。
 * 说明：封装 `@kit.NetworkKit` 的 HTTP 请求能力，业务资源不直接依赖 Harmony 网络 API。
 */
export class HarmonyHttpTransport implements OpenAITransport {
  /**
   * 发起 Harmony HTTP 请求。
   *
   * API：所有 OpenAI REST API。
   * 说明：目前统一按字符串响应处理，JSON 解析交给资源层。
   */
  async request(options: OpenAIRequestOptions): Promise<OpenAIResponse> {
    const request = http.createHttp();
    if (options.cancelToken !== undefined) {
      options.cancelToken.onCancel(() => {
        request.destroy();
      });
    }
    try {
      const response = await request.request(options.url, {
        method: options.method,
        header: options.headers,
        extraData: options.body,
        multiFormDataList: this.toMultiFormDataList(options.multipart),
        readTimeout: options.readTimeout,
        connectTimeout: options.connectTimeout,
        expectDataType: this.toHttpDataType(options.responseDataType),
      });
      return {
        statusCode: response.responseCode as number,
        body: this.toResponseBody(response.result),
      };
    } catch (error) {
      throw new OpenAINetworkError(String(error));
    } finally {
      request.destroy();
    }
  }

  /**
   * 发起 Harmony HTTP streaming 请求。
   *
   * API：SSE streaming。
   * 说明：使用 `requestInStream` 监听 `dataReceive`，逐块交给 SDK SSE parser。
   */
  stream(
    options: OpenAIRequestOptions,
    onChunk: OpenAIStreamChunkHandler,
    onError?: OpenAIStreamErrorHandler,
    onDone?: OpenAIStreamDoneHandler
  ): OpenAIStream {
    const request = http.createHttp();
    const decoder = util.TextDecoder.create('utf-8');
    let closed = false;
    const closeStream = (): void => {
      if (closed) {
        return;
      }
      closed = true;
      request.destroy();
    };
    if (options.cancelToken !== undefined) {
      options.cancelToken.onCancel(closeStream);
    }
    request.on('dataReceive', (data: ArrayBuffer) => {
      if (closed) {
        return;
      }
      onChunk(decoder.decodeToString(new Uint8Array(data)));
    });
    request.on('dataEnd', () => {
      if (closed) {
        return;
      }
      if (onDone !== undefined) {
        onDone();
      }
      closeStream();
    });
    request.requestInStream(options.url, {
      method: options.method,
      header: options.headers,
      extraData: options.body,
      multiFormDataList: this.toMultiFormDataList(options.multipart),
      readTimeout: options.readTimeout,
      connectTimeout: options.connectTimeout,
    }).catch((error: Error) => {
      if (closed) {
        return;
      }
      if (onError !== undefined) {
        onError(String(error));
      }
      closeStream();
    });
    return new HarmonyOpenAIStream(closeStream);
  }

  private toHttpDataType(responseDataType?: string): http.HttpDataType {
    if (responseDataType === 'arraybuffer') {
      return http.HttpDataType.ARRAY_BUFFER;
    }
    return http.HttpDataType.STRING;
  }

  private toMultiFormDataList(parts?: Array<OpenAIMultipartFormData>): Array<http.MultiFormData> | undefined {
    if (parts === undefined) {
      return undefined;
    }
    const dataList: Array<http.MultiFormData> = [];
    for (let index = 0; index < parts.length; index++) {
      const part = parts[index];
      const item: http.MultiFormData = {
        name: part.name,
        contentType: part.contentType,
      };
      if (part.remoteFileName !== undefined) {
        item.remoteFileName = part.remoteFileName;
      }
      if (part.data !== undefined) {
        item.data = part.data;
      }
      if (part.filePath !== undefined) {
        item.filePath = part.filePath;
      }
      dataList.push(item);
    }
    return dataList;
  }

  private toResponseBody(result: string | Object | ArrayBuffer): string {
    if (typeof result === 'string') {
      return result;
    }
    if (result instanceof ArrayBuffer) {
      const bytes = new Uint8Array(result);
      const base64 = new util.Base64Helper();
      return base64.encodeToStringSync(bytes);
    }
    return JSON.stringify(result);
  }
}

class HarmonyOpenAIStream implements OpenAIStream {
  private closeHandler: () => void;

  constructor(closeHandler: () => void) {
    this.closeHandler = closeHandler;
  }

  close(): void {
    this.closeHandler();
  }
}
