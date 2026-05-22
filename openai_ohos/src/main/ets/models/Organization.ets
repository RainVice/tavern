import type { JsonObject, OpenAIListResponse } from './Common';

/**
 * Organization Admin API model。
 *
 * API：`/v1/organization/*`。
 * 说明：组织级管理接口通常需要 admin API key，适合服务端使用。
 */

/**
 * 组织项目状态。
 *
 * API：Organization Projects。
 * 说明：项目可处于 active 或 archived；归档后不能再用于请求或更新。
 */
export type OrganizationProjectStatus = 'active' | 'archived' | string;

/**
 * 项目成员角色。
 *
 * API：Project users、Project API keys owner。
 * 说明：官方项目内置角色为 `owner` 和 `member`，自定义角色由其他 role API 管理。
 */
export type OrganizationProjectRole = 'owner' | 'member' | string;

/**
 * 组织项目对象。
 *
 * API：`/v1/organization/projects`。
 * 说明：表示组织下的一个 OpenAI API Project。
 */
export interface OrganizationProject {
  /**
   * 项目 ID。
   *
   * API：Organization Projects。
   * 说明：用于 retrieve、update、archive 以及项目下 users/groups/api keys 等子资源。
   */
  id: string;

  /**
   * 对象类型。
   *
   * API：Organization Projects。
   * 说明：固定为 `organization.project`。
   */
  object: 'organization.project' | string;

  /**
   * 项目名称。
   *
   * API：Organization Projects。
   * 说明：展示在报表和管理后台中的友好名称。
   */
  name: string;

  /**
   * 创建时间。
   *
   * API：Organization Projects。
   * 说明：Unix 秒级时间戳。
   */
  created_at: number;

  /**
   * 归档时间。
   *
   * API：Organization Projects。
   * 说明：未归档时为 `null`。
   */
  archived_at: number | null;

  /**
   * 项目状态。
   *
   * API：Organization Projects。
   * 说明：`active` 表示可用，`archived` 表示已归档。
   */
  status: OrganizationProjectStatus;
}

/**
 * 创建组织项目参数。
 *
 * API：`POST /v1/organization/projects`。
 * 说明：在组织内创建新项目；项目只能归档，不能删除。
 */
export interface OrganizationProjectCreateParams {
  /**
   * 项目名称。
   *
   * API：Create project。
   * 说明：报表和管理后台显示的友好名称。
   */
  name: string;

  /**
   * 数据驻留区域。
   *
   * API：Create project。
   * 说明：组织开通 Data residency 后可指定；具体可选值由服务端决定。
   */
  geography?: string;
}

/**
 * 更新组织项目参数。
 *
 * API：`POST /v1/organization/projects/{project_id}`。
 * 说明：更新项目名称；归档项目不能更新。
 */
export interface OrganizationProjectUpdateParams {
  /**
   * 新项目名称。
   *
   * API：Modify project。
   * 说明：更新后显示在报表和管理后台。
   */
  name: string;
}

/**
 * 组织项目列表参数。
 *
 * API：`GET /v1/organization/projects`。
 * 说明：分页读取组织项目，可选择是否包含归档项目。
 */
export interface OrganizationProjectListParams {
  /**
   * 下一页游标。
   *
   * API：List projects。
   * 说明：传入上一页最后一个项目 ID。
   */
  after?: string;

  /**
   * 返回数量上限。
   *
   * API：List projects。
   * 说明：官方通常允许 1 到 100，默认 20。
   */
  limit?: number;

  /**
   * 是否包含归档项目。
   *
   * API：List projects。
   * 说明：`true` 返回 active 和 archived；默认只返回 active。
   */
  include_archived?: boolean;
}

/**
 * 组织项目列表响应。
 *
 * API：`GET /v1/organization/projects`。
 * 说明：分页返回项目对象数组。
 */
export type OrganizationProjectListResponse = OpenAIListResponse<OrganizationProject>;

/**
 * 项目用户对象。
 *
 * API：`/v1/organization/projects/{project_id}/users`。
 * 说明：表示某个用户在项目内的成员身份和角色。
 */
export interface OrganizationProjectUser {
  /**
   * 对象类型。
   *
   * API：Project users。
   * 说明：固定为 `organization.project.user`。
   */
  object: 'organization.project.user' | string;

  /**
   * 用户 ID。
   *
   * API：Project users。
   * 说明：用于 retrieve、update、delete 项目用户。
   */
  id: string;

  /**
   * 用户姓名。
   *
   * API：Project users。
   * 说明：组织成员的展示名称，部分响应可能省略。
   */
  name?: string;

  /**
   * 用户邮箱。
   *
   * API：Project users。
   * 说明：组织成员的邮箱地址。
   */
  email: string;

  /**
   * 项目角色。
   *
   * API：Project users。
   * 说明：`owner` 可管理项目，`member` 为普通成员。
   */
  role: OrganizationProjectRole;

  /**
   * 加入时间。
   *
   * API：Project users。
   * 说明：用户被添加到该项目的 Unix 秒级时间戳。
   */
  added_at: number;
}

/**
 * 添加项目用户参数。
 *
 * API：`POST /v1/organization/projects/{project_id}/users`。
 * 说明：把组织成员添加到项目中。
 */
export interface OrganizationProjectUserCreateParams {
  /**
   * 用户 ID。
   *
   * API：Create project user。
   * 说明：要添加到项目的组织用户 ID。
   */
  user_id: string;

  /**
   * 项目角色。
   *
   * API：Create project user。
   * 说明：官方支持 `owner` 或 `member`。
   */
  role: OrganizationProjectRole;
}

/**
 * 更新项目用户参数。
 *
 * API：`POST /v1/organization/projects/{project_id}/users/{user_id}`。
 * 说明：修改用户在项目内的角色。
 */
export interface OrganizationProjectUserUpdateParams {
  /**
   * 新项目角色。
   *
   * API：Modify project user。
   * 说明：官方支持 `owner` 或 `member`。
   */
  role: OrganizationProjectRole;
}

/**
 * 项目用户列表参数。
 *
 * API：`GET /v1/organization/projects/{project_id}/users`。
 * 说明：分页读取项目用户。
 */
export interface OrganizationProjectUserListParams {
  /** 下一页游标。API：List project users。说明：传入上一页最后一个 user ID。 */
  after?: string;
  /** 返回数量上限。API：List project users。说明：官方默认 20。 */
  limit?: number;
}

/** 项目用户列表响应。API：List project users。说明：列表元素为项目用户对象。 */
export type OrganizationProjectUserListResponse = OpenAIListResponse<OrganizationProjectUser>;

/**
 * 删除项目用户响应。
 *
 * API：`DELETE /v1/organization/projects/{project_id}/users/{user_id}`。
 * 说明：移除用户对项目的访问。
 */
export interface OrganizationProjectUserDeleted {
  /** 对象类型。API：Delete project user。说明：通常为 `organization.project.user.deleted`。 */
  object: 'organization.project.user.deleted' | string;
  /** 用户 ID。API：Delete project user。说明：被移除的用户 ID。 */
  id: string;
  /** 删除状态。API：Delete project user。说明：`true` 表示已移除。 */
  deleted: boolean;
}

/**
 * 项目组对象。
 *
 * API：`/v1/organization/projects/{project_id}/groups`。
 * 说明：表示某个组织 group 已获得项目访问权限。
 */
export interface OrganizationProjectGroup {
  /** 对象类型。API：Project groups。说明：固定为 `project.group`。 */
  object: 'project.group' | string;
  /** 项目 ID。API：Project groups。说明：被授权访问的项目。 */
  project_id: string;
  /** 组 ID。API：Project groups。说明：拥有项目访问权限的组织 group。 */
  group_id: string;
  /** 组名称。API：Project groups。说明：组织 group 的展示名称。 */
  group_name: string;
  /** 授权时间。API：Project groups。说明：Unix 秒级时间戳。 */
  created_at: number;
}

/**
 * 添加项目组参数。
 *
 * API：`POST /v1/organization/projects/{project_id}/groups`。
 * 说明：把组织 group 授权到项目，并指定项目 role。
 */
export interface OrganizationProjectGroupCreateParams {
  /** 组 ID。API：Add project group。说明：要添加到项目的组织 group。 */
  group_id: string;
  /** 角色 ID。API：Add project group。说明：授予该 group 的项目 role ID。 */
  role: string;
}

/**
 * 项目组列表参数。
 *
 * API：`GET /v1/organization/projects/{project_id}/groups`。
 * 说明：分页读取拥有项目访问权限的组。
 */
export interface OrganizationProjectGroupListParams {
  /** 下一页游标。API：List project groups。说明：传入上一页最后一个 group ID。 */
  after?: string;
  /** 返回数量上限。API：List project groups。说明：官方默认 20。 */
  limit?: number;
  /** 排序方向。API：List project groups。说明：`asc` 或 `desc`。 */
  order?: 'asc' | 'desc';
}

/** 项目组列表响应。API：List project groups。说明：列表元素为项目组对象。 */
export type OrganizationProjectGroupListResponse = OpenAIListResponse<OrganizationProjectGroup>;

/**
 * 删除项目组响应。
 *
 * API：`DELETE /v1/organization/projects/{project_id}/groups/{group_id}`。
 * 说明：撤销 group 对项目的访问。
 */
export interface OrganizationProjectGroupDeleted {
  /** 对象类型。API：Remove project group。说明：通常为 `project.group.deleted`。 */
  object: 'project.group.deleted' | string;
  /** 删除状态。API：Remove project group。说明：`true` 表示已撤销。 */
  deleted: boolean;
}

/**
 * 项目 service account 摘要。
 *
 * API：Project API keys。
 * 说明：当 API key 属于 service account 时，owner 中包含该对象。
 */
export interface OrganizationProjectServiceAccount {
  /** 对象类型。API：Project API keys owner。说明：固定为 `organization.project.service_account`。 */
  object: 'organization.project.service_account' | string;
  /** Service account ID。API：Project API keys owner。说明：服务账号标识。 */
  id: string;
  /** Service account 名称。API：Project API keys owner。说明：展示名称。 */
  name: string;
  /** 项目角色。API：Project API keys owner。说明：`owner` 或 `member`。 */
  role: OrganizationProjectRole;
  /** 创建时间。API：Project API keys owner。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 新建时返回的未脱敏 API key。API：Create project service account。说明：只在创建响应中出现，请调用方安全保存。 */
  api_key?: OrganizationProjectServiceAccountApiKey;
}

/**
 * 项目 service account API key。
 *
 * API：Create project service account。
 * 说明：创建 service account 时返回一次未脱敏密钥。
 */
export interface OrganizationProjectServiceAccountApiKey {
  /** 对象类型。API：Create project service account。说明：固定为 `organization.project.service_account.api_key`。 */
  object: 'organization.project.service_account.api_key' | string;
  /** 未脱敏 API key 值。API：Create project service account。说明：只返回一次，业务方必须安全保存。 */
  value: string;
  /** Key 名称。API：Create project service account。说明：服务端生成的 key 名称。 */
  name: string;
  /** 创建时间。API：Create project service account。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** Key ID。API：Create project service account。说明：该 service account key 的 ID。 */
  id: string;
}

/** 创建项目 service account 参数。API：`POST /v1/organization/projects/{project_id}/service_accounts`。说明：创建 bot 用户并返回一次性 API key。 */
export interface OrganizationProjectServiceAccountCreateParams {
  /** Service account 名称。API：Create project service account。说明：人类可读名称。 */
  name: string;
}

/**
 * 项目 service account 列表参数。
 *
 * API：`GET /v1/organization/projects/{project_id}/service_accounts`。
 * 说明：分页读取项目内 service accounts。
 */
export interface OrganizationProjectServiceAccountListParams {
  /** 下一页游标。API：List project service accounts。说明：传入上一页最后一个 service account ID。 */
  after?: string;
  /** 返回数量上限。API：List project service accounts。说明：官方默认 20。 */
  limit?: number;
}

/** 项目 service account 列表响应。API：List project service accounts。说明：列表元素为 service account。 */
export type OrganizationProjectServiceAccountListResponse = OpenAIListResponse<OrganizationProjectServiceAccount>;

/**
 * 删除项目 service account 响应。
 *
 * API：`DELETE /v1/organization/projects/{project_id}/service_accounts/{service_account_id}`。
 * 说明：删除项目内 bot 用户。
 */
export interface OrganizationProjectServiceAccountDeleted {
  /** 对象类型。API：Delete project service account。说明：通常为 `organization.project.service_account.deleted`。 */
  object: 'organization.project.service_account.deleted' | string;
  /** Service account ID。API：Delete project service account。说明：被删除的 service account。 */
  id: string;
  /** 删除状态。API：Delete project service account。说明：`true` 表示已删除。 */
  deleted: boolean;
}

/**
 * 项目 API key owner。
 *
 * API：Project API keys。
 * 说明：API key 可能属于用户或 service account。
 */
export interface OrganizationProjectApiKeyOwner {
  /** Owner 类型。API：Project API keys。说明：`user` 或 `service_account`。 */
  type: 'user' | 'service_account' | string;
  /** 用户 owner。API：Project API keys。说明：当 `type` 为 `user` 时存在。 */
  user?: OrganizationProjectUser;
  /** Service account owner。API：Project API keys。说明：当 `type` 为 `service_account` 时存在。 */
  service_account?: OrganizationProjectServiceAccount;
}

/**
 * 项目 API key 对象。
 *
 * API：`/v1/organization/projects/{project_id}/api_keys`。
 * 说明：管理员可列出、查看、删除项目内用户创建的 API key；不能代用户创建 key。
 */
export interface OrganizationProjectApiKey {
  /** 对象类型。API：Project API keys。说明：固定为 `organization.project.api_key`。 */
  object: 'organization.project.api_key' | string;
  /** 脱敏 key 值。API：Project API keys。说明：例如 `sk-abc...def`，不能用于请求鉴权。 */
  redacted_value: string;
  /** API key 名称。API：Project API keys。说明：用户设置的 key 名称。 */
  name: string;
  /** 创建时间。API：Project API keys。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 最后使用时间。API：Project API keys。说明：从未使用或服务端未返回时可能为空。 */
  last_used_at?: number | null;
  /** API key ID。API：Project API keys。说明：retrieve/delete 使用该 ID。 */
  id: string;
  /** 所有者。API：Project API keys。说明：用户或 service account。 */
  owner: OrganizationProjectApiKeyOwner;
}

/**
 * 项目 API key 列表参数。
 *
 * API：`GET /v1/organization/projects/{project_id}/api_keys`。
 * 说明：分页读取项目内 API keys。
 */
export interface OrganizationProjectApiKeyListParams {
  /** 下一页游标。API：List project API keys。说明：传入上一页最后一个 key ID。 */
  after?: string;
  /** 返回数量上限。API：List project API keys。说明：官方默认 20。 */
  limit?: number;
}

/** 项目 API key 列表响应。API：List project API keys。说明：列表元素为 API key 对象。 */
export type OrganizationProjectApiKeyListResponse = OpenAIListResponse<OrganizationProjectApiKey>;

/**
 * 删除项目 API key 响应。
 *
 * API：`DELETE /v1/organization/projects/{project_id}/api_keys/{key_id}`。
 * 说明：删除用户 API key；service account key 可能由服务端拒绝。
 */
export interface OrganizationProjectApiKeyDeleted {
  /** 对象类型。API：Delete project API key。说明：通常为 `organization.project.api_key.deleted`。 */
  object: 'organization.project.api_key.deleted' | string;
  /** API key ID。API：Delete project API key。说明：被删除的 key。 */
  id: string;
  /** 删除状态。API：Delete project API key。说明：`true` 表示已删除。 */
  deleted: boolean;
}

/**
 * 项目模型限流对象。
 *
 * API：`/v1/organization/projects/{project_id}/rate_limits`。
 * 说明：某个项目下某个模型的速率限制配置。
 */
export interface OrganizationProjectRateLimit {
  /** 对象类型。API：Project rate limits。说明：固定为 `project.rate_limit`。 */
  object: 'project.rate_limit' | string;
  /** Rate limit ID。API：Project rate limits。说明：更新限流配置时使用。 */
  id: string;
  /** 模型 ID。API：Project rate limits。说明：该限流配置适用的模型。 */
  model: string;
  /** 每分钟最大请求数。API：Project rate limits。说明：RPM 限制。 */
  max_requests_per_1_minute?: number;
  /** 每分钟最大 token 数。API：Project rate limits。说明：TPM 限制。 */
  max_tokens_per_1_minute?: number;
  /** 每分钟最大图片数。API：Project rate limits。说明：IPM 限制。 */
  max_images_per_1_minute?: number;
  /** 每天最大请求数。API：Project rate limits。说明：RPD 限制。 */
  max_requests_per_1_day?: number;
  /** 每分钟最大音频 MB。API：Project rate limits。说明：音频模型相关限制。 */
  max_audio_megabytes_per_1_minute?: number;
  /** Batch 每天最大输入 token。API：Project rate limits。说明：batch 队列相关限制。 */
  batch_1_day_max_input_tokens?: number;
}

/**
 * 更新项目模型限流参数。
 *
 * API：`POST /v1/organization/projects/{project_id}/rate_limits/{rate_limit_id}`。
 * 说明：只传要修改的限流字段。
 */
export interface OrganizationProjectRateLimitUpdateParams {
  /** Batch 每天最大输入 token。API：Modify project rate limit。说明：仅部分模型适用。 */
  batch_1_day_max_input_tokens?: number;
  /** 每分钟最大音频 MB。API：Modify project rate limit。说明：仅音频模型适用。 */
  max_audio_megabytes_per_1_minute?: number;
  /** 每分钟最大图片数。API：Modify project rate limit。说明：仅图像模型适用。 */
  max_images_per_1_minute?: number;
  /** 每天最大请求数。API：Modify project rate limit。说明：仅部分模型适用。 */
  max_requests_per_1_day?: number;
  /** 每分钟最大请求数。API：Modify project rate limit。说明：RPM 限制。 */
  max_requests_per_1_minute?: number;
  /** 每分钟最大 token 数。API：Modify project rate limit。说明：TPM 限制。 */
  max_tokens_per_1_minute?: number;
}

/**
 * 项目模型限流列表参数。
 *
 * API：`GET /v1/organization/projects/{project_id}/rate_limits`。
 * 说明：分页读取项目按模型配置的限流。
 */
export interface OrganizationProjectRateLimitListParams {
  /** 下一页游标。API：List project rate limits。说明：传入上一页最后一个 rate limit ID。 */
  after?: string;
  /** 上一页游标。API：List project rate limits。说明：传入当前页第一项 ID。 */
  before?: string;
  /** 返回数量上限。API：List project rate limits。说明：官方默认 100。 */
  limit?: number;
}

/** 项目模型限流列表响应。API：List project rate limits。说明：列表元素为 rate limit 对象。 */
export type OrganizationProjectRateLimitListResponse = OpenAIListResponse<OrganizationProjectRateLimit>;

/**
 * 组织 group 对象。
 *
 * API：`/v1/organization/groups`。
 * 说明：组织级用户集合，可授权到项目或用于访问控制。
 */
export interface OrganizationGroup {
  /** 对象类型。API：Organization groups。说明：固定为 `group`。 */
  object: 'group' | string;
  /** Group ID。API：Organization groups。说明：更新、删除和成员管理使用该 ID。 */
  id: string;
  /** Group 名称。API：Organization groups。说明：人类可读展示名称。 */
  name: string;
  /** 创建时间。API：Organization groups。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 是否 SCIM 托管。API：Organization groups。说明：SCIM 托管 group 可能不允许手工修改。 */
  is_scim_managed?: boolean;
  /** 是否 SCIM 托管。API：Organization groups。说明：部分响应使用 `scim_managed` 字段名。 */
  scim_managed?: boolean;
}

/** 创建组织 group 参数。API：`POST /v1/organization/groups`。说明：创建一个组织内可复用 group。 */
export interface OrganizationGroupCreateParams {
  /** Group 名称。API：Create group。说明：人类可读展示名称。 */
  name: string;
}

/** 更新组织 group 参数。API：`POST /v1/organization/groups/{group_id}`。说明：修改 group 展示名称。 */
export interface OrganizationGroupUpdateParams {
  /** 新名称。API：Update group。说明：更新后的展示名称。 */
  name: string;
}

/**
 * 组织 group 列表参数。
 *
 * API：`GET /v1/organization/groups`。
 * 说明：分页读取组织内 groups。
 */
export interface OrganizationGroupListParams {
  /** 下一页游标。API：List groups。说明：传入上一页最后一个 group ID。 */
  after?: string;
  /** 返回数量上限。API：List groups。说明：官方默认 100。 */
  limit?: number;
  /** 排序方向。API：List groups。说明：`asc` 或 `desc`。 */
  order?: 'asc' | 'desc';
}

/** 组织 group 列表响应。API：List groups。说明：列表元素为 organization group。 */
export type OrganizationGroupListResponse = OpenAIListResponse<OrganizationGroup>;

/**
 * 删除组织 group 响应。
 *
 * API：`DELETE /v1/organization/groups/{group_id}`。
 * 说明：删除组织 group。
 */
export interface OrganizationGroupDeleted {
  /** 对象类型。API：Delete group。说明：通常为 `group.deleted`。 */
  object: 'group.deleted' | string;
  /** Group ID。API：Delete group。说明：被删除的 group。 */
  id: string;
  /** 删除状态。API：Delete group。说明：`true` 表示已删除。 */
  deleted: boolean;
}

/**
 * 组织用户对象。
 *
 * API：Group users、Organization users。
 * 说明：表示组织成员基础信息。
 */
export interface OrganizationUser {
  /** 对象类型。API：Organization users。说明：通常为 `organization.user`。 */
  object: 'organization.user' | string;
  /** 用户 ID。API：Organization users。说明：组织用户标识。 */
  id: string;
  /** 用户姓名。API：Organization users。说明：展示名称。 */
  name?: string;
  /** 用户邮箱。API：Organization users。说明：登录邮箱。 */
  email: string;
  /** 组织角色。API：Organization users。说明：例如 `owner`、`reader`。 */
  role?: string;
  /** 加入时间。API：Organization users。说明：Unix 秒级时间戳。 */
  added_at?: number;
}

/** 组织用户列表参数。API：`GET /v1/organization/users`。说明：分页读取组织用户。 */
export interface OrganizationUserListParams {
  /** 下一页游标。API：List users。说明：传入上一页最后一个 user ID。 */
  after?: string;
  /** 返回数量上限。API：List users。说明：官方默认 20。 */
  limit?: number;
}

/** 组织用户列表响应。API：List users。说明：列表元素为 organization user。 */
export type OrganizationUserListResponse = OpenAIListResponse<OrganizationUser>;

/** 更新组织用户参数。API：`POST /v1/organization/users/{user_id}`。说明：修改用户组织角色。 */
export interface OrganizationUserUpdateParams {
  /** 组织角色。API：Modify user。说明：官方支持 `owner` 或 `reader`。 */
  role: 'owner' | 'reader' | string;
}

/**
 * 删除组织用户响应。
 *
 * API：`DELETE /v1/organization/users/{user_id}`。
 * 说明：从组织移除用户。
 */
export interface OrganizationUserDeleted {
  /** 对象类型。API：Delete user。说明：通常为 `organization.user.deleted`。 */
  object: 'organization.user.deleted' | string;
  /** 用户 ID。API：Delete user。说明：被移除的组织用户。 */
  id: string;
  /** 删除状态。API：Delete user。说明：`true` 表示已移除。 */
  deleted: boolean;
}

/**
 * 邀请附带项目授权。
 *
 * API：Create invite。
 * 说明：用户接受组织邀请时，同时加入这些项目。
 */
export interface OrganizationInviteProject {
  /** 项目 ID。API：Create invite。说明：要加入的项目 ID。 */
  id: string;
  /** 项目角色。API：Create invite。说明：例如 `member` 或 `owner`。 */
  role: OrganizationProjectRole;
}

/**
 * 组织邀请状态。
 *
 * API：Organization Invites。
 * 说明：邀请生命周期状态，以服务端返回为准。
 */
export type OrganizationInviteStatus = 'pending' | 'accepted' | 'expired' | string;

/**
 * 组织邀请对象。
 *
 * API：`/v1/organization/invites`。
 * 说明：邀请邮箱加入组织，接受前可删除。
 */
export interface OrganizationInvite {
  /** 对象类型。API：Organization invites。说明：固定为 `organization.invite`。 */
  object: 'organization.invite' | string;
  /** Invite ID。API：Organization invites。说明：retrieve/delete 使用该 ID。 */
  id: string;
  /** 被邀请邮箱。API：Organization invites。说明：邀请邮件发送地址。 */
  email: string;
  /** 组织角色。API：Organization invites。说明：官方支持 `owner` 或 `reader`。 */
  role: 'owner' | 'reader' | string;
  /** 邀请状态。API：Organization invites。说明：例如 `pending`、`accepted`。 */
  status: OrganizationInviteStatus;
  /** 发起邀请时间。API：Organization invites。说明：Unix 秒级时间戳。 */
  invited_at: number;
  /** 邀请过期时间。API：Organization invites。说明：Unix 秒级时间戳。 */
  expires_at: number;
  /** 接受时间。API：Organization invites。说明：未接受时为 `null`。 */
  accepted_at: number | null;
  /** 接受邀请后加入的项目。API：Organization invites。说明：创建邀请时可设置。 */
  projects?: Array<OrganizationInviteProject>;
}

/**
 * 创建组织邀请参数。
 *
 * API：`POST /v1/organization/invites`。
 * 说明：向邮箱发送组织邀请，可同时设置项目成员身份。
 */
export interface OrganizationInviteCreateParams {
  /** 被邀请邮箱。API：Create invite。说明：邀请邮件发送地址。 */
  email: string;
  /** 组织角色。API：Create invite。说明：官方支持 `owner` 或 `reader`。 */
  role: 'owner' | 'reader' | string;
  /** 项目授权。API：Create invite。说明：接受邀请后加入这些项目；省略时加入默认项目。 */
  projects?: Array<OrganizationInviteProject>;
}

/** 组织邀请列表参数。API：`GET /v1/organization/invites`。说明：分页读取组织邀请。 */
export interface OrganizationInviteListParams {
  /** 下一页游标。API：List invites。说明：传入上一页最后一个 invite ID。 */
  after?: string;
  /** 返回数量上限。API：List invites。说明：官方默认 20。 */
  limit?: number;
}

/** 组织邀请列表响应。API：List invites。说明：列表元素为 organization invite。 */
export type OrganizationInviteListResponse = OpenAIListResponse<OrganizationInvite>;

/**
 * 删除组织邀请响应。
 *
 * API：`DELETE /v1/organization/invites/{invite_id}`。
 * 说明：删除未接受的邀请；已接受邀请服务端会拒绝。
 */
export interface OrganizationInviteDeleted {
  /** 对象类型。API：Delete invite。说明：通常为 `organization.invite.deleted`。 */
  object: 'organization.invite.deleted' | string;
  /** Invite ID。API：Delete invite。说明：被删除的邀请。 */
  id: string;
  /** 删除状态。API：Delete invite。说明：`true` 表示已删除。 */
  deleted: boolean;
}

/**
 * Admin API key owner。
 *
 * API：Admin API Keys。
 * 说明：当前 admin key owner 通常为组织 owner 用户。
 */
export interface OrganizationAdminApiKeyOwner {
  /** Owner 类型。API：Admin API Keys。说明：通常为 `user`。 */
  type?: string;
  /** 对象类型。API：Admin API Keys。说明：通常为 `organization.user`。 */
  object?: string;
  /** 用户 ID。API：Admin API Keys。说明：owner 用户 ID。 */
  id?: string;
  /** 用户姓名。API：Admin API Keys。说明：owner 展示名称。 */
  name?: string;
  /** 创建时间。API：Admin API Keys。说明：Unix 秒级时间戳。 */
  created_at?: number;
  /** 用户角色。API：Admin API Keys。说明：通常为 `owner`。 */
  role?: string;
}

/**
 * Admin API key 对象。
 *
 * API：`/v1/organization/admin_api_keys`。
 * 说明：组织级 admin key，可用于调用 Admin API；创建时才返回未脱敏 `value`。
 */
export interface OrganizationAdminApiKey {
  /** 对象类型。API：Admin API Keys。说明：固定为 `organization.admin_api_key`。 */
  object: 'organization.admin_api_key' | string;
  /** Admin key ID。API：Admin API Keys。说明：retrieve/delete 使用该 ID。 */
  id: string;
  /** Key 名称。API：Admin API Keys。说明：便于识别用途。 */
  name?: string;
  /** 脱敏 key 值。API：Admin API Keys。说明：例如 `sk-admin...xyz`。 */
  redacted_value: string;
  /** 未脱敏 key 值。API：Create admin API key。说明：仅创建响应出现一次。 */
  value?: string;
  /** 创建时间。API：Admin API Keys。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 最后使用时间。API：Admin API Keys。说明：未使用或未返回时为空。 */
  last_used_at?: number | null;
  /** Owner。API：Admin API Keys。说明：创建或拥有该 key 的组织 owner。 */
  owner: OrganizationAdminApiKeyOwner;
}

/**
 * 创建 Admin API key 参数。
 *
 * API：`POST /v1/organization/admin_api_keys`。
 * 说明：创建组织 admin key；未脱敏 value 只在创建响应返回一次。
 */
export interface OrganizationAdminApiKeyCreateParams {
  /** Key 名称。API：Create admin API key。说明：便于管理后台识别。 */
  name: string;
}

/** Admin API key 列表参数。API：`GET /v1/organization/admin_api_keys`。说明：分页读取 admin keys。 */
export interface OrganizationAdminApiKeyListParams {
  /** 下一页游标。API：List admin API keys。说明：传入上一页最后一个 key ID。 */
  after?: string;
  /** 返回数量上限。API：List admin API keys。说明：服务端默认值由官方决定。 */
  limit?: number;
}

/** Admin API key 列表响应。API：List admin API keys。说明：列表元素为 admin key。 */
export type OrganizationAdminApiKeyListResponse = OpenAIListResponse<OrganizationAdminApiKey>;

/**
 * 删除 Admin API key 响应。
 *
 * API：`DELETE /v1/organization/admin_api_keys/{key_id}`。
 * 说明：删除指定 admin key。
 */
export interface OrganizationAdminApiKeyDeleted {
  /** 对象类型。API：Delete admin API key。说明：固定为 `organization.admin_api_key.deleted`。 */
  object: 'organization.admin_api_key.deleted' | string;
  /** Admin key ID。API：Delete admin API key。说明：被删除的 key。 */
  id: string;
  /** 删除状态。API：Delete admin API key。说明：`true` 表示已删除。 */
  deleted: boolean;
}

/**
 * 管理角色对象。
 *
 * API：Organization Roles、Project Roles。
 * 说明：自定义角色可授予 organization 或 project 级权限。
 */
export interface OrganizationRole {
  /** 对象类型。API：Roles。说明：固定为 `role`。 */
  object: 'role' | string;
  /** Role ID。API：Roles。说明：update/delete 使用该 ID。 */
  id: string;
  /** Role 名称。API：Roles。说明：唯一的自定义角色名称。 */
  name: string;
  /** Role 描述。API：Roles。说明：解释角色用途。 */
  description?: string;
  /** 权限列表。API：Roles。说明：该角色授予的 permission 字符串。 */
  permissions: Array<string>;
  /** 资源类型。API：Roles。说明：例如 `api.organization` 或 `api.project`。 */
  resource_type: string;
  /** 是否预置角色。API：Roles。说明：OpenAI 管理的预置角色不能作为普通自定义角色修改。 */
  predefined_role: boolean;
}

/**
 * 创建 role 参数。
 *
 * API：Create organization role、Create project role。
 * 说明：创建 organization 或 project 级自定义角色。
 */
export interface OrganizationRoleCreateParams {
  /** Role 名称。API：Create role。说明：唯一名称。 */
  role_name: string;
  /** 权限列表。API：Create role。说明：要授予的 permission 字符串。 */
  permissions: Array<string>;
  /** Role 描述。API：Create role。说明：可选说明。 */
  description?: string;
}

/**
 * 更新 role 参数。
 *
 * API：Update organization role、Update project role。
 * 说明：仅传需要修改的字段。
 */
export interface OrganizationRoleUpdateParams {
  /** 新 role 名称。API：Update role。说明：可选修改。 */
  role_name?: string;
  /** 新权限列表。API：Update role。说明：可选修改。 */
  permissions?: Array<string>;
  /** 新描述。API：Update role。说明：可选修改。 */
  description?: string;
}

/**
 * Role 列表参数。
 *
 * API：List organization roles、List project roles。
 * 说明：分页读取自定义和预置角色。
 */
export interface OrganizationRoleListParams {
  /** 下一页游标。API：List roles。说明：传入上一页 `next` 或最后 role ID。 */
  after?: string;
  /** 返回数量上限。API：List roles。说明：官方默认 1000。 */
  limit?: number;
  /** 排序方向。API：List roles。说明：`asc` 或 `desc`。 */
  order?: 'asc' | 'desc';
}

/** Role 列表响应。API：List roles。说明：列表元素为 role。 */
export type OrganizationRoleListResponse = OpenAIListResponse<OrganizationRole>;

/**
 * 删除 role 响应。
 *
 * API：Delete organization role、Delete project role。
 * 说明：删除自定义角色。
 */
export interface OrganizationRoleDeleted {
  /** 对象类型。API：Delete role。说明：通常为 `role.deleted`。 */
  object: 'role.deleted' | string;
  /** Role ID。API：Delete role。说明：被删除的 role。 */
  id: string;
  /** 删除状态。API：Delete role。说明：`true` 表示已删除。 */
  deleted: boolean;
}

/**
 * Audit log 时间范围过滤。
 *
 * API：List audit logs。
 * 说明：按 `effective_at` Unix 秒级时间过滤。
 */
export interface OrganizationAuditLogEffectiveAtFilter {
  /** 大于。API：List audit logs。说明：仅返回 effective_at > gt 的事件。 */
  gt?: number;
  /** 大于等于。API：List audit logs。说明：仅返回 effective_at >= gte 的事件。 */
  gte?: number;
  /** 小于。API：List audit logs。说明：仅返回 effective_at < lt 的事件。 */
  lt?: number;
  /** 小于等于。API：List audit logs。说明：仅返回 effective_at <= lte 的事件。 */
  lte?: number;
}

/**
 * Audit log actor。
 *
 * API：Audit logs。
 * 说明：表示触发审计事件的 session 或 API key。
 */
export interface OrganizationAuditLogActor {
  /** Actor 类型。API：Audit logs。说明：`session` 或 `api_key`。 */
  type: 'session' | 'api_key' | string;
  /** Session 信息。API：Audit logs。说明：当 actor 来自用户 session 时存在。 */
  session?: JsonObject;
  /** API key 信息。API：Audit logs。说明：当 actor 来自 API key 时存在。 */
  api_key?: JsonObject;
}

/**
 * Audit log project 摘要。
 *
 * API：Audit logs。
 * 说明：事件关联项目；非项目作用域事件可能不存在。
 */
export interface OrganizationAuditLogProject {
  /** 项目 ID。API：Audit logs。说明：事件关联项目 ID。 */
  id: string;
  /** 项目名称。API：Audit logs。说明：事件关联项目名称。 */
  name?: string;
}

/**
 * Audit log 对象。
 *
 * API：`GET /v1/organization/audit_logs`。
 * 说明：组织内用户动作或配置变更日志；事件详情字段按 `type` 以服务端原始 JSON 返回。
 */
export interface OrganizationAuditLog {
  /** 日志 ID。API：Audit logs。说明：审计日志唯一 ID。 */
  id: string;
  /** 事件类型。API：Audit logs。说明：例如 `api_key.created`、`project.updated`。 */
  type: string;
  /** 生效时间。API：Audit logs。说明：Unix 秒级时间戳。 */
  effective_at: number;
  /** Actor。API：Audit logs。说明：触发事件的用户 session 或 API key。 */
  actor: OrganizationAuditLogActor;
  /** Project。API：Audit logs。说明：项目作用域事件关联项目。 */
  project?: OrganizationAuditLogProject;
}

/**
 * Audit logs 列表参数。
 *
 * API：`GET /v1/organization/audit_logs`。
 * 说明：支持按 actor、event type、project、resource 和时间范围过滤。
 */
export interface OrganizationAuditLogListParams {
  /** actor 邮箱列表。API：List audit logs。说明：只返回这些邮箱触发的事件。 */
  actor_emails?: Array<string>;
  /** actor ID 列表。API：List audit logs。说明：用户、service account 或 key tracking ID。 */
  actor_ids?: Array<string>;
  /** 下一页游标。API：List audit logs。说明：传入上一页最后一个日志 ID。 */
  after?: string;
  /** 上一页游标。API：List audit logs。说明：传入当前页第一项日志 ID。 */
  before?: string;
  /** 时间范围。API：List audit logs。说明：按 effective_at 过滤。 */
  effective_at?: OrganizationAuditLogEffectiveAtFilter;
  /** 事件类型列表。API：List audit logs。说明：例如 `project.created`。 */
  event_types?: Array<string>;
  /** 返回数量上限。API：List audit logs。说明：官方默认 20。 */
  limit?: number;
  /** 项目 ID 列表。API：List audit logs。说明：只返回这些项目相关事件。 */
  project_ids?: Array<string>;
  /** 资源 ID 列表。API：List audit logs。说明：只返回这些目标资源相关事件。 */
  resource_ids?: Array<string>;
}

/** Audit logs 列表响应。API：List audit logs。说明：列表元素为 audit log。 */
export type OrganizationAuditLogListResponse = OpenAIListResponse<OrganizationAuditLog>;

/** 证书有效期详情。API：Certificates。说明：证书有效起止时间。 */
export interface OrganizationCertificateDetails {
  /** 生效时间。API：Certificates。说明：Unix 秒级时间戳。 */
  valid_at: number;
  /** 过期时间。API：Certificates。说明：Unix 秒级时间戳。 */
  expires_at: number;
}

/**
 * mTLS 证书对象。
 *
 * API：Organization Certificates、Project Certificates。
 * 说明：可在组织或项目级激活/停用的 mTLS 证书。
 */
export interface OrganizationCertificate {
  /** 对象类型。API：Certificates。说明：例如 `organization.certificate` 或 `organization.project.certificate`。 */
  object: 'organization.certificate' | 'organization.project.certificate' | string;
  /** 证书 ID。API：Certificates。说明：retrieve/update/delete/activate 使用。 */
  id: string;
  /** 证书名称。API：Certificates。说明：人类可读名称。 */
  name?: string;
  /** 是否激活。API：Certificates。说明：当前 scope 下是否 active。 */
  active: boolean;
  /** 创建时间。API：Certificates。说明：Unix 秒级时间戳。 */
  created_at: number;
  /** 证书有效期详情。API：Certificates。说明：包含 valid_at 和 expires_at。 */
  certificate_details: OrganizationCertificateDetails;
}

/** 上传证书参数。API：`POST /v1/organization/certificates`。说明：上传 PEM 证书，不自动激活。 */
export interface OrganizationCertificateCreateParams {
  /** 证书名称。API：Upload certificate。说明：可选展示名称。 */
  name?: string;
  /** PEM 证书内容。API：Upload certificate。说明：官方示例字段名为 `certificate`。 */
  certificate: string;
}

/** 更新证书参数。API：`POST /v1/organization/certificates/{certificate_id}`。说明：只能更新名称。 */
export interface OrganizationCertificateUpdateParams {
  /** 新证书名称。API：Modify certificate。说明：更新后的展示名称。 */
  name: string;
}

/** 证书列表参数。API：List organization/project certificates。说明：分页读取证书。 */
export interface OrganizationCertificateListParams {
  /** 下一页游标。API：List certificates。说明：传入上一页最后一个 cert ID。 */
  after?: string;
  /** 返回数量上限。API：List certificates。说明：服务端默认值由官方决定。 */
  limit?: number;
}

/** 证书列表响应。API：List certificates。说明：列表元素为证书对象。 */
export type OrganizationCertificateListResponse = OpenAIListResponse<OrganizationCertificate>;

/** 证书激活/停用参数。API：Activate/Deactivate certificates。说明：一次最多 10 个证书 ID。 */
export interface OrganizationCertificateToggleParams {
  /** 证书 ID 列表。API：Activate/Deactivate certificates。说明：要激活或停用的证书。 */
  certificate_ids: Array<string>;
}

/**
 * 证书激活/停用响应。
 *
 * API：Activate/Deactivate certificates。
 * 说明：返回被激活或停用后的证书对象列表。
 */
export interface OrganizationCertificateActivationResponse {
  /** 对象类型。API：Activate/Deactivate certificates。说明：随 scope 和动作变化。 */
  object: string;
  /** 证书列表。API：Activate/Deactivate certificates。说明：操作后的证书对象。 */
  data: Array<OrganizationCertificate>;
}

/** 删除证书响应。API：`DELETE /v1/organization/certificates/{certificate_id}`。说明：删除 inactive 证书。 */
export interface OrganizationCertificateDeleted {
  /** 对象类型。API：Delete certificate。说明：通常为 `certificate.deleted`。 */
  object: 'certificate.deleted' | string;
  /** 证书 ID。API：Delete certificate。说明：被删除的证书。 */
  id: string;
}

/** Group user 对象。API：`POST /v1/organization/groups/{group_id}/users`。说明：添加成员后返回确认 payload。 */
export interface OrganizationGroupUser {
  /** 对象类型。API：Add group user。说明：固定为 `group.user`。 */
  object: 'group.user' | string;
  /** 用户 ID。API：Add group user。说明：被加入 group 的用户。 */
  user_id: string;
  /** Group ID。API：Add group user。说明：用户加入的 group。 */
  group_id: string;
}

/** 添加 group 用户参数。API：`POST /v1/organization/groups/{group_id}/users`。说明：把组织用户加入 group。 */
export interface OrganizationGroupUserCreateParams {
  /** 用户 ID。API：Add group user。说明：要加入 group 的组织用户 ID。 */
  user_id: string;
}

/**
 * Group users 列表参数。
 *
 * API：`GET /v1/organization/groups/{group_id}/users`。
 * 说明：分页读取 group 内用户。
 */
export interface OrganizationGroupUserListParams {
  /** 下一页游标。API：List group users。说明：传入上一页最后一个 user ID。 */
  after?: string;
  /** 返回数量上限。API：List group users。说明：官方默认 100。 */
  limit?: number;
  /** 排序方向。API：List group users。说明：`asc` 或 `desc`。 */
  order?: 'asc' | 'desc';
}

/** Group users 列表响应。API：List group users。说明：列表元素为组织用户对象。 */
export type OrganizationGroupUserListResponse = OpenAIListResponse<OrganizationUser>;

/**
 * 删除 group 用户响应。
 *
 * API：`DELETE /v1/organization/groups/{group_id}/users/{user_id}`。
 * 说明：把用户从 group 移除。
 */
export interface OrganizationGroupUserDeleted {
  /** 对象类型。API：Remove group user。说明：通常为 `group.user.deleted`。 */
  object: 'group.user.deleted' | string;
  /** 删除状态。API：Remove group user。说明：`true` 表示已移除。 */
  deleted: boolean;
}
