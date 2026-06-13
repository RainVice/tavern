import type { JsonObject, Metadata, OpenAIModel } from './Common';
import type { ModerationOutcome } from './Moderations';

/**
 * Responses API 常见模型 ID。
 *
 * API：`POST /v1/responses`。
 * 说明：这里保留常用模型提示，同时请求字段仍允许传入任意字符串，便于兼容 OpenAI 后续新模型。
 */
export type ResponsesModel = OpenAIModel | 'gpt-5.4' | 'gpt-5.3-codex' | 'gpt-4.1' | 'gpt-4o';

/**
 * Responses API 输入消息角色。
 *
 * API：`POST /v1/responses` 的 `input` 字段。
 * 说明：`developer` 和 `system` 指令优先级高于 `user`，`assistant` 用于回传历史助手消息。
 */
export type ResponseInputRole = 'user' | 'assistant' | 'system' | 'developer';

/**
 * Responses API 图像清晰度。
 *
 * API：`POST /v1/responses` 的图像输入内容。
 * 说明：`auto` 由 OpenAI 自动选择，`original` 用于要求保留原图细节的模型能力。
 */
export type ResponseImageDetail = 'low' | 'high' | 'auto' | 'original';

/**
 * 文本输入内容。
 *
 * API：`POST /v1/responses`。
 * 说明：用于多模态 message 的 `content` 数组，表示一段用户、开发者或系统文本。
 */
export interface ResponseInputText {
  /**
   * 内容类型。
   *
   * API：`POST /v1/responses`。
   * 说明：固定为 `input_text`，用于区分文本、图像和文件输入。
   */
  type: 'input_text';

  /**
   * 文本内容。
   *
   * API：`POST /v1/responses`。
   * 说明：发送给模型的自然语言、指令或上下文文本。
   */
  text: string;
}

/**
 * 图像输入内容。
 *
 * API：`POST /v1/responses`。
 * 说明：用于视觉理解场景，可通过已上传文件 ID 或 data URL/公网 URL 提供图片。
 */
export interface ResponseInputImage {
  /**
   * 内容类型。
   *
   * API：`POST /v1/responses`。
   * 说明：固定为 `input_image`。
   */
  type: 'input_image';

  /**
   * 图像细节级别。
   *
   * API：`POST /v1/responses`。
   * 说明：控制模型读取图片的细节程度；更高细节通常会消耗更多 token。
   */
  detail: ResponseImageDetail;

  /**
   * 文件 ID。
   *
   * API：`POST /v1/responses`，配合 Files API。
   * 说明：传入已通过 `POST /v1/files` 上传的图片文件 ID。
   */
  file_id?: string | null;

  /**
   * 图片 URL。
   *
   * API：`POST /v1/responses`。
   * 说明：可以是完整公网 URL，也可以是 base64 data URL。
   */
  image_url?: string | null;
}

/**
 * 文件输入内容。
 *
 * API：`POST /v1/responses`。
 * 说明：用于让模型读取 PDF、文本等文件，可传文件 ID、URL 或 base64 文件内容。
 */
export interface ResponseInputFile {
  /**
   * 内容类型。
   *
   * API：`POST /v1/responses`。
   * 说明：固定为 `input_file`。
   */
  type: 'input_file';

  /**
   * 文件渲染细节。
   *
   * API：`POST /v1/responses`。
   * 说明：`high` 适合需要更高质量解析的文件，`low` 适合默认低成本解析。
   */
  detail?: 'low' | 'high';

  /**
   * base64 文件内容。
   *
   * API：`POST /v1/responses`。
   * 说明：HTTP 层可将本地文件编码后填入该字段。
   */
  file_data?: string | null;

  /**
   * 文件 ID。
   *
   * API：`POST /v1/responses`，配合 Files API。
   * 说明：引用已上传文件。
   */
  file_id?: string | null;

  /**
   * 文件 URL。
   *
   * API：`POST /v1/responses`。
   * 说明：引用可访问的远程文件地址。
   */
  file_url?: string | null;

  /**
   * 文件名。
   *
   * API：`POST /v1/responses`。
   * 说明：当使用 `file_data` 时建议提供，帮助 OpenAI 判断文件类型。
   */
  filename?: string | null;
}

/**
 * Responses API 多模态输入内容。
 *
 * API：`POST /v1/responses` 的 `input[].content`。
 * 说明：一个 message 可混合文本、图像和文件内容。
 */
export type ResponseInputContent = ResponseInputText | ResponseInputImage | ResponseInputFile;

/**
 * 简化输入消息。
 *
 * API：`POST /v1/responses`。
 * 说明：贴近官方 SDK 的 easy input message，可直接传字符串内容，也可传多模态内容数组。
 */
export interface ResponseInputMessage {
  /**
   * 消息角色。
   *
   * API：`POST /v1/responses`。
   * 说明：决定指令层级和上下文身份。
   */
  role: ResponseInputRole;

  /**
   * 消息内容。
   *
   * API：`POST /v1/responses`。
   * 说明：可传字符串，或传文本/图像/文件组成的数组。
   */
  content: string | Array<ResponseInputContent>;

  /**
   * 消息类型。
   *
   * API：`POST /v1/responses`。
   * 说明：官方固定为 `message`；创建请求中可省略。
   */
  type?: 'message';

  /**
   * 助手消息阶段。
   *
   * API：`POST /v1/responses`。
   * 说明：用于 Codex 类模型保留 `commentary` 或 `final_answer` 阶段信息；用户消息不使用。
   */
  phase?: 'commentary' | 'final_answer' | null;
}

/**
 * 函数工具定义。
 *
 * API：`POST /v1/responses` 的 `tools` 字段。
 * 说明：让模型按 JSON Schema 生成函数调用参数，后续 client 层可执行本地函数。
 */
export interface ResponseFunctionTool {
  /**
   * 工具类型。
   *
   * API：`POST /v1/responses`。
   * 说明：固定为 `function`。
   */
  type: 'function';

  /**
   * 函数名。
   *
   * API：`POST /v1/responses`。
   * 说明：模型会在工具调用输出中返回该名称。
   */
  name: string;

  /**
   * 函数描述。
   *
   * API：`POST /v1/responses`。
   * 说明：告诉模型何时以及如何使用该函数。
   */
  description?: string | null;

  /**
   * 参数 JSON Schema。
   *
   * API：`POST /v1/responses`。
   * 说明：描述函数参数结构；使用 `JsonObject` 避免 ArkTS 的动态 `any`。
   */
  parameters?: JsonObject | null;

  /**
   * 是否严格遵守 schema。
   *
   * API：`POST /v1/responses`。
   * 说明：开启后模型必须按 schema 生成参数，适合结构化函数调用。
   */
  strict?: boolean | null;
}

/**
 * Web 搜索工具定义。
 *
 * API：`POST /v1/responses` 的 `tools` 字段。
 * 说明：让模型在回答时调用 OpenAI 托管的网页搜索能力。
 */
export interface ResponseWebSearchTool {
  /**
   * 工具类型。
   *
   * API：`POST /v1/responses`。
   * 说明：兼容官方当前命名，通常为 `web_search_preview`。
   */
  type: 'web_search_preview' | 'web_search_preview_2025_03_11';

  /**
   * 搜索上下文规模。
   *
   * API：`POST /v1/responses`。
   * 说明：控制搜索结果上下文多少，规模越大成本可能越高。
   */
  search_context_size?: 'low' | 'medium' | 'high';

  /**
   * 用户位置提示。
   *
   * API：`POST /v1/responses`。
   * 说明：帮助搜索返回更贴近用户地区的结果。
   */
  user_location?: JsonObject | null;
}

/**
 * 文件搜索工具定义。
 *
 * API：`POST /v1/responses` 的 `tools` 字段。
 * 说明：让模型检索 OpenAI vector store 中的文件内容。
 */
export interface ResponseFileSearchTool {
  /**
   * 工具类型。
   *
   * API：`POST /v1/responses`。
   * 说明：固定为 `file_search`。
   */
  type: 'file_search';

  /**
   * vector store ID 列表。
   *
   * API：`POST /v1/responses`。
   * 说明：模型会在这些向量库中检索相关内容。
   */
  vector_store_ids: Array<string>;

  /**
   * 最大返回结果数量。
   *
   * API：`POST /v1/responses`。
   * 说明：限制文件搜索召回条数。
   */
  max_num_results?: number;
}

/**
 * Code Interpreter 自动容器配置。
 *
 * API：`POST /v1/responses` 的 `tools[].container`。
 * 说明：让 OpenAI 自动创建或复用代码解释器容器，可附加文件和内存规格。
 */
export interface ResponseCodeInterpreterAutoContainer {
  /**
   * 容器模式。
   *
   * API：Code Interpreter tool。
   * 说明：固定为 `auto`。
   */
  type: 'auto';

  /**
   * 文件 ID 列表。
   *
   * API：Code Interpreter tool。
   * 说明：启动容器时可用的文件。
   */
  file_ids?: Array<string>;

  /**
   * 内存限制。
   *
   * API：Code Interpreter tool。
   * 说明：官方当前常见值包括 `1g`、`4g`、`16g`、`64g`。
   */
  memory_limit?: '1g' | '4g' | '16g' | '64g' | string;
}

/**
 * Code Interpreter 工具定义。
 *
 * API：`POST /v1/responses` 的 `tools` 字段。
 * 说明：让模型在 OpenAI 托管容器中编写并运行 Python。
 */
export interface ResponseCodeInterpreterTool {
  /**
   * 工具类型。
   *
   * API：Code Interpreter tool。
   * 说明：固定为 `code_interpreter`。
   */
  type: 'code_interpreter';

  /**
   * 容器配置。
   *
   * API：Code Interpreter tool。
   * 说明：可传容器 ID 字符串，或传 `{ type: "auto" }` 自动创建/复用容器。
   */
  container: string | ResponseCodeInterpreterAutoContainer;
}

/**
 * Image generation 工具定义。
 *
 * API：`POST /v1/responses` 的 `tools` 字段。
 * 说明：让模型在 Responses 流程内调用 GPT Image 模型生成或编辑图片。
 */
export interface ResponseImageGenerationTool {
  /**
   * 工具类型。
   *
   * API：Image generation tool。
   * 说明：固定为 `image_generation`。
   */
  type: 'image_generation';

  /**
   * 背景设置。
   *
   * API：Image generation tool。
   * 说明：控制透明、非透明或自动背景。
   */
  background?: 'transparent' | 'opaque' | 'auto' | null;

  /**
   * 输入保真度。
   *
   * API：Image generation tool。
   * 说明：编辑图像时控制对输入图的保留程度。
   */
  input_fidelity?: 'low' | 'high' | null;

  /**
   * 图像模型。
   *
   * API：Image generation tool。
   * 说明：通常为 GPT Image 系列模型，具体可用值以官方接口为准。
   */
  model?: string | null;

  /**
   * moderation 强度。
   *
   * API：Image generation tool。
   * 说明：控制图像生成的内容审核强度。
   */
  moderation?: 'low' | 'auto' | null;

  /**
   * 输出压缩比例。
   *
   * API：Image generation tool。
   * 说明：用于 jpeg/webp 输出格式，范围由服务端校验。
   */
  output_compression?: number | null;

  /**
   * 输出格式。
   *
   * API：Image generation tool。
   * 说明：例如 `png`、`jpeg`、`webp`。
   */
  output_format?: 'png' | 'jpeg' | 'webp' | null;

  /**
   * 流式预览图数量。
   *
   * API：Image generation tool。
   * 说明：开启 stream 后可请求 0 到 3 张 partial image。
   */
  partial_images?: 0 | 1 | 2 | 3 | number | null;

  /**
   * 质量等级。
   *
   * API：Image generation tool。
   * 说明：更高质量通常延迟和成本更高。
   */
  quality?: 'auto' | 'low' | 'medium' | 'high' | null;

  /**
   * 输出尺寸。
   *
   * API：Image generation tool。
   * 说明：例如 `1024x1024`、`1024x1536`、`1536x1024` 或 `auto`。
   */
  size?: 'auto' | '1024x1024' | '1024x1536' | '1536x1024' | string | null;
}

/**
 * MCP 工具定义。
 *
 * API：`POST /v1/responses` 的 `tools` 字段。
 * 说明：连接远程 MCP server 或预定义 connector，让模型调用外部工具。
 */
export interface ResponseMCPTool {
  /**
   * 工具类型。
   *
   * API：MCP tool。
   * 说明：固定为 `mcp`。
   */
  type: 'mcp';

  /**
   * server label。
   *
   * API：MCP tool。
   * 说明：标识要使用的 MCP server。
   */
  server_label: string;

  /**
   * server URL。
   *
   * API：MCP tool。
   * 说明：远程 MCP server 地址；与 `connector_id` 通常二选一。
   */
  server_url?: string;

  /**
   * connector ID。
   *
   * API：MCP tool。
   * 说明：预定义 connector 的标识；与 `server_url` 通常二选一。
   */
  connector_id?: string;

  /**
   * 允许调用的工具列表。
   *
   * API：MCP tool。
   * 说明：限制模型只能调用这些 MCP 工具。
   */
  allowed_tools?: Array<string>;

  /**
   * 审批策略。
   *
   * API：MCP tool。
   * 说明：可设置为总是审批、从不审批，或传入更细的官方配置对象。
   */
  require_approval?: 'always' | 'never' | JsonObject;

  /**
   * server 描述。
   *
   * API：MCP tool。
   * 说明：帮助模型理解该 MCP server 的用途。
   */
  server_description?: string;

  /**
   * 额外请求头。
   *
   * API：MCP tool。
   * 说明：连接远程 server 时使用的 header，例如业务侧鉴权信息。
   */
  headers?: Record<string, string>;
}

/**
 * 本地 shell 工具定义。
 *
 * API：`POST /v1/responses` 的 `tools` 字段。
 * 说明：让模型请求在本地环境执行命令；实际执行仍由宿主应用控制。
 */
export interface ResponseLocalShellTool {
  /**
   * 工具类型。
   *
   * API：Local shell tool。
   * 说明：固定为 `local_shell`。
   */
  type: 'local_shell';
}

/**
 * Shell 工具定义。
 *
 * API：`POST /v1/responses` 的 `tools` 字段。
 * 说明：让模型请求 shell 命令调用；适合 Codex 类执行环境。
 */
export interface ResponseShellTool {
  /**
   * 工具类型。
   *
   * API：Shell tool。
   * 说明：固定为 `shell`。
   */
  type: 'shell';
}

/**
 * Apply patch 工具定义。
 *
 * API：`POST /v1/responses` 的 `tools` 字段。
 * 说明：让模型以结构化 diff 形式请求创建、删除或更新文件。
 */
export interface ResponseApplyPatchTool {
  /**
   * 工具类型。
   *
   * API：Apply patch tool。
   * 说明：固定为 `apply_patch`。
   */
  type: 'apply_patch';
}

/**
 * Computer use 工具定义。
 *
 * API：`POST /v1/responses` 的 `tools` 字段。
 * 说明：让模型请求操作图形界面；具体环境和屏幕尺寸由宿主应用提供。
 */
export interface ResponseComputerUseTool {
  /**
   * 工具类型。
   *
   * API：Computer use tool。
   * 说明：固定为 `computer_use_preview`。
   */
  type: 'computer_use_preview';

  /**
   * 屏幕宽度。
   *
   * API：Computer use tool。
   * 说明：宿主环境提供给模型的可操作画面宽度。
   */
  display_width: number;

  /**
   * 屏幕高度。
   *
   * API：Computer use tool。
   * 说明：宿主环境提供给模型的可操作画面高度。
   */
  display_height: number;

  /**
   * 执行环境。
   *
   * API：Computer use tool。
   * 说明：例如浏览器、macOS、Windows 或 Ubuntu。
   */
  environment?: 'browser' | 'mac' | 'windows' | 'ubuntu' | string;
}

/**
 * Custom tool 定义。
 *
 * API：`POST /v1/responses` 的 `tools` 字段。
 * 说明：用于非 JSON Schema 函数的自定义工具调用格式。
 */
export interface ResponseCustomTool {
  /**
   * 工具类型。
   *
   * API：Custom tool。
   * 说明：固定为 `custom`。
   */
  type: 'custom';

  /**
   * 工具名称。
   *
   * API：Custom tool。
   * 说明：模型用该名称请求调用自定义工具。
   */
  name: string;

  /**
   * 工具描述。
   *
   * API：Custom tool。
   * 说明：帮助模型判断何时使用该工具。
   */
  description?: string | null;

  /**
   * 输入格式。
   *
   * API：Custom tool。
   * 说明：描述自定义工具接受的输入格式。
   */
  format?: JsonObject | null;
}

/**
 * Tool search 工具定义。
 *
 * API：`POST /v1/responses` 的 `tools` 字段。
 * 说明：用于让模型在可用工具集合中检索候选工具；字段保持宽松以兼容后续细化。
 */
export interface ResponseToolSearchTool {
  /**
   * 工具类型。
   *
   * API：Tool search。
   * 说明：固定为 `tool_search`。
   */
  type: 'tool_search';

  /**
   * 候选工具名称。
   *
   * API：Tool search。
   * 说明：限制模型可检索的工具名集合。
   */
  tool_names?: Array<string>;
}

/**
 * Responses API 工具。
 *
 * API：`POST /v1/responses` 的 `tools` 字段。
 * 说明：覆盖函数、网页搜索、文件搜索和 Responses 高阶内置工具。
 */
export type ResponseTool =
  ResponseFunctionTool |
  ResponseWebSearchTool |
  ResponseFileSearchTool |
  ResponseCodeInterpreterTool |
  ResponseImageGenerationTool |
  ResponseMCPTool |
  ResponseLocalShellTool |
  ResponseShellTool |
  ResponseApplyPatchTool |
  ResponseComputerUseTool |
  ResponseCustomTool |
  ResponseToolSearchTool;

/**
 * Responses API 文本输出格式。
 *
 * API：`POST /v1/responses` 的 `text.format` 字段。
 * 说明：用于普通文本或 JSON Schema 结构化输出。
 */
export interface ResponseTextFormat {
  /**
   * 输出格式类型。
   *
   * API：`POST /v1/responses`。
   * 说明：`text` 表示普通文本，`json_object` 表示 JSON 对象，`json_schema` 表示严格结构化输出。
   */
  type: 'text' | 'json_object' | 'json_schema';

  /**
   * schema 名称。
   *
   * API：`POST /v1/responses`。
   * 说明：当 `type` 为 `json_schema` 时使用，便于 OpenAI 标识该结构。
   */
  name?: string;

  /**
   * schema 描述。
   *
   * API：`POST /v1/responses`。
   * 说明：帮助模型理解结构化输出目标。
   */
  description?: string;

  /**
   * JSON Schema。
   *
   * API：`POST /v1/responses`。
   * 说明：当 `type` 为 `json_schema` 时使用。
   */
  schema?: JsonObject;

  /**
   * 是否严格匹配 schema。
   *
   * API：`POST /v1/responses`。
   * 说明：开启后输出必须符合 schema 支持的子集。
   */
  strict?: boolean | null;
}

/**
 * Responses API 文本配置。
 *
 * API：`POST /v1/responses` 的 `text` 字段。
 * 说明：控制文本输出格式和详细程度。
 */
export interface ResponseTextConfig {
  /**
   * 输出格式。
   *
   * API：`POST /v1/responses`。
   * 说明：用于纯文本、JSON object 或 JSON Schema 输出。
   */
  format?: ResponseTextFormat;

  /**
   * 文本详细程度。
   *
   * API：`POST /v1/responses`。
   * 说明：部分模型支持 `low`、`medium`、`high` 控制答案详略。
   */
  verbosity?: 'low' | 'medium' | 'high';
}

/**
 * Responses API 推理配置。
 *
 * API：`POST /v1/responses`。
 * 说明：用于 GPT-5 和 o 系列推理模型。
 */
export interface ResponseReasoningConfig {
  /**
   * 推理努力程度。
   *
   * API：`POST /v1/responses`。
   * 说明：值越高通常推理更充分，但延迟和成本也更高。
   */
  effort?: 'minimal' | 'low' | 'medium' | 'high' | 'xhigh' | null;

  /**
   * 推理摘要。
   *
   * API：`POST /v1/responses`。
   * 说明：控制是否返回模型推理摘要，具体可用值取决于模型。
   */
  summary?: 'auto' | 'concise' | 'detailed' | null;
}

/**
 * Responses moderated completions 配置。
 *
 * API：`POST /v1/responses`。
 * 说明：开启后服务端会审核输入和输出。
 */
export interface ResponseModerationConfig {
  /**
   * 审核模型。
   *
   * API：`POST /v1/responses`。
   * 说明：例如 `omni-moderation-latest`。
   */
  model: string;
}

/**
 * Responses moderated completions 结果。
 *
 * API：Responses API 响应。
 * 说明：包含输入和输出两侧的审核结果或审核错误。
 */
export interface ResponseModeration {
  /**
   * 输入审核结果。
   *
   * API：Responses API 响应。
   * 说明：可能是成功审核结果，也可能是审核错误。
   */
  input: ModerationOutcome;

  /**
   * 输出审核结果。
   *
   * API：Responses API 响应。
   * 说明：可能是成功审核结果，也可能是审核错误。
   */
  output: ModerationOutcome;
}

/**
 * 创建 Response 请求。
 *
 * API：`POST /v1/responses`。
 * 说明：官方当前推荐的统一文本、多模态、工具调用和结构化输出入口。
 */
export interface ResponseCreateParams {
  /**
   * 是否后台运行。
   *
   * API：`POST /v1/responses`。
   * 说明：适合耗时任务；后台任务可通过 retrieve 或 cancel 管理。
   */
  background?: boolean | null;

  /**
   * 输入内容。
   *
   * API：`POST /v1/responses`。
   * 说明：可传简单字符串，或传多轮、多模态输入消息数组。
   */
  input?: string | Array<ResponseInputMessage>;

  /**
   * 系统或开发者指令。
   *
   * API：`POST /v1/responses`。
   * 说明：用于设置模型行为；与 `previous_response_id` 一起使用时不会自动继承上一轮 instructions。
   */
  instructions?: string | null;

  /**
   * 最大输出 token。
   *
   * API：`POST /v1/responses`。
   * 说明：限制可见输出与推理 token 的总生成上限。
   */
  max_output_tokens?: number | null;

  /**
   * 元数据。
   *
   * API：`POST /v1/responses`。
   * 说明：用于存储业务侧可查询的键值对。
   */
  metadata?: Metadata | null;

  /**
   * 模型 ID。
   *
   * API：`POST /v1/responses`。
   * 说明：例如 `gpt-5.4`、`gpt-4.1`、`gpt-4o`。
   */
  model?: ResponsesModel;

  /**
   * Moderated completions 配置。
   *
   * API：`POST /v1/responses`。
   * 说明：开启后服务端会审核请求输入和模型输出。
   */
  moderation?: ResponseModerationConfig | null;

  /**
   * 是否允许并行工具调用。
   *
   * API：`POST /v1/responses`。
   * 说明：开启后模型可以在同一轮里请求多个工具。
   */
  parallel_tool_calls?: boolean | null;

  /**
   * 上一轮 response ID。
   *
   * API：`POST /v1/responses`。
   * 说明：用于创建多轮对话状态；不能与某些 conversation 方式同时使用。
   */
  previous_response_id?: string | null;

  /**
   * prompt cache key。
   *
   * API：`POST /v1/responses`。
   * 说明：用于把相似请求归入同一缓存桶，提升 prompt cache 命中率。
   */
  prompt_cache_key?: string;

  /**
   * 推理配置。
   *
   * API：`POST /v1/responses`。
   * 说明：仅推理模型支持。
   */
  reasoning?: ResponseReasoningConfig | null;

  /**
   * 安全标识。
   *
   * API：`POST /v1/responses`。
   * 说明：建议传入业务用户的不可逆哈希，用于滥用检测。
   */
  safety_identifier?: string;

  /**
   * 服务层级。
   *
   * API：`POST /v1/responses`。
   * 说明：控制默认、flex、priority 等处理策略，是否可用取决于账号权益。
   */
  service_tier?: 'auto' | 'default' | 'flex' | 'scale' | 'priority' | null;

  /**
   * 是否存储响应。
   *
   * API：`POST /v1/responses`。
   * 说明：开启后可通过 retrieve 获取历史响应。
   */
  store?: boolean | null;

  /**
   * 是否使用流式响应。
   *
   * API：`POST /v1/responses`。
   * 说明：开启后返回 SSE 事件流，非流式时返回完整 `ResponseObject`。
   */
  stream?: boolean | null;

  /**
   * 采样温度。
   *
   * API：`POST /v1/responses`。
   * 说明：范围通常为 0 到 2；越高越随机。
   */
  temperature?: number | null;

  /**
   * 文本输出配置。
   *
   * API：`POST /v1/responses`。
   * 说明：用于结构化输出、JSON 输出和 verbosity。
   */
  text?: ResponseTextConfig;

  /**
   * 工具选择策略。
   *
   * API：`POST /v1/responses`。
   * 说明：可传 `auto`、`none`、`required`，或具体工具选择对象；核心模型层先用 JSON object 兼容对象形态。
   */
  tool_choice?: 'none' | 'auto' | 'required' | JsonObject;

  /**
   * 工具列表。
   *
   * API：`POST /v1/responses`。
   * 说明：核心模型层覆盖 function、web search、file search。
   */
  tools?: Array<ResponseTool>;

  /**
   * nucleus sampling 参数。
   *
   * API：`POST /v1/responses`。
   * 说明：通常建议在 `temperature` 和 `top_p` 中只调整一个。
   */
  top_p?: number | null;

  /**
   * 截断策略。
   *
   * API：`POST /v1/responses`。
   * 说明：`auto` 会在超上下文时自动截断，`disabled` 会让请求失败。
   */
  truncation?: 'auto' | 'disabled' | null;

  /**
   * 旧用户标识。
   *
   * API：`POST /v1/responses`。
   * 说明：官方已建议改用 `safety_identifier` 和 `prompt_cache_key`。
   */
  user?: string;
}

/**
 * Response 输出文本。
 *
 * API：`POST /v1/responses`、`GET /v1/responses/{response_id}`。
 * 说明：模型最终文本通常也会被 SDK 汇总到 `output_text`。
 */
export interface ResponseOutputText {
  /**
   * 输出类型。
   *
   * API：Responses API 响应。
   * 说明：固定为 `output_text`。
   */
  type: 'output_text';

  /**
   * 输出文本。
   *
   * API：Responses API 响应。
   * 说明：模型生成的自然语言或结构化 JSON 字符串。
   */
  text: string;

  /**
   * 注解列表。
   *
   * API：Responses API 响应。
   * 说明：可能包含文件引用、URL 引用等；核心层以 JSON object 保留。
   */
  annotations: Array<JsonObject>;
}

/**
 * Response 拒答内容。
 *
 * API：Responses API 响应。
 * 说明：当模型因安全或策略原因拒绝回答时返回。
 */
export interface ResponseOutputRefusal {
  /**
   * 输出类型。
   *
   * API：Responses API 响应。
   * 说明：固定为 `refusal`。
   */
  type: 'refusal';

  /**
   * 拒答文本。
   *
   * API：Responses API 响应。
   * 说明：模型解释无法完成请求的原因。
   */
  refusal: string;
}

/**
 * Response 输出消息。
 *
 * API：Responses API 响应。
 * 说明：模型生成的 assistant message。
 */
export interface ResponseOutputMessage {
  /**
   * 输出项 ID。
   *
   * API：Responses API 响应。
   * 说明：用于引用该输出消息。
   */
  id: string;

  /**
   * 输出项类型。
   *
   * API：Responses API 响应。
   * 说明：固定为 `message`。
   */
  type: 'message';

  /**
   * 输出角色。
   *
   * API：Responses API 响应。
   * 说明：固定为 `assistant`。
   */
  role: 'assistant';

  /**
   * 输出状态。
   *
   * API：Responses API 响应。
   * 说明：表示该消息是否生成完成。
   */
  status: 'in_progress' | 'completed' | 'incomplete';

  /**
   * 输出内容。
   *
   * API：Responses API 响应。
   * 说明：可包含文本和拒答项。
   */
  content: Array<ResponseOutputText | ResponseOutputRefusal>;

  /**
   * 助手消息阶段。
   *
   * API：Responses API 响应。
   * 说明：Codex 类模型可能返回 `commentary` 或 `final_answer`。
   */
  phase?: 'commentary' | 'final_answer' | null;
}

/**
 * Response 函数工具调用输出项。
 *
 * API：Responses API 响应。
 * 说明：当模型请求调用自定义函数时返回。
 */
export interface ResponseFunctionToolCall {
  /**
   * 输出项类型。
   *
   * API：Responses API 响应。
   * 说明：固定为 `function_call`。
   */
  type: 'function_call';

  /**
   * 调用 ID。
   *
   * API：Responses API 响应。
   * 说明：提交工具结果时用来关联本次调用。
   */
  call_id: string;

  /**
   * 函数名。
   *
   * API：Responses API 响应。
   * 说明：对应请求中定义的 function tool 名称。
   */
  name: string;

  /**
   * 函数参数。
   *
   * API：Responses API 响应。
   * 说明：模型生成的 JSON 字符串，client 层可按 schema 解析。
   */
  arguments: string;
}

/**
 * Response 推理输出项。
 *
 * API：Responses API 响应。
 * 说明：推理模型可能返回该项；加密推理内容用于跨轮保留推理上下文。
 */
export interface ResponseReasoningItem {
  /**
   * 输出项类型。
   *
   * API：Responses API 响应。
   * 说明：固定为 `reasoning`。
   */
  type: 'reasoning';

  /**
   * 输出项 ID。
   *
   * API：Responses API 响应。
   * 说明：服务端返回时可用于追踪该 reasoning item。
   */
  id?: string;

  /**
   * 状态。
   *
   * API：Responses API 响应。
   * 说明：表示推理项是否生成完成。
   */
  status?: 'in_progress' | 'completed' | 'incomplete';

  /**
   * 推理摘要。
   *
   * API：Responses API 响应。
   * 说明：当请求 `reasoning.summary` 时可能返回。
   */
  summary?: Array<JsonObject>;

  /**
   * 加密推理内容。
   *
   * API：Responses API 响应。
   * 说明：用于在后续请求中安全回传给 OpenAI，应用层不应尝试解密。
   */
  encrypted_content?: string | null;
}

/**
 * Code Interpreter 调用输出项。
 *
 * API：Responses API 响应。
 * 说明：模型请求在容器里执行 Python 时返回。
 */
export interface ResponseCodeInterpreterToolCall {
  type: 'code_interpreter_call';
  id?: string;
  call_id?: string;
  container_id?: string;
  code?: string;
  status?: 'in_progress' | 'completed' | 'incomplete' | 'failed';
  outputs?: Array<JsonObject>;
}

/**
 * Image generation 调用输出项。
 *
 * API：Responses API 响应。
 * 说明：Responses 内置图像工具完成后返回 base64 图片或流式 partial image。
 */
export interface ResponseImageGenerationCall {
  type: 'image_generation_call';
  id?: string;
  status?: 'in_progress' | 'completed' | 'incomplete' | 'failed';
  result?: string | null;
  revised_prompt?: string | null;
}

/**
 * MCP 调用输出项。
 *
 * API：Responses API 响应。
 * 说明：模型调用 MCP server 工具时返回。
 */
export interface ResponseMCPToolCall {
  type: 'mcp_call';
  id?: string;
  call_id?: string;
  server_label?: string;
  name?: string;
  arguments?: string;
  output?: string | null;
  error?: string | null;
  status?: 'in_progress' | 'completed' | 'incomplete' | 'failed';
}

/**
 * Shell 调用输出项。
 *
 * API：Responses API 响应。
 * 说明：模型请求执行 shell 命令时返回。
 */
export interface ResponseShellToolCall {
  type: 'shell_call' | 'local_shell_call';
  id?: string;
  call_id?: string;
  command?: string;
  status?: 'in_progress' | 'completed' | 'incomplete';
}

/**
 * Apply patch 操作。
 *
 * API：Responses API 响应。
 * 说明：描述模型请求创建、删除或更新文件。
 */
export interface ResponseApplyPatchOperation {
  type: 'create_file' | 'delete_file' | 'update_file' | string;
  path: string;
  diff?: string;
}

/**
 * Apply patch 调用输出项。
 *
 * API：Responses API 响应。
 * 说明：模型请求应用文件 diff 时返回。
 */
export interface ResponseApplyPatchToolCall {
  type: 'apply_patch_call';
  id?: string;
  call_id?: string;
  operation: ResponseApplyPatchOperation;
  status?: 'in_progress' | 'completed';
}

/**
 * Responses API 输出项。
 *
 * API：Responses API 响应。
 * 说明：覆盖 message、function call、reasoning 和常见高阶工具调用；未知项仍用 JSON object 兼容。
 */
export type ResponseOutputItem =
  ResponseOutputMessage |
  ResponseFunctionToolCall |
  ResponseReasoningItem |
  ResponseCodeInterpreterToolCall |
  ResponseImageGenerationCall |
  ResponseMCPToolCall |
  ResponseShellToolCall |
  ResponseApplyPatchToolCall |
  JsonObject;

/**
 * Responses API token 用量。
 *
 * API：Responses API 响应。
 * 说明：统计输入、输出和推理 token。
 */
export interface ResponseUsage {
  /**
   * 输入 token 数。
   *
   * API：Responses API 响应。
   * 说明：包含文本、图片、文件等输入折算 token。
   */
  input_tokens: number;

  /**
   * 输出 token 数。
   *
   * API：Responses API 响应。
   * 说明：包含可见输出 token。
   */
  output_tokens: number;

  /**
   * 总 token 数。
   *
   * API：Responses API 响应。
   * 说明：输入与输出 token 总和。
   */
  total_tokens: number;

  /**
   * 输入 token 细分。
   *
   * API：Responses API 响应。
   * 说明：例如缓存命中 token 数。
   */
  input_tokens_details?: JsonObject;

  /**
   * 输出 token 细分。
   *
   * API：Responses API 响应。
   * 说明：例如 reasoning token 数。
   */
  output_tokens_details?: JsonObject;
}

/**
 * Response 对象。
 *
 * API：`POST /v1/responses`、`GET /v1/responses/{response_id}`、`POST /v1/responses/{response_id}/cancel`。
 * 说明：Responses API 的完整非流式响应。
 */
export interface ResponseObject {
  /**
   * Response ID。
   *
   * API：Responses API 响应。
   * 说明：用于 retrieve、delete、cancel 和多轮 `previous_response_id`。
   */
  id: string;

  /**
   * 对象类型。
   *
   * API：Responses API 响应。
   * 说明：固定为 `response`。
   */
  object: 'response';

  /**
   * 创建时间。
   *
   * API：Responses API 响应。
   * 说明：Unix 秒级时间戳。
   */
  created_at: number;

  /**
   * 响应状态。
   *
   * API：Responses API 响应。
   * 说明：表示任务是否完成、失败、排队或取消。
   */
  status?: 'completed' | 'failed' | 'in_progress' | 'cancelled' | 'queued' | 'incomplete';

  /**
   * 汇总输出文本。
   *
   * API：Responses API 响应。
   * 说明：官方 SDK 会把输出消息文本聚合到该字段，方便直接读取。
   */
  output_text: string;

  /**
   * 模型 ID。
   *
   * API：Responses API 响应。
   * 说明：实际生成该响应的模型。
   */
  model: string;

  /**
   * Moderated completions 审核结果。
   *
   * API：Responses API 响应。
   * 说明：仅在请求传入 moderation 配置时返回。
   */
  moderation?: ResponseModeration | null;

  /**
   * 输出项列表。
   *
   * API：Responses API 响应。
   * 说明：包含 assistant message、函数调用、内置工具调用等输出。
   */
  output: Array<ResponseOutputItem>;

  /**
   * 错误信息。
   *
   * API：Responses API 响应。
   * 说明：当模型生成失败时返回；成功时通常为 null。
   */
  error: JsonObject | null;

  /**
   * 未完成详情。
   *
   * API：Responses API 响应。
   * 说明：当响应因 token、过滤等原因不完整时返回。
   */
  incomplete_details: JsonObject | null;

  /**
   * 元数据。
   *
   * API：Responses API 响应。
   * 说明：创建请求传入的 metadata。
   */
  metadata: Metadata | null;

  /**
   * token 用量。
   *
   * API：Responses API 响应。
   * 说明：用于成本统计和上下文预算分析。
   */
  usage?: ResponseUsage | null;
}

/**
 * Responses API 流式事件。
 *
 * API：`POST /v1/responses` 设置 `stream: true`。
 * 说明：SSE 每条事件的基础形态；具体事件 payload 可通过 `type` 再细分。
 */
export interface ResponseStreamEvent {
  /**
   * 事件类型。
   *
   * API：Responses API streaming。
   * 说明：例如 `response.output_text.delta`、`response.completed`、`response.failed`。
   */
  type: string;

  /**
   * 序号。
   *
   * API：Responses API streaming。
   * 说明：用于按服务端顺序处理事件。
   */
  sequence_number?: number;

  /**
   * 文本增量。
   *
   * API：Responses API streaming。
   * 说明：文本流式输出事件中包含。
   */
  delta?: string;

  /**
   * 完整 Response。
   *
   * API：Responses API streaming。
   * 说明：完成、失败等事件可能携带最终 response 对象。
   */
  response?: ResponseObject;
}
