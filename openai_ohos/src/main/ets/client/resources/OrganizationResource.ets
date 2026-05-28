import type {
  OrganizationAdminApiKey,
  OrganizationAdminApiKeyCreateParams,
  OrganizationAdminApiKeyDeleted,
  OrganizationAdminApiKeyListParams,
  OrganizationAdminApiKeyListResponse,
  OrganizationAuditLogListParams,
  OrganizationAuditLogListResponse,
  OrganizationCertificate,
  OrganizationCertificateActivationResponse,
  OrganizationCertificateCreateParams,
  OrganizationCertificateDeleted,
  OrganizationCertificateListParams,
  OrganizationCertificateListResponse,
  OrganizationCertificateToggleParams,
  OrganizationCertificateUpdateParams,
  OrganizationGroup,
  OrganizationGroupCreateParams,
  OrganizationGroupDeleted,
  OrganizationGroupListParams,
  OrganizationGroupListResponse,
  OrganizationGroupUpdateParams,
  OrganizationGroupUser,
  OrganizationGroupUserCreateParams,
  OrganizationGroupUserDeleted,
  OrganizationGroupUserListParams,
  OrganizationGroupUserListResponse,
  OrganizationInvite,
  OrganizationInviteCreateParams,
  OrganizationInviteDeleted,
  OrganizationInviteListParams,
  OrganizationInviteListResponse,
  OrganizationProject,
  OrganizationProjectApiKey,
  OrganizationProjectApiKeyDeleted,
  OrganizationProjectApiKeyListParams,
  OrganizationProjectApiKeyListResponse,
  OrganizationProjectCreateParams,
  OrganizationProjectGroup,
  OrganizationProjectGroupCreateParams,
  OrganizationProjectGroupDeleted,
  OrganizationProjectGroupListParams,
  OrganizationProjectGroupListResponse,
  OrganizationProjectListParams,
  OrganizationProjectRateLimit,
  OrganizationProjectRateLimitListParams,
  OrganizationProjectRateLimitListResponse,
  OrganizationProjectRateLimitUpdateParams,
  OrganizationProjectServiceAccount,
  OrganizationProjectServiceAccountCreateParams,
  OrganizationProjectServiceAccountDeleted,
  OrganizationProjectServiceAccountListParams,
  OrganizationProjectServiceAccountListResponse,
  OrganizationProjectUser,
  OrganizationProjectUserCreateParams,
  OrganizationProjectUserDeleted,
  OrganizationProjectUserListParams,
  OrganizationProjectUserListResponse,
  OrganizationProjectUserUpdateParams,
  OrganizationProjectListResponse,
  OrganizationProjectUpdateParams,
  OrganizationRole,
  OrganizationRoleCreateParams,
  OrganizationRoleDeleted,
  OrganizationRoleListParams,
  OrganizationRoleListResponse,
  OrganizationRoleUpdateParams,
  OrganizationUser,
  OrganizationUserDeleted,
  OrganizationUserListParams,
  OrganizationUserListResponse,
  OrganizationUserUpdateParams,
} from '../../models/Organization';
import { OpenAIRequestClient } from '../core/OpenAIRequestClient';
import { appendStringArrayQuery, appendStringQuery, buildPathWithQuery } from '../core/RequestUtils';

/**
 * Organization 资源入口。
 *
 * API：`/v1/organization/*`。
 * 说明：组织管理 API，通常需要 admin API key。
 */
export interface OpenAIOrganizationResource {
  /**
   * Projects 子资源。
   *
   * API：Organization Projects。
   * 说明：管理组织内 API Projects。
   */
  projects: OpenAIOrganizationProjectsResource;

  /**
   * Groups 子资源。
   *
   * API：Organization Groups。
   * 说明：管理组织内可复用用户组及其成员。
   */
  groups: OpenAIOrganizationGroupsResource;

  /**
   * Users 子资源。
   *
   * API：Organization Users。
   * 说明：管理组织用户及其组织角色。
   */
  users: OpenAIOrganizationUsersResource;

  /**
   * Invites 子资源。
   *
   * API：Organization Invites。
   * 说明：创建、读取、删除组织邀请。
   */
  invites: OpenAIOrganizationInvitesResource;

  /**
   * Admin API keys 子资源。
   *
   * API：Admin API Keys。
   * 说明：管理组织级 admin key。
   */
  adminApiKeys: OpenAIOrganizationAdminApiKeysResource;

  /**
   * Roles 子资源。
   *
   * API：Organization Roles。
   * 说明：管理组织级自定义角色。
   */
  roles: OpenAIOrganizationRolesResource;

  /**
   * Audit logs 子资源。
   *
   * API：Organization Audit Logs。
   * 说明：读取组织审计日志。
   */
  auditLogs: OpenAIOrganizationAuditLogsResource;

  /**
   * Certificates 子资源。
   *
   * API：Organization Certificates。
   * 说明：管理组织级 mTLS 证书。
   */
  certificates: OpenAIOrganizationCertificatesResource;
}

/** Organization certificates 子资源。API：`/v1/organization/certificates`。说明：管理组织级 mTLS 证书。 */
export interface OpenAIOrganizationCertificatesResource {
  /** 列出证书。API：List organization certificates。说明：分页读取组织证书。 */
  list(params?: OrganizationCertificateListParams): Promise<OrganizationCertificateListResponse>;
  /** 上传证书。API：Upload certificate。说明：上传 PEM 证书。 */
  create(params: OrganizationCertificateCreateParams): Promise<OrganizationCertificate>;
  /** 获取证书。API：Retrieve certificate。说明：读取单个证书。 */
  retrieve(certificateID: string): Promise<OrganizationCertificate>;
  /** 更新证书。API：Modify certificate。说明：修改证书名称。 */
  update(certificateID: string, params: OrganizationCertificateUpdateParams): Promise<OrganizationCertificate>;
  /** 删除证书。API：Delete certificate。说明：删除 inactive 证书。 */
  delete(certificateID: string): Promise<OrganizationCertificateDeleted>;
  /** 激活证书。API：Activate certificates for organization。说明：组织级激活证书。 */
  activate(params: OrganizationCertificateToggleParams): Promise<OrganizationCertificateActivationResponse>;
  /** 停用证书。API：Deactivate certificates for organization。说明：组织级停用证书。 */
  deactivate(params: OrganizationCertificateToggleParams): Promise<OrganizationCertificateActivationResponse>;
}

/** Audit logs 子资源。API：`/v1/organization/audit_logs`。说明：读取组织安全审计日志。 */
export interface OpenAIOrganizationAuditLogsResource {
  /** 列出 audit logs。API：List audit logs。说明：支持 actor、event、project、resource 和时间过滤。 */
  list(params?: OrganizationAuditLogListParams): Promise<OrganizationAuditLogListResponse>;
}

/** Organization roles 子资源。API：`/v1/organization/roles`。说明：管理组织级角色。 */
export interface OpenAIOrganizationRolesResource {
  /** 列出 roles。API：List organization roles。说明：分页读取组织角色。 */
  list(params?: OrganizationRoleListParams): Promise<OrganizationRoleListResponse>;
  /** 创建 role。API：Create organization role。说明：创建组织级自定义角色。 */
  create(params: OrganizationRoleCreateParams): Promise<OrganizationRole>;
  /** 更新 role。API：Update organization role。说明：修改组织级自定义角色。 */
  update(roleID: string, params: OrganizationRoleUpdateParams): Promise<OrganizationRole>;
  /** 删除 role。API：Delete organization role。说明：删除组织级自定义角色。 */
  delete(roleID: string): Promise<OrganizationRoleDeleted>;
}

/** Admin API keys 子资源。API：`/v1/organization/admin_api_keys`。说明：管理组织 admin keys。 */
export interface OpenAIOrganizationAdminApiKeysResource {
  /** 列出 admin keys。API：List admin API keys。说明：分页读取组织 admin keys。 */
  list(params?: OrganizationAdminApiKeyListParams): Promise<OrganizationAdminApiKeyListResponse>;
  /** 创建 admin key。API：Create admin API key。说明：返回一次性未脱敏 value。 */
  create(params: OrganizationAdminApiKeyCreateParams): Promise<OrganizationAdminApiKey>;
  /** 获取 admin key。API：Retrieve admin API key。说明：读取 key 元数据。 */
  retrieve(keyID: string): Promise<OrganizationAdminApiKey>;
  /** 删除 admin key。API：Delete admin API key。说明：删除指定 admin key。 */
  delete(keyID: string): Promise<OrganizationAdminApiKeyDeleted>;
}

/** Organization users 子资源。API：`/v1/organization/users`。说明：管理组织用户。 */
export interface OpenAIOrganizationUsersResource {
  /** 列出组织用户。API：List users。说明：分页读取组织用户。 */
  list(params?: OrganizationUserListParams): Promise<OrganizationUserListResponse>;
  /** 获取组织用户。API：Retrieve user。说明：读取单个用户详情。 */
  retrieve(userID: string): Promise<OrganizationUser>;
  /** 更新组织用户。API：Modify user。说明：修改组织角色。 */
  update(userID: string, params: OrganizationUserUpdateParams): Promise<OrganizationUser>;
  /** 删除组织用户。API：Delete user。说明：从组织移除用户。 */
  delete(userID: string): Promise<OrganizationUserDeleted>;
}

/** Organization invites 子资源。API：`/v1/organization/invites`。说明：管理组织邀请。 */
export interface OpenAIOrganizationInvitesResource {
  /** 列出邀请。API：List invites。说明：分页读取组织邀请。 */
  list(params?: OrganizationInviteListParams): Promise<OrganizationInviteListResponse>;
  /** 创建邀请。API：Create invite。说明：邀请邮箱加入组织。 */
  create(params: OrganizationInviteCreateParams): Promise<OrganizationInvite>;
  /** 获取邀请。API：Retrieve invite。说明：读取单个邀请。 */
  retrieve(inviteID: string): Promise<OrganizationInvite>;
  /** 删除邀请。API：Delete invite。说明：删除未接受邀请。 */
  delete(inviteID: string): Promise<OrganizationInviteDeleted>;
}

/** Organization groups 子资源。API：`/v1/organization/groups`。说明：管理组织 group 和成员。 */
export interface OpenAIOrganizationGroupsResource {
  /** Group users 子资源。API：Group users。说明：管理 group 成员。 */
  users: OpenAIOrganizationGroupUsersResource;
  /** 列出 groups。API：List groups。说明：分页读取组织 groups。 */
  list(params?: OrganizationGroupListParams): Promise<OrganizationGroupListResponse>;
  /** 创建 group。API：Create group。说明：创建组织 group。 */
  create(params: OrganizationGroupCreateParams): Promise<OrganizationGroup>;
  /** 更新 group。API：Update group。说明：修改组织 group 名称。 */
  update(groupID: string, params: OrganizationGroupUpdateParams): Promise<OrganizationGroup>;
  /** 删除 group。API：Delete group。说明：删除组织 group。 */
  delete(groupID: string): Promise<OrganizationGroupDeleted>;
}

/** Group users 子资源。API：`/v1/organization/groups/{group_id}/users`。说明：管理 group 成员。 */
export interface OpenAIOrganizationGroupUsersResource {
  /** 列出 group 用户。API：List group users。说明：分页读取 group 成员。 */
  list(groupID: string, params?: OrganizationGroupUserListParams): Promise<OrganizationGroupUserListResponse>;
  /** 添加 group 用户。API：Add group user。说明：把组织用户加入 group。 */
  create(groupID: string, params: OrganizationGroupUserCreateParams): Promise<OrganizationGroupUser>;
  /** 删除 group 用户。API：Remove group user。说明：把用户从 group 移除。 */
  delete(groupID: string, userID: string): Promise<OrganizationGroupUserDeleted>;
}

/**
 * Organization Projects 子资源。
 *
 * API：`/v1/organization/projects`。
 * 说明：创建、读取、更新和归档组织项目。
 */
export interface OpenAIOrganizationProjectsResource {
  /** Project users 子资源。API：Project users。说明：管理项目内用户和角色。 */
  users: OpenAIOrganizationProjectUsersResource;

  /** Project groups 子资源。API：Project groups。说明：管理 group 对项目的访问。 */
  groups: OpenAIOrganizationProjectGroupsResource;

  /** Project API keys 子资源。API：Project API keys。说明：列出、读取、删除项目内 API key。 */
  apiKeys: OpenAIOrganizationProjectApiKeysResource;

  /** Project service accounts 子资源。API：Project service accounts。说明：管理项目 bot 用户。 */
  serviceAccounts: OpenAIOrganizationProjectServiceAccountsResource;

  /** Project rate limits 子资源。API：Project rate limits。说明：管理项目模型限流。 */
  rateLimits: OpenAIOrganizationProjectRateLimitsResource;

  /** Project roles 子资源。API：Project Roles。说明：管理项目级自定义角色。 */
  roles: OpenAIOrganizationProjectRolesResource;

  /** Project certificates 子资源。API：Project Certificates。说明：管理项目级 mTLS 证书激活状态。 */
  certificates: OpenAIOrganizationProjectCertificatesResource;

  /**
   * 列出项目。
   *
   * API：`GET /v1/organization/projects`。
   * 说明：分页读取组织下项目，支持包含归档项目。
   */
  list(params?: OrganizationProjectListParams): Promise<OrganizationProjectListResponse>;

  /**
   * 创建项目。
   *
   * API：`POST /v1/organization/projects`。
   * 说明：创建新组织项目，需要 admin API key。
   */
  create(params: OrganizationProjectCreateParams): Promise<OrganizationProject>;

  /**
   * 获取项目。
   *
   * API：`GET /v1/organization/projects/{project_id}`。
   * 说明：读取单个项目详情。
   */
  retrieve(projectID: string): Promise<OrganizationProject>;

  /**
   * 更新项目。
   *
   * API：`POST /v1/organization/projects/{project_id}`。
   * 说明：更新项目名称。
   */
  update(projectID: string, params: OrganizationProjectUpdateParams): Promise<OrganizationProject>;

  /**
   * 归档项目。
   *
   * API：`POST /v1/organization/projects/{project_id}/archive`。
   * 说明：归档项目；默认项目不能归档。
   */
  archive(projectID: string): Promise<OrganizationProject>;
}

/** Project users 子资源。API：`/v1/organization/projects/{project_id}/users`。说明：管理项目成员。 */
export interface OpenAIOrganizationProjectUsersResource {
  /** 列出项目用户。API：List project users。说明：分页读取项目成员。 */
  list(projectID: string, params?: OrganizationProjectUserListParams): Promise<OrganizationProjectUserListResponse>;
  /** 添加项目用户。API：Create project user。说明：把组织用户加入项目。 */
  create(projectID: string, params: OrganizationProjectUserCreateParams): Promise<OrganizationProjectUser>;
  /** 获取项目用户。API：Retrieve project user。说明：读取项目成员详情。 */
  retrieve(projectID: string, userID: string): Promise<OrganizationProjectUser>;
  /** 更新项目用户。API：Modify project user。说明：修改成员角色。 */
  update(projectID: string, userID: string, params: OrganizationProjectUserUpdateParams): Promise<OrganizationProjectUser>;
  /** 删除项目用户。API：Delete project user。说明：移除成员。 */
  delete(projectID: string, userID: string): Promise<OrganizationProjectUserDeleted>;
}

/** Project groups 子资源。API：`/v1/organization/projects/{project_id}/groups`。说明：管理 group 对项目的访问。 */
export interface OpenAIOrganizationProjectGroupsResource {
  /** 列出项目组。API：List project groups。说明：分页读取拥有项目访问权限的 groups。 */
  list(projectID: string, params?: OrganizationProjectGroupListParams): Promise<OrganizationProjectGroupListResponse>;
  /** 添加项目组。API：Add project group。说明：授权 group 访问项目。 */
  create(projectID: string, params: OrganizationProjectGroupCreateParams): Promise<OrganizationProjectGroup>;
  /** 删除项目组。API：Remove project group。说明：撤销 group 访问。 */
  delete(projectID: string, groupID: string): Promise<OrganizationProjectGroupDeleted>;
}

/** Project API keys 子资源。API：`/v1/organization/projects/{project_id}/api_keys`。说明：管理项目内 API key 可见性和删除。 */
export interface OpenAIOrganizationProjectApiKeysResource {
  /** 列出 API keys。API：List project API keys。说明：分页读取项目内 API keys。 */
  list(projectID: string, params?: OrganizationProjectApiKeyListParams): Promise<OrganizationProjectApiKeyListResponse>;
  /** 获取 API key。API：Retrieve project API key。说明：读取单个 key 元数据。 */
  retrieve(projectID: string, keyID: string): Promise<OrganizationProjectApiKey>;
  /** 删除 API key。API：Delete project API key。说明：删除用户 API key。 */
  delete(projectID: string, keyID: string): Promise<OrganizationProjectApiKeyDeleted>;
}

/** Project service accounts 子资源。API：`/v1/organization/projects/{project_id}/service_accounts`。说明：管理项目 bot 用户。 */
export interface OpenAIOrganizationProjectServiceAccountsResource {
  /** 列出 service accounts。API：List project service accounts。说明：分页读取项目 bot 用户。 */
  list(projectID: string, params?: OrganizationProjectServiceAccountListParams): Promise<OrganizationProjectServiceAccountListResponse>;
  /** 创建 service account。API：Create project service account。说明：创建 bot 用户并返回一次性 API key。 */
  create(projectID: string, params: OrganizationProjectServiceAccountCreateParams): Promise<OrganizationProjectServiceAccount>;
  /** 获取 service account。API：Retrieve project service account。说明：读取 bot 用户详情。 */
  retrieve(projectID: string, serviceAccountID: string): Promise<OrganizationProjectServiceAccount>;
  /** 删除 service account。API：Delete project service account。说明：删除项目 bot 用户。 */
  delete(projectID: string, serviceAccountID: string): Promise<OrganizationProjectServiceAccountDeleted>;
}

/** Project rate limits 子资源。API：`/v1/organization/projects/{project_id}/rate_limits`。说明：管理项目模型限流。 */
export interface OpenAIOrganizationProjectRateLimitsResource {
  /** 列出 rate limits。API：List project rate limits。说明：分页读取项目模型限流。 */
  list(projectID: string, params?: OrganizationProjectRateLimitListParams): Promise<OrganizationProjectRateLimitListResponse>;
  /** 更新 rate limit。API：Modify project rate limit。说明：更新某个模型限流字段。 */
  update(projectID: string, rateLimitID: string, params: OrganizationProjectRateLimitUpdateParams): Promise<OrganizationProjectRateLimit>;
}

/** Project roles 子资源。API：`/v1/projects/{project_id}/roles`。说明：管理项目级自定义角色。 */
export interface OpenAIOrganizationProjectRolesResource {
  /** 列出 project roles。API：List project roles。说明：分页读取项目角色。 */
  list(projectID: string, params?: OrganizationRoleListParams): Promise<OrganizationRoleListResponse>;
  /** 创建 project role。API：Create project role。说明：创建项目级自定义角色。 */
  create(projectID: string, params: OrganizationRoleCreateParams): Promise<OrganizationRole>;
  /** 更新 project role。API：Update project role。说明：修改项目级自定义角色。 */
  update(projectID: string, roleID: string, params: OrganizationRoleUpdateParams): Promise<OrganizationRole>;
  /** 删除 project role。API：Delete project role。说明：删除项目级自定义角色。 */
  delete(projectID: string, roleID: string): Promise<OrganizationRoleDeleted>;
}

/** Project certificates 子资源。API：`/v1/organization/projects/{project_id}/certificates`。说明：管理项目证书激活状态。 */
export interface OpenAIOrganizationProjectCertificatesResource {
  /** 列出项目证书。API：List project certificates。说明：分页读取项目证书。 */
  list(projectID: string, params?: OrganizationCertificateListParams): Promise<OrganizationCertificateListResponse>;
  /** 激活项目证书。API：Activate certificates for project。说明：项目级激活证书。 */
  activate(projectID: string, params: OrganizationCertificateToggleParams): Promise<OrganizationCertificateActivationResponse>;
  /** 停用项目证书。API：Deactivate certificates for project。说明：项目级停用证书。 */
  deactivate(projectID: string, params: OrganizationCertificateToggleParams): Promise<OrganizationCertificateActivationResponse>;
}

interface EmptyRequestBody {
}

export class OrganizationResource implements OpenAIOrganizationResource {
  projects: OpenAIOrganizationProjectsResource;
  groups: OpenAIOrganizationGroupsResource;
  users: OpenAIOrganizationUsersResource;
  invites: OpenAIOrganizationInvitesResource;
  adminApiKeys: OpenAIOrganizationAdminApiKeysResource;
  roles: OpenAIOrganizationRolesResource;
  auditLogs: OpenAIOrganizationAuditLogsResource;
  certificates: OpenAIOrganizationCertificatesResource;

  constructor(client: OpenAIRequestClient) {
    this.projects = new OrganizationProjectsResource(client);
    this.groups = new OrganizationGroupsResource(client);
    this.users = new OrganizationUsersResource(client);
    this.invites = new OrganizationInvitesResource(client);
    this.adminApiKeys = new OrganizationAdminApiKeysResource(client);
    this.roles = new OrganizationRolesResource(client);
    this.auditLogs = new OrganizationAuditLogsResource(client);
    this.certificates = new OrganizationCertificatesResource(client);
  }
}

class OrganizationProjectsResource implements OpenAIOrganizationProjectsResource {
  users: OpenAIOrganizationProjectUsersResource;
  groups: OpenAIOrganizationProjectGroupsResource;
  apiKeys: OpenAIOrganizationProjectApiKeysResource;
  serviceAccounts: OpenAIOrganizationProjectServiceAccountsResource;
  rateLimits: OpenAIOrganizationProjectRateLimitsResource;
  roles: OpenAIOrganizationProjectRolesResource;
  certificates: OpenAIOrganizationProjectCertificatesResource;
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
    this.users = new OrganizationProjectUsersResource(client);
    this.groups = new OrganizationProjectGroupsResource(client);
    this.apiKeys = new OrganizationProjectApiKeysResource(client);
    this.serviceAccounts = new OrganizationProjectServiceAccountsResource(client);
    this.rateLimits = new OrganizationProjectRateLimitsResource(client);
    this.roles = new OrganizationProjectRolesResource(client);
    this.certificates = new OrganizationProjectCertificatesResource(client);
  }

  async list(params?: OrganizationProjectListParams): Promise<OrganizationProjectListResponse> {
    const body = await this.client.get(this.buildListPath(params));
    return JSON.parse(body) as OrganizationProjectListResponse;
  }

  async create(params: OrganizationProjectCreateParams): Promise<OrganizationProject> {
    const body = await this.client.post('/organization/projects', params);
    return JSON.parse(body) as OrganizationProject;
  }

  async retrieve(projectID: string): Promise<OrganizationProject> {
    const body = await this.client.get('/organization/projects/' + encodeURIComponent(projectID));
    return JSON.parse(body) as OrganizationProject;
  }

  async update(projectID: string, params: OrganizationProjectUpdateParams): Promise<OrganizationProject> {
    const body = await this.client.post('/organization/projects/' + encodeURIComponent(projectID), params);
    return JSON.parse(body) as OrganizationProject;
  }

  async archive(projectID: string): Promise<OrganizationProject> {
    const requestBody: EmptyRequestBody = {};
    const body = await this.client.post('/organization/projects/' + encodeURIComponent(projectID) + '/archive', requestBody);
    return JSON.parse(body) as OrganizationProject;
  }

  private buildListPath(params?: OrganizationProjectListParams): string {
    if (params === undefined) {
      return '/organization/projects';
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'after', params.after);
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    if (params.include_archived !== undefined) {
      query.push('include_archived=' + params.include_archived.toString());
    }
    return buildPathWithQuery('/organization/projects', query);
  }
}

class OrganizationProjectUsersResource implements OpenAIOrganizationProjectUsersResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(projectID: string, params?: OrganizationProjectUserListParams): Promise<OrganizationProjectUserListResponse> {
    const body = await this.client.get(this.buildListPath(projectID, params));
    return JSON.parse(body) as OrganizationProjectUserListResponse;
  }

  async create(projectID: string, params: OrganizationProjectUserCreateParams): Promise<OrganizationProjectUser> {
    const body = await this.client.post(this.buildBasePath(projectID), params);
    return JSON.parse(body) as OrganizationProjectUser;
  }

  async retrieve(projectID: string, userID: string): Promise<OrganizationProjectUser> {
    const body = await this.client.get(this.buildBasePath(projectID) + '/' + encodeURIComponent(userID));
    return JSON.parse(body) as OrganizationProjectUser;
  }

  async update(projectID: string, userID: string, params: OrganizationProjectUserUpdateParams): Promise<OrganizationProjectUser> {
    const body = await this.client.post(this.buildBasePath(projectID) + '/' + encodeURIComponent(userID), params);
    return JSON.parse(body) as OrganizationProjectUser;
  }

  async delete(projectID: string, userID: string): Promise<OrganizationProjectUserDeleted> {
    const body = await this.client.delete(this.buildBasePath(projectID) + '/' + encodeURIComponent(userID));
    return JSON.parse(body) as OrganizationProjectUserDeleted;
  }

  private buildListPath(projectID: string, params?: OrganizationProjectUserListParams): string {
    if (params === undefined) {
      return this.buildBasePath(projectID);
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'after', params.after);
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    return buildPathWithQuery(this.buildBasePath(projectID), query);
  }

  private buildBasePath(projectID: string): string {
    return '/organization/projects/' + encodeURIComponent(projectID) + '/users';
  }
}

class OrganizationProjectGroupsResource implements OpenAIOrganizationProjectGroupsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(projectID: string, params?: OrganizationProjectGroupListParams): Promise<OrganizationProjectGroupListResponse> {
    const body = await this.client.get(this.buildListPath(projectID, params));
    return JSON.parse(body) as OrganizationProjectGroupListResponse;
  }

  async create(projectID: string, params: OrganizationProjectGroupCreateParams): Promise<OrganizationProjectGroup> {
    const body = await this.client.post(this.buildBasePath(projectID), params);
    return JSON.parse(body) as OrganizationProjectGroup;
  }

  async delete(projectID: string, groupID: string): Promise<OrganizationProjectGroupDeleted> {
    const body = await this.client.delete(this.buildBasePath(projectID) + '/' + encodeURIComponent(groupID));
    return JSON.parse(body) as OrganizationProjectGroupDeleted;
  }

  private buildListPath(projectID: string, params?: OrganizationProjectGroupListParams): string {
    if (params === undefined) {
      return this.buildBasePath(projectID);
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'after', params.after);
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    if (params.order !== undefined) {
      query.push('order=' + params.order);
    }
    return buildPathWithQuery(this.buildBasePath(projectID), query);
  }

  private buildBasePath(projectID: string): string {
    return '/organization/projects/' + encodeURIComponent(projectID) + '/groups';
  }
}

class OrganizationProjectApiKeysResource implements OpenAIOrganizationProjectApiKeysResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(projectID: string, params?: OrganizationProjectApiKeyListParams): Promise<OrganizationProjectApiKeyListResponse> {
    const body = await this.client.get(this.buildListPath(projectID, params));
    return JSON.parse(body) as OrganizationProjectApiKeyListResponse;
  }

  async retrieve(projectID: string, keyID: string): Promise<OrganizationProjectApiKey> {
    const body = await this.client.get(this.buildBasePath(projectID) + '/' + encodeURIComponent(keyID));
    return JSON.parse(body) as OrganizationProjectApiKey;
  }

  async delete(projectID: string, keyID: string): Promise<OrganizationProjectApiKeyDeleted> {
    const body = await this.client.delete(this.buildBasePath(projectID) + '/' + encodeURIComponent(keyID));
    return JSON.parse(body) as OrganizationProjectApiKeyDeleted;
  }

  private buildListPath(projectID: string, params?: OrganizationProjectApiKeyListParams): string {
    if (params === undefined) {
      return this.buildBasePath(projectID);
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'after', params.after);
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    return buildPathWithQuery(this.buildBasePath(projectID), query);
  }

  private buildBasePath(projectID: string): string {
    return '/organization/projects/' + encodeURIComponent(projectID) + '/api_keys';
  }
}

class OrganizationProjectServiceAccountsResource implements OpenAIOrganizationProjectServiceAccountsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(projectID: string, params?: OrganizationProjectServiceAccountListParams): Promise<OrganizationProjectServiceAccountListResponse> {
    const body = await this.client.get(this.buildListPath(projectID, params));
    return JSON.parse(body) as OrganizationProjectServiceAccountListResponse;
  }

  async create(projectID: string, params: OrganizationProjectServiceAccountCreateParams): Promise<OrganizationProjectServiceAccount> {
    const body = await this.client.post(this.buildBasePath(projectID), params);
    return JSON.parse(body) as OrganizationProjectServiceAccount;
  }

  async retrieve(projectID: string, serviceAccountID: string): Promise<OrganizationProjectServiceAccount> {
    const body = await this.client.get(this.buildBasePath(projectID) + '/' + encodeURIComponent(serviceAccountID));
    return JSON.parse(body) as OrganizationProjectServiceAccount;
  }

  async delete(projectID: string, serviceAccountID: string): Promise<OrganizationProjectServiceAccountDeleted> {
    const body = await this.client.delete(this.buildBasePath(projectID) + '/' + encodeURIComponent(serviceAccountID));
    return JSON.parse(body) as OrganizationProjectServiceAccountDeleted;
  }

  private buildListPath(projectID: string, params?: OrganizationProjectServiceAccountListParams): string {
    if (params === undefined) {
      return this.buildBasePath(projectID);
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'after', params.after);
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    return buildPathWithQuery(this.buildBasePath(projectID), query);
  }

  private buildBasePath(projectID: string): string {
    return '/organization/projects/' + encodeURIComponent(projectID) + '/service_accounts';
  }
}

class OrganizationProjectRateLimitsResource implements OpenAIOrganizationProjectRateLimitsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(projectID: string, params?: OrganizationProjectRateLimitListParams): Promise<OrganizationProjectRateLimitListResponse> {
    const body = await this.client.get(this.buildListPath(projectID, params));
    return JSON.parse(body) as OrganizationProjectRateLimitListResponse;
  }

  async update(projectID: string, rateLimitID: string, params: OrganizationProjectRateLimitUpdateParams): Promise<OrganizationProjectRateLimit> {
    const body = await this.client.post(this.buildBasePath(projectID) + '/' + encodeURIComponent(rateLimitID), params);
    return JSON.parse(body) as OrganizationProjectRateLimit;
  }

  private buildListPath(projectID: string, params?: OrganizationProjectRateLimitListParams): string {
    if (params === undefined) {
      return this.buildBasePath(projectID);
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'after', params.after);
    appendStringQuery(query, 'before', params.before);
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    return buildPathWithQuery(this.buildBasePath(projectID), query);
  }

  private buildBasePath(projectID: string): string {
    return '/organization/projects/' + encodeURIComponent(projectID) + '/rate_limits';
  }
}

class OrganizationProjectRolesResource implements OpenAIOrganizationProjectRolesResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(projectID: string, params?: OrganizationRoleListParams): Promise<OrganizationRoleListResponse> {
    const body = await this.client.get(this.buildListPath(projectID, params));
    return JSON.parse(body) as OrganizationRoleListResponse;
  }

  async create(projectID: string, params: OrganizationRoleCreateParams): Promise<OrganizationRole> {
    const body = await this.client.post(this.buildBasePath(projectID), params);
    return JSON.parse(body) as OrganizationRole;
  }

  async update(projectID: string, roleID: string, params: OrganizationRoleUpdateParams): Promise<OrganizationRole> {
    const body = await this.client.post(this.buildBasePath(projectID) + '/' + encodeURIComponent(roleID), params);
    return JSON.parse(body) as OrganizationRole;
  }

  async delete(projectID: string, roleID: string): Promise<OrganizationRoleDeleted> {
    const body = await this.client.delete(this.buildBasePath(projectID) + '/' + encodeURIComponent(roleID));
    return JSON.parse(body) as OrganizationRoleDeleted;
  }

  private buildListPath(projectID: string, params?: OrganizationRoleListParams): string {
    if (params === undefined) {
      return this.buildBasePath(projectID);
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'after', params.after);
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    if (params.order !== undefined) {
      query.push('order=' + params.order);
    }
    return buildPathWithQuery(this.buildBasePath(projectID), query);
  }

  private buildBasePath(projectID: string): string {
    return '/organization/projects/' + encodeURIComponent(projectID) + '/roles';
  }
}

class OrganizationProjectCertificatesResource implements OpenAIOrganizationProjectCertificatesResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(projectID: string, params?: OrganizationCertificateListParams): Promise<OrganizationCertificateListResponse> {
    const body = await this.client.get(this.buildListPath(projectID, params));
    return JSON.parse(body) as OrganizationCertificateListResponse;
  }

  async activate(projectID: string, params: OrganizationCertificateToggleParams): Promise<OrganizationCertificateActivationResponse> {
    const body = await this.client.post(this.buildBasePath(projectID) + '/activate', params);
    return JSON.parse(body) as OrganizationCertificateActivationResponse;
  }

  async deactivate(projectID: string, params: OrganizationCertificateToggleParams): Promise<OrganizationCertificateActivationResponse> {
    const body = await this.client.post(this.buildBasePath(projectID) + '/deactivate', params);
    return JSON.parse(body) as OrganizationCertificateActivationResponse;
  }

  private buildListPath(projectID: string, params?: OrganizationCertificateListParams): string {
    if (params === undefined) {
      return this.buildBasePath(projectID);
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'after', params.after);
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    return buildPathWithQuery(this.buildBasePath(projectID), query);
  }

  private buildBasePath(projectID: string): string {
    return '/organization/projects/' + encodeURIComponent(projectID) + '/certificates';
  }
}

class OrganizationGroupsResource implements OpenAIOrganizationGroupsResource {
  users: OpenAIOrganizationGroupUsersResource;
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
    this.users = new OrganizationGroupUsersResource(client);
  }

  async list(params?: OrganizationGroupListParams): Promise<OrganizationGroupListResponse> {
    const body = await this.client.get(this.buildListPath(params));
    return JSON.parse(body) as OrganizationGroupListResponse;
  }

  async create(params: OrganizationGroupCreateParams): Promise<OrganizationGroup> {
    const body = await this.client.post('/organization/groups', params);
    return JSON.parse(body) as OrganizationGroup;
  }

  async update(groupID: string, params: OrganizationGroupUpdateParams): Promise<OrganizationGroup> {
    const body = await this.client.post('/organization/groups/' + encodeURIComponent(groupID), params);
    return JSON.parse(body) as OrganizationGroup;
  }

  async delete(groupID: string): Promise<OrganizationGroupDeleted> {
    const body = await this.client.delete('/organization/groups/' + encodeURIComponent(groupID));
    return JSON.parse(body) as OrganizationGroupDeleted;
  }

  private buildListPath(params?: OrganizationGroupListParams): string {
    if (params === undefined) {
      return '/organization/groups';
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'after', params.after);
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    if (params.order !== undefined) {
      query.push('order=' + params.order);
    }
    return buildPathWithQuery('/organization/groups', query);
  }
}

class OrganizationGroupUsersResource implements OpenAIOrganizationGroupUsersResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(groupID: string, params?: OrganizationGroupUserListParams): Promise<OrganizationGroupUserListResponse> {
    const body = await this.client.get(this.buildListPath(groupID, params));
    return JSON.parse(body) as OrganizationGroupUserListResponse;
  }

  async create(groupID: string, params: OrganizationGroupUserCreateParams): Promise<OrganizationGroupUser> {
    const body = await this.client.post(this.buildBasePath(groupID), params);
    return JSON.parse(body) as OrganizationGroupUser;
  }

  async delete(groupID: string, userID: string): Promise<OrganizationGroupUserDeleted> {
    const body = await this.client.delete(this.buildBasePath(groupID) + '/' + encodeURIComponent(userID));
    return JSON.parse(body) as OrganizationGroupUserDeleted;
  }

  private buildListPath(groupID: string, params?: OrganizationGroupUserListParams): string {
    if (params === undefined) {
      return this.buildBasePath(groupID);
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'after', params.after);
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    if (params.order !== undefined) {
      query.push('order=' + params.order);
    }
    return buildPathWithQuery(this.buildBasePath(groupID), query);
  }

  private buildBasePath(groupID: string): string {
    return '/organization/groups/' + encodeURIComponent(groupID) + '/users';
  }
}

class OrganizationUsersResource implements OpenAIOrganizationUsersResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(params?: OrganizationUserListParams): Promise<OrganizationUserListResponse> {
    const body = await this.client.get(this.buildListPath(params));
    return JSON.parse(body) as OrganizationUserListResponse;
  }

  async retrieve(userID: string): Promise<OrganizationUser> {
    const body = await this.client.get('/organization/users/' + encodeURIComponent(userID));
    return JSON.parse(body) as OrganizationUser;
  }

  async update(userID: string, params: OrganizationUserUpdateParams): Promise<OrganizationUser> {
    const body = await this.client.post('/organization/users/' + encodeURIComponent(userID), params);
    return JSON.parse(body) as OrganizationUser;
  }

  async delete(userID: string): Promise<OrganizationUserDeleted> {
    const body = await this.client.delete('/organization/users/' + encodeURIComponent(userID));
    return JSON.parse(body) as OrganizationUserDeleted;
  }

  private buildListPath(params?: OrganizationUserListParams): string {
    if (params === undefined) {
      return '/organization/users';
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'after', params.after);
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    return buildPathWithQuery('/organization/users', query);
  }
}

class OrganizationInvitesResource implements OpenAIOrganizationInvitesResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(params?: OrganizationInviteListParams): Promise<OrganizationInviteListResponse> {
    const body = await this.client.get(this.buildListPath(params));
    return JSON.parse(body) as OrganizationInviteListResponse;
  }

  async create(params: OrganizationInviteCreateParams): Promise<OrganizationInvite> {
    const body = await this.client.post('/organization/invites', params);
    return JSON.parse(body) as OrganizationInvite;
  }

  async retrieve(inviteID: string): Promise<OrganizationInvite> {
    const body = await this.client.get('/organization/invites/' + encodeURIComponent(inviteID));
    return JSON.parse(body) as OrganizationInvite;
  }

  async delete(inviteID: string): Promise<OrganizationInviteDeleted> {
    const body = await this.client.delete('/organization/invites/' + encodeURIComponent(inviteID));
    return JSON.parse(body) as OrganizationInviteDeleted;
  }

  private buildListPath(params?: OrganizationInviteListParams): string {
    if (params === undefined) {
      return '/organization/invites';
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'after', params.after);
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    return buildPathWithQuery('/organization/invites', query);
  }
}

class OrganizationAdminApiKeysResource implements OpenAIOrganizationAdminApiKeysResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(params?: OrganizationAdminApiKeyListParams): Promise<OrganizationAdminApiKeyListResponse> {
    const body = await this.client.get(this.buildListPath(params));
    return JSON.parse(body) as OrganizationAdminApiKeyListResponse;
  }

  async create(params: OrganizationAdminApiKeyCreateParams): Promise<OrganizationAdminApiKey> {
    const body = await this.client.post('/organization/admin_api_keys', params);
    return JSON.parse(body) as OrganizationAdminApiKey;
  }

  async retrieve(keyID: string): Promise<OrganizationAdminApiKey> {
    const body = await this.client.get('/organization/admin_api_keys/' + encodeURIComponent(keyID));
    return JSON.parse(body) as OrganizationAdminApiKey;
  }

  async delete(keyID: string): Promise<OrganizationAdminApiKeyDeleted> {
    const body = await this.client.delete('/organization/admin_api_keys/' + encodeURIComponent(keyID));
    return JSON.parse(body) as OrganizationAdminApiKeyDeleted;
  }

  private buildListPath(params?: OrganizationAdminApiKeyListParams): string {
    if (params === undefined) {
      return '/organization/admin_api_keys';
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'after', params.after);
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    return buildPathWithQuery('/organization/admin_api_keys', query);
  }
}

class OrganizationRolesResource implements OpenAIOrganizationRolesResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(params?: OrganizationRoleListParams): Promise<OrganizationRoleListResponse> {
    const body = await this.client.get(this.buildListPath(params));
    return JSON.parse(body) as OrganizationRoleListResponse;
  }

  async create(params: OrganizationRoleCreateParams): Promise<OrganizationRole> {
    const body = await this.client.post('/organization/roles', params);
    return JSON.parse(body) as OrganizationRole;
  }

  async update(roleID: string, params: OrganizationRoleUpdateParams): Promise<OrganizationRole> {
    const body = await this.client.post('/organization/roles/' + encodeURIComponent(roleID), params);
    return JSON.parse(body) as OrganizationRole;
  }

  async delete(roleID: string): Promise<OrganizationRoleDeleted> {
    const body = await this.client.delete('/organization/roles/' + encodeURIComponent(roleID));
    return JSON.parse(body) as OrganizationRoleDeleted;
  }

  private buildListPath(params?: OrganizationRoleListParams): string {
    if (params === undefined) {
      return '/organization/roles';
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'after', params.after);
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    if (params.order !== undefined) {
      query.push('order=' + params.order);
    }
    return buildPathWithQuery('/organization/roles', query);
  }
}

class OrganizationAuditLogsResource implements OpenAIOrganizationAuditLogsResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(params?: OrganizationAuditLogListParams): Promise<OrganizationAuditLogListResponse> {
    const body = await this.client.get(this.buildListPath(params));
    return JSON.parse(body) as OrganizationAuditLogListResponse;
  }

  private buildListPath(params?: OrganizationAuditLogListParams): string {
    if (params === undefined) {
      return '/organization/audit_logs';
    }
    const query: Array<string> = [];
    appendStringArrayQuery(query, 'actor_emails', params.actor_emails);
    appendStringArrayQuery(query, 'actor_ids', params.actor_ids);
    appendStringQuery(query, 'after', params.after);
    appendStringQuery(query, 'before', params.before);
    appendStringArrayQuery(query, 'event_types', params.event_types);
    appendStringArrayQuery(query, 'project_ids', params.project_ids);
    appendStringArrayQuery(query, 'resource_ids', params.resource_ids);
    this.appendEffectiveAtQuery(query, params);
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    return buildPathWithQuery('/organization/audit_logs', query);
  }

  private appendEffectiveAtQuery(query: Array<string>, params: OrganizationAuditLogListParams): void {
    if (params.effective_at === undefined) {
      return;
    }
    if (params.effective_at.gt !== undefined) {
      query.push('effective_at[gt]=' + params.effective_at.gt.toString());
    }
    if (params.effective_at.gte !== undefined) {
      query.push('effective_at[gte]=' + params.effective_at.gte.toString());
    }
    if (params.effective_at.lt !== undefined) {
      query.push('effective_at[lt]=' + params.effective_at.lt.toString());
    }
    if (params.effective_at.lte !== undefined) {
      query.push('effective_at[lte]=' + params.effective_at.lte.toString());
    }
  }
}

class OrganizationCertificatesResource implements OpenAIOrganizationCertificatesResource {
  private client: OpenAIRequestClient;

  constructor(client: OpenAIRequestClient) {
    this.client = client;
  }

  async list(params?: OrganizationCertificateListParams): Promise<OrganizationCertificateListResponse> {
    const body = await this.client.get(this.buildListPath(params));
    return JSON.parse(body) as OrganizationCertificateListResponse;
  }

  async create(params: OrganizationCertificateCreateParams): Promise<OrganizationCertificate> {
    const body = await this.client.post('/organization/certificates', params);
    return JSON.parse(body) as OrganizationCertificate;
  }

  async retrieve(certificateID: string): Promise<OrganizationCertificate> {
    const body = await this.client.get('/organization/certificates/' + encodeURIComponent(certificateID));
    return JSON.parse(body) as OrganizationCertificate;
  }

  async update(certificateID: string, params: OrganizationCertificateUpdateParams): Promise<OrganizationCertificate> {
    const body = await this.client.post('/organization/certificates/' + encodeURIComponent(certificateID), params);
    return JSON.parse(body) as OrganizationCertificate;
  }

  async delete(certificateID: string): Promise<OrganizationCertificateDeleted> {
    const body = await this.client.delete('/organization/certificates/' + encodeURIComponent(certificateID));
    return JSON.parse(body) as OrganizationCertificateDeleted;
  }

  async activate(params: OrganizationCertificateToggleParams): Promise<OrganizationCertificateActivationResponse> {
    const body = await this.client.post('/organization/certificates/activate', params);
    return JSON.parse(body) as OrganizationCertificateActivationResponse;
  }

  async deactivate(params: OrganizationCertificateToggleParams): Promise<OrganizationCertificateActivationResponse> {
    const body = await this.client.post('/organization/certificates/deactivate', params);
    return JSON.parse(body) as OrganizationCertificateActivationResponse;
  }

  private buildListPath(params?: OrganizationCertificateListParams): string {
    if (params === undefined) {
      return '/organization/certificates';
    }
    const query: Array<string> = [];
    appendStringQuery(query, 'after', params.after);
    if (params.limit !== undefined) {
      query.push('limit=' + params.limit.toString());
    }
    return buildPathWithQuery('/organization/certificates', query);
  }
}
