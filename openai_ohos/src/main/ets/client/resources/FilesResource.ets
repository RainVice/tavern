import { fileIo } from '@kit.CoreFileKit';
import type {
  FileContentWriter,
  FileCreateParams,
  FileDeleted,
  FileDownloadOptions,
  FileDownloadResult,
  FileListParams,
  FileListResponse,
  FileObject,
} from '../../models/Files';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import { appendCursorQuery, appendStringQuery, buildFilePart, buildPathWithQuery, buildTextPart, encodePathParam } from '../core/RequestUtils';
import type { OpenAIMultipartFormData } from '../core/Types';

/**
 * Files 资源入口。
 *
 * API：`/v1/files`。
 * 说明：覆盖 multipart 上传、列表、获取、删除、内容读取和文件落盘下载。
 */
export interface OpenAIFilesResource {
  /**
   * 上传文件。
   *
   * API：`POST /v1/files`。
   * 说明：使用 multipart 上传本地文件。
   */
  create(params: FileCreateParams): Promise<FileObject>;

  /**
   * 列出文件。
   *
   * API：`GET /v1/files`。
   * 说明：返回当前项目下已上传文件列表。
   */
  list(params?: FileListParams): Promise<FileListResponse>;

  /**
   * 获取文件。
   *
   * API：`GET /v1/files/{file_id}`。
   * 说明：返回单个文件元数据。
   */
  retrieve(fileID: string): Promise<FileObject>;

  /**
   * 删除文件。
   *
   * API：`DELETE /v1/files/{file_id}`。
   * 说明：删除已上传文件。
   */
  delete(fileID: string): Promise<FileDeleted>;

  /**
   * 读取文件内容。
   *
   * API：`GET /v1/files/{file_id}/content`。
   * 说明：返回文件原始内容字符串，常用于读取 batch 输出 JSONL。
   */
  content(fileID: string): Promise<string>;

  /**
   * 下载文件内容并写入本地路径。
   *
   * API：`GET /v1/files/{file_id}/content`。
   * 说明：默认使用 Harmony fileIo 写入；测试可通过 options.writer 注入写入器。
   */
  download(fileID: string, destinationPath: string, options?: FileDownloadOptions): Promise<FileDownloadResult>;
}

class HarmonyFileContentWriter implements FileContentWriter {
  write(destinationPath: string, contentBody: string): number {
    const file = this.openFile(destinationPath);
    try {
      return this.writeContent(file.fd, contentBody);
    } finally {
      this.closeFile(file);
    }
  }

  private openFile(destinationPath: string): fileIo.File {
    try {
      return fileIo.openSync(destinationPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY);
    } catch (error) {
      throw new Error('打开文件失败: ' + String(error));
    }
  }

  private writeContent(fd: number, contentBody: string): number {
    try {
      return fileIo.writeSync(fd, contentBody);
    } catch (error) {
      throw new Error('写入文件失败: ' + String(error));
    }
  }

  private closeFile(file: fileIo.File): void {
    try {
      fileIo.closeSync(file);
    } catch (error) {
      throw new Error('关闭文件失败: ' + String(error));
    }
  }
}

export class FilesResource implements OpenAIFilesResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async create(params: FileCreateParams): Promise<FileObject> {
    const parts: Array<OpenAIMultipartFormData> = [];
    parts.push(buildFilePart('file', params.file));
    parts.push(buildTextPart('purpose', params.purpose));
    const body = await this.client.postMultipart('/files', parts);
    return JSON.parse(body) as FileObject;
  }

  async list(params?: FileListParams): Promise<FileListResponse> {
    const body = await this.client.get(this.buildListPath(params));
    return JSON.parse(body) as FileListResponse;
  }

  async retrieve(fileID: string): Promise<FileObject> {
    const body = await this.client.get('/files/' + encodePathParam(fileID));
    return JSON.parse(body) as FileObject;
  }

  async delete(fileID: string): Promise<FileDeleted> {
    const body = await this.client.delete('/files/' + encodePathParam(fileID));
    return JSON.parse(body) as FileDeleted;
  }

  async content(fileID: string): Promise<string> {
    return await this.client.get('/files/' + encodePathParam(fileID) + '/content');
  }

  async download(fileID: string, destinationPath: string, options?: FileDownloadOptions): Promise<FileDownloadResult> {
    const contentBody = await this.content(fileID);
    const writer = options === undefined || options.writer === undefined ? new HarmonyFileContentWriter() : options.writer;
    const bytes = writer.write(destinationPath, contentBody);
    return {
      path: destinationPath,
      bytes: bytes,
    };
  }

  private buildListPath(params?: FileListParams): string {
    if (params === undefined) {
      return '/files';
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'purpose', params.purpose);
    appendCursorQuery(query, params);
    return buildPathWithQuery('/files', query);
  }
}
