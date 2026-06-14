/**
 * 作者注释模块在模块注册表中的唯一标识名，用于跨模块引用。
 */
export const AUTHOR_NOTE_MODULE_NAME: string = '2_floating_prompt';

/**
 * 作者注释元数据，包含用户在运行时编辑的核心参数（prompt、interval 等）。
 * 由当前对话实例内部维护，每次调用 buildInjection 时提供。
 */
export interface AuthorNoteMetadata {
  /**
   * 注入的提示词文本。
   */
  prompt: string;
  /**
   * 两次注入之间间隔的用户消息条数。
   */
  interval: number;
  /**
   * 注入在对话历史中的插入深度（从最新消息往前数第几条）。
   */
  depth: number;
  /**
   * 注入文本在消息中的插入位置（开头/结尾等）。
   */
  position: number;
  /**
   * 注入使用的角色标识（user/assistant/system 等角色枚举值）。
   */
  role: number;
}

/**
 * 作者注释默认值配置，当元数据中的对应值为空或无效时使用。
 * 所有字段均设定了合理回退值，确保注入行为可预测。
 */
export interface AuthorNoteDefaults {
  /**
   * 默认的注入提示词文本。
   */
  prompt: string;
  /**
   * 默认的注入间隔（消息条数）。
   */
  interval: number;
  /**
   * 默认的插入深度。
   */
  depth: number;
  /**
   * 默认的插入位置。
   */
  position: number;
  /**
   * 默认的角色标识。
   */
  role: number;
  /**
   * 是否允许注入执行世界信息（World Info）扫描。
   */
  allowWorldInfoScan: boolean;
}

/**
 * 角色专属的作者注释覆盖项，允许每个角色拥有独立的注入提示词与配置。
 * 当该项启用时，将优先于全局默认值参与注入构建。
 */
export interface AuthorNoteCharacterNote {
  /**
   * 角色专属的注入提示词文本。
   */
  prompt: string;
  /**
   * 是否启用该角色的专属注释注入。
   */
  enabled: boolean;
  /**
   * 角色注释在注入中的插入位置。
   */
  position: number;
}

/**
 * 调用 AuthorNoteRuntime.buildInjection 时所需的所有输入参数集合。
 */
export interface AuthorNoteBuildInput {
  /**
   * 当前对话的标识符，用于关联注入到正确的对话上下文。
   */
  chatId: string;
  /**
   * 当前是否处于对话（Chat）模式，非对话模式将跳过注入。
   */
  inChat: boolean;
  /**
   * 当前对话中用户已发送的消息总数，用于计算注入时机。
   */
  userMessageCount: number;
  /**
   * 用户自定义的元数据，直接来自对话框配置。
   */
  metadata: AuthorNoteMetadata;
  /**
   * 模块的默认参数集，在元数据字段为空时作为回退值。
   */
  defaults: AuthorNoteDefaults;
  /**
   * 可选的角色专属注释覆盖，启用后将改写最终 prompt。
   */
  characterNote?: AuthorNoteCharacterNote;
}

/**
 * 一次作者注释注入的完整指令，包含所有需要在 LLM 请求中生效的参数。
 * buildInjection 方法的返回值，也是事件发布的数据核心。
 */
export interface AuthorNoteInjection {
  /**
   * 所属模块名称，用于事件订阅方区分注入来源。
   */
  moduleName: string;
  /**
   * 目标对话标识符，与输入的 chatId 保持一致。
   */
  chatId: string;
  /**
   * 最终解析后的注入提示词文本。
   */
  prompt: string;
  /**
   * 本次注入是否处于启用状态。
   */
  enabled: boolean;
  /**
   * 本次注入是否需要触发世界信息（World Info）检索。
   */
  shouldScanWorldInfo: boolean;
  /**
   * 距离下次实际注入还剩多少条用户消息，为 0 时表示本轮触发。
   */
  messagesTillInsertion: number;
  /**
   * 注入文本在消息中的插入位置。
   */
  position: number;
  /**
   * 注入在对话历史中的插入深度。
   */
  depth: number;
  /**
   * 注入使用的角色标识。
   */
  role: number;
}

/**
 * 作者注释事件发布时携带的数据载荷，包含构建完成的注入指令快照。
 */
export interface AuthorNoteBuiltPayload {
  /**
   * 构建完成的注入指令对象。
   */
  injection: AuthorNoteInjection;
}
