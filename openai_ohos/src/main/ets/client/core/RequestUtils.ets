import type { CursorPageParams } from '../../models/Common';
import type { OpenAIMultipartFormData } from './Types';

/**
 * OpenAI 请求工具函数。
 *
 * API：所有 OpenAI REST API。
 * 说明：集中处理分页 query、数组 query 和 multipart 常用字段，避免各 resource 重复实现。
 */

/**
 * 构建带 query 的路径。
 *
 * API：所有 GET 列表 API。
 * 说明：query 为空时返回原 path。
 */
export function buildPathWithQuery(path: string, query: Array<string>): string {
  if (query.length === 0) {
    return path;
  }
  return path + '?' + query.join('&');
}

/**
 * 构建游标分页路径。
 *
 * API：所有游标分页列表 API。
 * 说明：支持 limit、after、before、order。
 */
export function buildCursorListPath(path: string, params?: CursorPageParams): string {
  if (params === undefined) {
    return path;
  }
  const query: Array<string> = [];
  appendCursorQuery(query, params);
  return buildPathWithQuery(path, query);
}

/**
 * 追加游标分页 query。
 *
 * API：所有游标分页列表 API。
 * 说明：供带额外过滤条件的资源复用。
 */
export function appendCursorQuery(query: Array<string>, params: CursorPageParams): void {
  if (params.limit !== undefined) {
    query.push('limit=' + params.limit.toString());
  }
  if (params.after !== undefined) {
    query.push('after=' + encodeURIComponent(params.after));
  }
  if (params.before !== undefined) {
    query.push('before=' + encodeURIComponent(params.before));
  }
  if (params.order !== undefined) {
    query.push('order=' + params.order);
  }
}

/**
 * 追加字符串 query。
 *
 * API：所有带字符串过滤条件的 GET API。
 * 说明：value 为空时不追加。
 */
export function appendStringQuery(query: Array<string>, name: string, value?: string): void {
  if (value !== undefined) {
    query.push(name + '=' + encodeURIComponent(value));
  }
}

/**
 * 追加字符串数组 query。
 *
 * API：`include[]` 等重复 query 字段。
 * 说明：按 `name[]=value` 形式展开。
 */
export function appendStringArrayQuery(query: Array<string>, name: string, values?: Array<string>): void {
  if (values === undefined) {
    return;
  }
  for (let index = 0; index < values.length; index++) {
    query.push(name + '[]=' + encodeURIComponent(values[index]));
  }
}

/**
 * 从路径中提取文件名。
 *
 * API：所有 multipart 上传 API。
 * 说明：用于 Harmony multipart 的 `remoteFileName`。
 */
export function fileNameFromPath(path: string): string {
  const index = path.lastIndexOf('/');
  if (index >= 0 && index < path.length - 1) {
    return path.substring(index + 1);
  }
  return path;
}

/**
 * 构建 multipart 文件字段。
 *
 * API：Files、Uploads、Containers、Images、Audio 等上传 API。
 * 说明：默认使用 `application/octet-stream`。
 */
export function buildFilePart(name: string, filePath: string): OpenAIMultipartFormData {
  return {
    name: name,
    contentType: 'application/octet-stream',
    remoteFileName: fileNameFromPath(filePath),
    filePath: filePath,
  };
}

/**
 * 构建 multipart 文本字段。
 *
 * API：所有 multipart API。
 * 说明：普通字段统一使用 `text/plain`。
 */
export function buildTextPart(name: string, value: string): OpenAIMultipartFormData {
  return {
    name: name,
    contentType: 'text/plain',
    data: value,
  };
}
