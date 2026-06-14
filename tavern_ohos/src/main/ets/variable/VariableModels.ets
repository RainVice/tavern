/**
 * 描述变量模块在运行时交换的数据结构。
 */
export interface VariableResolveContext {
  /**
   * 用户标识，用于解析 user 作用域变量时确定所属用户。
   */
  userId: string;
  /**
   * 角色标识，用于解析 character 作用域变量时确定所属角色。
   */
  characterId: string;
  /**
   * persona 标识，用于解析 persona 作用域变量时确定当前 persona。
   */
  personaId: string;
  /**
   * 聊天标识，用于解析 chat 作用域变量时确定当前会话。
   */
  chatId: string;
  /**
   * group 标识，用于解析 group 作用域变量时确定当前群组。
   */
  groupId: string;
  /**
   * 消息标识，用于解析 message 作用域变量时确定当前消息。
   */
  messageId: string;
  /**
   * plugin 标识，用于解析 plugin 作用域变量时确定当前插件。
   */
  pluginId: string;
}

/**
 * 描述变量持久化或内存索引中的一条记录。
 */
export interface VariableEntry {
  /**
   * 变量作用域（global、user、character、chat、temporary 等），决定变量的生命周期和可见范围。
   */
  scope: string;
  /**
   * 作用域下的具体对象标识，如用户 ID 或聊天 ID，用于在作用域内唯一确定变量归属。
   */
  scopeId: string;
  /**
   * 关联的插件标识（作用域为 plugin 时使用），用于插件在 plugin 作用域中存储变量。
   */
  pluginId: string;
  /**
   * 变量键名，在 (scope, scopeId) 范围内必须唯一，用于变量值的查询定位。
   */
  key: string;
  /**
   * 变量值，存储任意字符串内容，在提示词变量展开时被替换到文本中。
   */
  value: string;
  /**
   * 是否为持久化变量（temporary 和 pipe 作用域的变量不会持久化），决定导出和备份时的取值。
   */
  persistent: boolean;
  /**
   * 变量创建时间戳（毫秒），用于变量生命周期追踪和排序。
   */
  createdAt: number;
  /**
   * 变量最后更新时间戳（毫秒），用于变量变更监测。
   */
  updatedAt: number;
}

/**
 * 描述变量操作完成后返回给调用方的结果。
 */
export interface VariableResolveResult {
  /**
   * 是否找到了匹配的变量，用于调用方判断是否需要使用默认值。
   */
  found: boolean;
  /**
   * 匹配到的变量所处的作用域，反映变量解析链路中实际命中的作用域层级。
   */
  scope: string;
  /**
   * 匹配到的变量作用域标识，用于定位变量存储位置。
   */
  scopeId: string;
  /**
   * 匹配到的变量键名，与查询输入的 key 一致。
   */
  key: string;
  /**
   * 匹配到的变量值，用于在宏展开或命令执行时替换到目标文本中。
   */
  value: string;
}

/**
 * 描述变量事件发布时携带的数据结构。
 */
export interface VariableChangedPayload {
  /**
   * 发生变更的变量作用域，供事件订阅方定位变更位置。
   */
  scope: string;
  /**
   * 发生变更的变量作用域标识，供事件订阅方定位变更位置。
   */
  scopeId: string;
  /**
   * 发生变更的变量键名，用于标识具体变动的变量。
   */
  key: string;
  /**
   * 变更前的旧值，供事件订阅方执行差异对比或撤销操作。
   */
  oldValue: string;
  /**
   * 变更后的新值，供事件订阅方获取更新后的数据。
   */
  newValue: string;
  /**
   * 变量是否为持久化类型，供事件订阅方判断是否需要同步到存储。
   */
  persistent: boolean;
}

/**
 * 描述变量删除事件发布时携带的数据结构，供事件订阅方在变量删除时执行后续同步或清理。
 */
export interface VariableDeletedPayload {
  /**
   * 被删除变量所在的作用域，供事件订阅方定位删除位置。
   */
  scope: string;
  /**
   * 被删除变量所在的作用域标识，供事件订阅方定位删除位置。
   */
  scopeId: string;
  /**
   * 被删除变量的键名，用于标识具体移除的变量。
   */
  key: string;
  /**
   * 被删除变量的旧值，供事件订阅方执行数据补偿或日志记录。
   */
  oldValue: string;
}

/**
 * 描述变量导出时生成的数据结构，用于备份、迁移或与外部系统互通。
 */
export interface VariableExportData {
  /**
   * 导出的变量条目列表（仅含持久化变量），用于数据迁移或恢复。
   */
  entries: Array<VariableEntry>;
  /**
   * 导出时间戳（毫秒），用于记录导出操作的执行时间。
   */
  exportedAt: number;
}
