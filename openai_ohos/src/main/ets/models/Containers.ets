import type { CursorPageParams, OpenAIListResponse } from './Common';

/**
 * Containers API model。
 *
 * API：`/v1/containers`、`/v1/containers/{container_id}/files`。
 * 说明：管理 Code Interpreter 工具使用的容器和容器内文件。
 */

/** Container 状态。API：Containers。说明：表示容器运行或删除状态。 */
export type ContainerStatus = 'running' | 'deleted';

/** Container 内存规格。API：Create Container。说明：控制代码解释器容器可用内存。 */
export type ContainerMemoryLimit = '1g' | '4g' | '16g' | '64g';

/** Container 网络策略类型。API：Create Container。说明：控制容器外网访问能力。 */
export type ContainerNetworkPolicyType = 'allowlist' | 'disabled';

/**
 * Container 过期策略。
 *
 * API：Create/Retrieve Container。
 * 说明：按最后活跃时间自动释放容器。
 */
export interface ContainerExpiresAfter {
  /** 过期锚点。API：Containers。说明：当前官方使用 `last_active_at`。 */
  anchor?: 'last_active_at';
  /** 分钟数。API：Containers。说明：从锚点开始经过多少分钟后过期。 */
  minutes?: number;
}

/**
 * Container 域名密钥。
 *
 * API：Create Container。
 * 说明：给 allowlist 域名注入指定密钥。
 */
export interface ContainerNetworkPolicyDomainSecret {
  /** 域名。API：Create Container。说明：密钥关联的目标域名。 */
  domain: string;
  /** 密钥名。API：Create Container。说明：容器内暴露给该域的密钥名称。 */
  name: string;
  /** 密钥值。API：Create Container。说明：敏感值会发送到 OpenAI 容器配置。 */
  value: string;
}

/**
 * Container 网络策略。
 *
 * API：Create/Retrieve Container。
 * 说明：`disabled` 禁止外网，`allowlist` 只允许指定域名。
 */
export interface ContainerNetworkPolicy {
  /** 策略类型。API：Containers。说明：`allowlist` 或 `disabled`。 */
  type: ContainerNetworkPolicyType;
  /** 允许域名。API：Containers。说明：当 type 为 `allowlist` 时使用。 */
  allowed_domains?: Array<string>;
  /** 域名密钥。API：Create Container。说明：为 allowlist 域名提供密钥。 */
  domain_secrets?: Array<ContainerNetworkPolicyDomainSecret>;
}

/**
 * Skill 引用。
 *
 * API：Create Container。
 * 说明：引用已创建的 skill 或内置 skill。
 */
export interface ContainerSkillReference {
  /** 类型。API：Create Container。说明：固定为 `skill_reference`。 */
  type: 'skill_reference';
  /** Skill ID。API：Create Container。说明：要挂载到容器的 skill。 */
  skill_id: string;
  /** Skill 版本。API：Create Container。说明：可传具体版本或 `latest`。 */
  version?: string;
}

/**
 * Inline Skill source。
 *
 * API：Create Container。
 * 说明：使用 base64 zip 直接定义容器 skill。
 */
export interface ContainerInlineSkillSource {
  /** Source 类型。API：Create Container。说明：固定为 `base64`。 */
  type: 'base64';
  /** 媒体类型。API：Create Container。说明：固定为 `application/zip`。 */
  media_type: 'application/zip';
  /** 数据。API：Create Container。说明：base64 编码的 skill zip。 */
  data: string;
}

/**
 * Inline Skill。
 *
 * API：Create Container。
 * 说明：在创建容器时直接上传一个 skill。
 */
export interface ContainerInlineSkill {
  /** 类型。API：Create Container。说明：固定为 `inline`。 */
  type: 'inline';
  /** 名称。API：Create Container。说明：skill 名称。 */
  name: string;
  /** 描述。API：Create Container。说明：skill 能力说明。 */
  description: string;
  /** 源码包。API：Create Container。说明：base64 zip。 */
  source: ContainerInlineSkillSource;
}

/** Container skill。API：Create Container。说明：可引用已有 skill 或传 inline skill。 */
export type ContainerSkill = ContainerSkillReference | ContainerInlineSkill;

/**
 * 创建 Container 参数。
 *
 * API：`POST /v1/containers`。
 * 说明：创建 Code Interpreter 容器，可配置名称、内存、网络和 skill。
 */
export interface ContainerCreateParams {
  /** 名称。API：Create Container。说明：用于识别容器。 */
  name?: string;
  /** 内存限制。API：Create Container。说明：例如 `4g`。 */
  memory_limit?: ContainerMemoryLimit;
  /** 过期策略。API：Create Container。说明：控制容器自动释放。 */
  expires_after?: ContainerExpiresAfter;
  /** 网络策略。API：Create Container。说明：控制容器出站网络访问。 */
  network_policy?: ContainerNetworkPolicy;
  /** Skills。API：Create Container。说明：给容器挂载工具能力。 */
  skills?: Array<ContainerSkill>;
}

/**
 * Container 对象。
 *
 * API：Create/Retrieve/List Container。
 * 说明：表示一个可供 Code Interpreter 使用的运行容器。
 */
export interface Container {
  /** Container ID。API：Containers。说明：后续文件管理和删除使用该 ID。 */
  id: string;
  /** 对象类型。API：Containers。说明：固定为 `container`。 */
  object: 'container';
  /** 创建时间。API：Containers。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 名称。API：Containers。说明：创建时设置的容器名称。 */
  name?: string;
  /** 状态。API：Containers。说明：例如 `running` 或 `deleted`。 */
  status: ContainerStatus | string;
  /** 过期策略。API：Containers。说明：控制容器自动释放。 */
  expires_after?: ContainerExpiresAfter;
  /** 最后活跃时间。API：Containers。说明：Unix 秒级时间戳。 */
  last_active_at?: number;
  /** 内存限制。API：Containers。说明：容器当前内存规格。 */
  memory_limit?: ContainerMemoryLimit;
  /** 网络策略。API：Containers。说明：容器当前网络访问配置。 */
  network_policy?: ContainerNetworkPolicy;
}

/** Container 列表参数。API：List Containers。说明：支持游标分页。 */
export interface ContainerListParams extends CursorPageParams {
}

/** Container 列表响应。API：List Containers。说明：列表元素为 Container。 */
export type ContainerListResponse = OpenAIListResponse<Container>;

/** 删除 Container 响应。API：Delete Container。说明：表示容器删除结果。 */
export interface ContainerDeleted {
  /** Container ID。API：Delete Container。说明：被删除的容器 ID。 */
  id: string;
  /** 对象类型。API：Delete Container。说明：通常为 `container.deleted`。 */
  object: string;
  /** 删除结果。API：Delete Container。说明：`true` 表示已删除。 */
  deleted: boolean;
}

/** Container file 来源。API：Container Files。说明：表示文件来自用户或助手。 */
export type ContainerFileSource = 'user' | 'assistant' | string;

/**
 * Container File 对象。
 *
 * API：Container Files。
 * 说明：表示容器内的一个文件。
 */
export interface ContainerFile {
  /** 文件 ID。API：Container Files。说明：容器内文件 ID。 */
  id: string;
  /** 对象类型。API：Container Files。说明：固定为 `container.file`。 */
  object: 'container.file';
  /** 创建时间。API：Container Files。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 文件大小。API：Container Files。说明：字节数。 */
  bytes: number;
  /** 所属容器。API：Container Files。说明：文件所在 Container ID。 */
  container_id: string;
  /** 容器内路径。API：Container Files。说明：例如 `/mnt/data/input.txt`。 */
  path: string;
  /** 来源。API：Container Files。说明：例如 `user` 或 `assistant`。 */
  source: ContainerFileSource;
}

/**
 * 创建 Container File 参数。
 *
 * API：`POST /v1/containers/{container_id}/files`。
 * 说明：可通过本地文件 multipart 上传，或通过 OpenAI File ID 创建容器文件。
 */
export interface ContainerFileCreateParams {
  /** 本地文件路径。API：Create Container File。说明：存在时使用 multipart 字段 `file`。 */
  file?: string;
  /** OpenAI File ID。API：Create Container File。说明：存在时使用 JSON 请求体。 */
  file_id?: string;
}

/** Container File 列表参数。API：List Container Files。说明：支持游标分页。 */
export interface ContainerFileListParams extends CursorPageParams {
}

/** Container File 列表响应。API：List Container Files。说明：列表元素为 Container File。 */
export type ContainerFileListResponse = OpenAIListResponse<ContainerFile>;

/** 删除 Container File 响应。API：Delete Container File。说明：表示容器内文件删除结果。 */
export interface ContainerFileDeleted {
  /** 文件 ID。API：Delete Container File。说明：被删除的容器文件 ID。 */
  id: string;
  /** 对象类型。API：Delete Container File。说明：通常为 `container.file.deleted`。 */
  object: string;
  /** 删除结果。API：Delete Container File。说明：`true` 表示已删除。 */
  deleted: boolean;
}
