import type {
  Container,
  ContainerCreateParams,
  ContainerDeleted,
  ContainerFile,
  ContainerFileCreateParams,
  ContainerFileDeleted,
  ContainerFileListParams,
  ContainerFileListResponse,
  ContainerListParams,
  ContainerListResponse,
} from '../../models/Containers';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import { buildCursorListPath, buildFilePart } from '../core/RequestUtils';

/**
 * Containers 资源入口。
 *
 * API：`/v1/containers`。
 * 说明：管理 Code Interpreter 容器。
 */
export interface OpenAIContainersResource {
  /** Files 子资源。API：Container Files。说明：管理容器内文件。 */
  files: OpenAIContainerFilesResource;
  /** 创建容器。API：`POST /v1/containers`。说明：创建 Code Interpreter 容器。 */
  create(params: ContainerCreateParams): Promise<Container>;
  /** 获取容器。API：`GET /v1/containers/{container_id}`。说明：读取容器状态。 */
  retrieve(containerID: string): Promise<Container>;
  /** 列出容器。API：`GET /v1/containers`。说明：分页读取容器列表。 */
  list(params?: ContainerListParams): Promise<ContainerListResponse>;
  /** 删除容器。API：`DELETE /v1/containers/{container_id}`。说明：释放容器。 */
  delete(containerID: string): Promise<ContainerDeleted>;
}

/**
 * Container Files 子资源。
 *
 * API：`/v1/containers/{container_id}/files`。
 * 说明：上传、列出、读取、删除容器文件。
 */
export interface OpenAIContainerFilesResource {
  /** 创建容器文件。API：Create Container File。说明：可 multipart 上传或用已有 File ID。 */
  create(containerID: string, params: ContainerFileCreateParams): Promise<ContainerFile>;
  /** 获取容器文件。API：Retrieve Container File。说明：读取文件元数据。 */
  retrieve(containerID: string, fileID: string): Promise<ContainerFile>;
  /** 列出容器文件。API：List Container Files。说明：分页读取容器内文件。 */
  list(containerID: string, params?: ContainerFileListParams): Promise<ContainerFileListResponse>;
  /** 读取容器文件内容。API：Retrieve Container File Content。说明：返回原始内容字符串（文本）或 base64 编码字符串（二进制）。 */
  content(containerID: string, fileID: string, options?: { responseDataType?: 'string' | 'arraybuffer' }): Promise<string>;
  /** 删除容器文件。API：Delete Container File。说明：删除容器内文件。 */
  delete(containerID: string, fileID: string): Promise<ContainerFileDeleted>;
}

export class ContainersResource implements OpenAIContainersResource {
  files: OpenAIContainerFilesResource;
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
    this.files = new ContainerFilesResource(client);
  }

  async create(params: ContainerCreateParams): Promise<Container> {
    const body = await this.client.post('/containers', params);
    return JSON.parse(body) as Container;
  }

  async retrieve(containerID: string): Promise<Container> {
    const body = await this.client.get('/containers/' + encodeURIComponent(containerID));
    return JSON.parse(body) as Container;
  }

  async list(params?: ContainerListParams): Promise<ContainerListResponse> {
    const body = await this.client.get(buildCursorListPath('/containers', params));
    return JSON.parse(body) as ContainerListResponse;
  }

  async delete(containerID: string): Promise<ContainerDeleted> {
    const body = await this.client.delete('/containers/' + encodeURIComponent(containerID));
    return JSON.parse(body) as ContainerDeleted;
  }
}

class ContainerFilesResource implements OpenAIContainerFilesResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(containerID: string, params: ContainerFileCreateParams): Promise<ContainerFile> {
    const encodedCID = encodeURIComponent(containerID);
    if (params.file !== undefined) {
      const part = buildFilePart('file', params.file);
      const body = await this.client.postMultipart('/containers/' + encodedCID + '/files', [part]);
      return JSON.parse(body) as ContainerFile;
    }
    const body = await this.client.post('/containers/' + encodedCID + '/files', params);
    return JSON.parse(body) as ContainerFile;
  }

  async retrieve(containerID: string, fileID: string): Promise<ContainerFile> {
    const body = await this.client.get('/containers/' + encodeURIComponent(containerID) + '/files/' + encodeURIComponent(fileID));
    return JSON.parse(body) as ContainerFile;
  }

  async list(containerID: string, params?: ContainerFileListParams): Promise<ContainerFileListResponse> {
    const body = await this.client.get(buildCursorListPath('/containers/' + encodeURIComponent(containerID) + '/files', params));
    return JSON.parse(body) as ContainerFileListResponse;
  }

  async content(containerID: string, fileID: string, options?: { responseDataType?: 'string' | 'arraybuffer' }): Promise<string> {
    const path = '/containers/' + encodeURIComponent(containerID) + '/files/' + encodeURIComponent(fileID) + '/content';
    if (options?.responseDataType === 'arraybuffer') {
      return await this.client.getBinary(path);
    }
    return await this.client.get(path);
  }

  async delete(containerID: string, fileID: string): Promise<ContainerFileDeleted> {
    const body = await this.client.delete('/containers/' + encodeURIComponent(containerID) + '/files/' + encodeURIComponent(fileID));
    return JSON.parse(body) as ContainerFileDeleted;
  }
}
