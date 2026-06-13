# OpenOHOS-native Headless SillyTavern Runtime 完整需求文档

> 文档目标：定义一个面向 OpenOHOS / 鸿蒙应用的 **无 UI、本地文件型、开箱即用的 SillyTavern 后台运行时 SDK**。  
> 该 Runtime 负责复刻 SillyTavern 除 Web UI / DOM 渲染以外的完整后台能力，包括角色、聊天、Prompt、WorldInfo、RAG、插件、命令、流式生成、图片、TTS、ASR、翻译、导入导出、任务、备份、诊断和兼容层。  
> UI 由宿主鸿蒙应用自行实现。

---

## 0. 版本基准与信息来源

### 0.1 目标基准

- 目标上游：SillyTavern `release` 分支。
- 当前文档按官方仓库、官方文档和源码目录进行功能归纳。
- 由于 SillyTavern 持续更新，实际开发时必须固定一个上游 commit 作为 v1.0 对齐基准。

### 0.2 参考资料

- SillyTavern GitHub 仓库：<https://github.com/SillyTavern/SillyTavern>
- SillyTavern 文档：<https://docs.sillytavern.app/>
- STscript 文档：<https://docs.sillytavern.app/usage/st-script/>
- Data Bank / RAG 文档：<https://docs.sillytavern.app/usage/core-concepts/data-bank/>
- Writing Extensions 文档：<https://docs.sillytavern.app/for-contributors/writing-extensions/>
- Server Plugins 文档：<https://docs.sillytavern.app/for-contributors/server-plugins/>
- Function Calling 文档：<https://docs.sillytavern.app/for-contributors/function-calling/>

---

## 1. 项目定位

### 1.1 项目名称

建议工作名：

```text
OpenOHOS Headless Tavern Runtime
```

或：

```text
Tavern Headless Runtime for OpenHarmony
```

### 1.2 项目定义

本项目是一个：

```text
OpenOHOS-native
本地文件型
无 UI
内置后台运行时
SillyTavern-compatible
ArkTS / OpenHarmony 优先
```

的 Runtime SDK。

它不是：

```text
WebView 壳
Node.js SillyTavern Server 打包
普通聊天 SDK
PromptBuilder 工具库
单纯 OpenAI 客户端
平台无关轻量库
```

### 1.3 核心目标

实现一个可在鸿蒙应用中直接导入的本地运行时：

```text
宿主 UI
  ↓
Headless Runtime SDK
  ↓
OpenOHOS Platform Layer
  ↓
沙箱文件 / 网络 / 加密 / 媒体 / 权限 / 日志
```

Runtime 内部实现完整后台能力。宿主 UI 只负责：

```text
界面展示
用户输入
文件选择
权限申请
生命周期通知
音频播放入口
图片预览入口
RuntimeEvent 订阅
UIRequestEvent 响应
```

---

## 2. 非目标范围

以下内容不作为 SDK 内部目标：

```text
1. 不复刻 SillyTavern Web UI。
2. 不复刻 DOM / jQuery / 浏览器布局逻辑。
3. 不直接运行 Node.js server.js。
4. 不把 Express endpoint 作为内部通信方式。
5. 不要求 UI 通过 localhost HTTP 调用 Runtime。
6. 不原样复刻不受限 Node Server Plugin 权限模型。
7. 不把所有数据塞入一个大 JSON。
8. 不把 API Key 存入普通 JSON。
9. 不在业务 Runtime 中直接调用 OpenOHOS API。
```

---

## 3. 总体架构

### 3.1 分层架构

```text
Host Harmony UI
  ├─ ArkUI 页面
  ├─ 事件订阅
  ├─ UIRequest 响应
  └─ 生命周期通知

Tavern Headless Runtime SDK
  ├─ App-facing Facade
  ├─ Runtime Layer
  ├─ Internal Service Layer
  ├─ OpenOHOS Platform Layer
  ├─ Compatibility Layer
  └─ Diagnostics / Test Layer

OpenOHOS Platform
  ├─ 沙箱文件系统
  ├─ HTTP / SSE / WebSocket
  ├─ 安全存储 / 加密
  ├─ 权限系统
  ├─ 音频 / 图片 / 媒体能力
  └─ 日志能力
```

### 3.2 Runtime Layer

Runtime Layer 包含业务运行时：

```text
AppRuntime
UserRuntime
SettingsRuntime
SecretRuntime
ProfileRuntime
PresetRuntime
CharacterRuntime
PersonaRuntime
AvatarRuntime
SpriteRuntime
ExpressionRuntime
ChatRuntime
GroupRuntime
MessageRuntime
SwipeRuntime
BranchRuntime
BookmarkRuntime
AttachmentRuntime
PromptRuntime
PromptManagerRuntime
PromptTemplateRuntime
InstructRuntime
SystemPromptRuntime
AuthorNoteRuntime
PromptItemizationRuntime
PromptCompressionRuntime
MacroRuntime
VariableRuntime
CommandRuntime
STscriptRuntime
QuickReplyRuntime
RegexRuntime
WorldInfoRuntime
DataBankRuntime
DocumentRuntime
VectorRuntime
EmbeddingRuntime
RetrievalRuntime
MemoryRuntime
SummaryRuntime
GenerationRuntime
StreamingRuntime
ReasoningRuntime
ToolCallingRuntime
TokenizerRuntime
SamplerRuntime
ImageGenerationRuntime
ImageCaptionRuntime
VisionRuntime
TTSRuntime
ASRRuntime
TranslationRuntime
AudioRuntime
PluginRuntime
ExtensionCompatRuntime
ServerPluginCompatRuntime
ContentManagerRuntime
AssetRuntime
FileRuntime
BackupRuntime
ImportExportRuntime
MigrationRuntime
SearchRuntime
StatsRuntime
DiagnosticsRuntime
TaskRuntime
EventRuntime
UIBridgeRuntime
PermissionRuntime
SandboxRuntime
CapabilityRuntime
LifecycleRuntime
SchedulerRuntime
CacheRuntime
IndexRuntime
StructuredOutputRuntime
MessageFormattingRuntime
WebSearchRuntime
PackageRuntime
```

### 3.3 Internal Service Layer

内部服务层不对外作为 adapter 暴露，但业务 Runtime 不应绕过它直接调用平台 API。

```text
StorageService
FileService
JsonStore
JsonlStore
AssetStore
SecretStore
NetworkService
StreamService
CryptoService
MediaFileService
TaskStore
MigrationService
BackupService
LoggerService
LockManager
TransactionManager
EventBus
Scheduler
ErrorService
IndexService
CacheService
```

### 3.4 OpenOHOS Platform Layer

```text
OpenOHOSFileStore
OpenOHOSJsonStore
OpenOHOSJsonlStore
OpenOHOSNetworkClient
OpenOHOSStreamClient
OpenOHOSSecureStore
OpenOHOSAssetStore
OpenOHOSAudioStore
OpenOHOSPermissionBridge
OpenOHOSLogger
OpenOHOSCrypto
OpenOHOSLifecycleBridge
```

---

## 4. 数据存储需求

### 4.1 存储策略

采用本地沙箱文件存储：

```text
JSON：角色、世界书、预设、设置、连接配置、插件配置
JSONL：聊天消息、任务历史、日志、向量项
Binary：图片、音频、附件、缩略图
Index JSON：列表页摘要、快速查询索引
```

### 4.2 根目录结构

```text
tavern-data/
  app/
    manifest.json
    settings.json
    runtime-state.json

  users/
    default/
      profile.json
      settings.json

      characters/
        index.json
        <characterId>/
          character.json
          avatar.png
          sprites/
          gallery/

      personas/
        index.json
        <personaId>.json

      chats/
        index.json
        <chatId>/
          chat.json
          messages.jsonl
          branches.json
          prompt-snapshots/
          attachments/

      groups/
        index.json
        <groupId>.json

      worldbooks/
        index.json
        <worldBookId>.json

      presets/
        generation/
        instruct/
        context/
        system/

      connection-profiles/
        index.json
        <profileId>.json

      quick-replies/
        index.json
        sets/

      regex/
        index.json
        scripts/

      plugins/
        installed.json
        settings/
        data/

      databank/
        documents/
        chunks/
        index.json

      vectors/
        collections/
        metadata.json

      assets/
        images/
        audio/
        backgrounds/
        themes/
        thumbnails/

      tasks/
        active.json
        history.jsonl

      backups/
      logs/
      diagnostics/
      migrations/
```

### 4.3 文件写入要求

所有关键写入必须支持：

```text
atomic write
写前备份
写后校验
损坏恢复
并发锁
事务变更集
版本迁移
未知字段保留
```

### 4.4 JSONL 聊天

聊天消息必须用 JSONL 存储，避免大聊天文件每次全量重写。

要求：

```text
追加写入
重建 compact
按 messageId 查找
按 index 分页读取
支持 metadata header
支持 partial streaming message
支持 interrupted / failed 消息恢复
```

---

## 5. 角色系统需求

### 5.1 CharacterRuntime

必须支持：

```text
创建角色
编辑角色
删除角色
复制角色
导入角色
导出角色
角色头像
角色标签
角色排序
角色搜索
角色收藏
角色 metadata
角色扩展字段
角色 gallery
角色 sprites
角色 character book
```

### 5.2 角色卡格式

必须支持：

```text
Character Card V1
Character Card V2
PNG metadata card
WebP metadata card，如上游支持
charx
JSON 角色卡
SillyTavern raw 格式
未知 extensions 保留
round-trip 导入导出
```

### 5.3 角色数据模型

内部角色模型需与上游格式解耦：

```text
normalized fields
raw fields
extensions
schemaVersion
compatVersion
createdAt
updatedAt
sourceFormat
migrationMetadata
```

---

## 6. Persona 用户人格系统

必须实现：

```text
PersonaProfile
Persona 切换
Persona 头像
Persona 描述
Persona 名称
Persona 标签
Persona 与聊天绑定
Persona 与角色绑定
Persona 专属 Lorebook
Persona Prompt 注入策略
{{user}} 宏绑定
Persona 导入导出
```

---

## 7. 聊天系统需求

### 7.1 ChatRuntime

必须支持：

```text
创建聊天
加载聊天
删除聊天
重命名聊天
归档聊天
复制聊天
搜索聊天
聊天排序
聊天预览
聊天 metadata
聊天设置快照
聊天绑定角色
聊天绑定 Persona
聊天绑定 WorldBook
聊天绑定 Preset
聊天绑定 Connection Profile
```

### 7.2 MessageRuntime

必须支持：

```text
添加用户消息
添加助手消息
添加系统消息
编辑消息
删除消息
批量删除
隐藏消息
取消隐藏
移动消息
消息 metadata
消息 bookmark
消息评分
消息标签
消息附件
消息 reasoning
消息 tool call
消息 translation
消息 TTS audio
消息 image attachment
消息 prompt snapshot
```

### 7.3 SwipeRuntime

必须支持：

```text
多个 candidate 回复
activeSwipeIndex
创建 swipe
切换 swipe
删除 swipe
编辑 swipe
regenerate 新 swipe
streaming swipe
failed swipe
interrupted swipe
```

### 7.4 BranchRuntime / Checkpoint

必须支持：

```text
从任意消息创建 branch
从任意消息创建 checkpoint
parent chat link
chat lineage
分支切换
分支导出
分支恢复
```

### 7.5 Continue / Regenerate

必须支持：

```text
regenerate last assistant
regenerate selected message
continue current assistant
continue as append_to_current_message
continue as new continuation message
停止后继续
失败后重试
```

---

## 8. 群聊系统需求

GroupRuntime 必须支持：

```text
创建群聊
删除群聊
编辑群聊
群聊成员
群聊成员顺序
群聊角色绑定
群聊 Persona 绑定
发言者选择
发言概率 / talkativeness
自动发言
手动选择发言者
多角色 Prompt 合并
群聊 WorldInfo 合并
群聊 regenerate
群聊 continue
群聊 tool calling
群聊导入导出
```

---

## 9. 附件和媒体资源系统

### 9.1 AttachmentRuntime

必须支持：

```text
文本附件
图片附件
音频附件
视频附件
PDF 附件
HTML 附件
Markdown 附件
EPUB 附件
JSON / YAML / code 附件
generated image
tts audio
asr source audio
caption result
rag document
```

### 9.2 附件行为

```text
挂到消息
挂到角色
挂到聊天
挂到 Persona
挂到 Data Bank
挂到插件
进入 Prompt
进入 RAG
被 caption
被翻译
被删除
被导出
```

---

## 10. Prompt 系统需求

### 10.1 PromptRuntime

Prompt 不是单函数，必须实现完整 Prompt 管理系统。

```text
PromptManager
PromptPipeline
PromptSection
PromptTemplate
ContextTemplate
InstructTemplate
SystemPrompt
Author Note
Extension Prompt Injection
Tool Prompt Injection
RAG Prompt Injection
WorldInfo Prompt Injection
Attachment Prompt Injection
Reasoning Prompt Policy
Prompt Ordering
Prompt Token Budget
Prompt Compression
Prompt Debug
Prompt Snapshot
Prompt Replay
Prompt Diff
```

### 10.2 Prompt 构建输入

```text
Character
Persona
ChatSession
Messages
WorldBooks
Data Bank results
Attachments
Memory / Summary
ConnectionProfile
GenerationPreset
ContextTemplate
InstructTemplate
SystemPromptPreset
Plugin injections
Tool definitions
Capability flags
```

### 10.3 Prompt Section 类型

```text
system
character_description
personality
scenario
example_dialogue
persona
author_note
world_info
rag_context
memory_summary
attachment_context
chat_history
reasoning_context
tool_definitions
extension_prompt
post_history_instruction
user_message
assistant_prefill
```

### 10.4 Prompt 调试

每次生成必须可记录：

```text
最终 Prompt
Prompt sections
section 来源
section token 数
WorldInfo 命中
RAG 命中
插件修改记录
裁剪记录
stop strings
provider request body
response metadata
```

---

## 11. Macro 系统

MacroRuntime 必须支持：

```text
{{char}}
{{user}}
嵌套宏
参数宏
变量宏
条件宏
时间日期宏
随机宏
角色字段宏
Persona 字段宏
聊天字段宏
世界书字段宏
插件注册宏
命令调用宏
宏 autocomplete
宏诊断
未知宏策略
```

宏可应用于：

```text
Prompt
Character Card
WorldBook
Quick Reply
STscript
Regex
Image Prompt
TTS Prompt
Translation Prompt
Caption Prompt
```

---

## 12. Variable 系统

必须支持：

```text
global variables
user variables
character variables
persona variables
chat variables
group variables
message variables
plugin variables
temporary variables
pipe variables
```

要求：

```text
变量读写
变量删除
变量作用域解析
变量持久化
变量导入导出
变量宏读取
变量命令读写
插件变量隔离
```

---

## 13. Command / Slash Command / STscript

### 13.1 CommandRuntime

必须支持：

```text
命令注册
命令解析
命令参数
命令返回值
命令权限
命令 autocomplete
命令帮助
命令错误
命令取消
```

### 13.2 STscriptRuntime

必须支持：

```text
命令批处理
管道 pipe
变量
宏
条件
循环，如上游支持
UI 请求命令映射
文件命令
消息命令
角色命令
群聊命令
世界书命令
Prompt 命令
生成命令
图片命令
TTS 命令
ASR 命令
翻译命令
插件命令
任务命令
调试命令
```

### 13.3 UI 命令处理

由于 SDK 无 UI，以下命令必须转为 UIRequestEvent：

```text
popup
input
buttons
confirm
select
file picker
toast
loader
media preview
navigation
clipboard
```

---

## 14. WorldInfo / Lorebook

WorldInfoRuntime 必须支持：

```text
世界书创建
世界书编辑
世界书删除
世界书导入导出
entry 创建
entry 编辑
entry 删除
关键词触发
secondary keys
constant entry
selective entry
case sensitive
scan depth
token budget
recursive scan
insertion order
insertion position
priority
disabled entry
character book
global world book
chat world book
persona world book
semantic activation
debug trace
```

---

## 15. RAG / Data Bank / Vector Storage

### 15.1 DataBankRuntime

必须支持：

```text
global documents
character documents
chat documents
message attachment documents
plugin documents
temporary documents
document enable/disable
document metadata
document scope
document tags
document import/export
```

### 15.2 DocumentRuntime

支持文档类型：

```text
txt
markdown
json
yaml
html
pdf
epub
docx，如后续实现
web page
youtube transcript，如后续实现
message attachment
manual text
```

### 15.3 ChunkRuntime

```text
按段落切分
按句子切分
最大 chunk size
chunk overlap
自定义 delimiter
保留标题层级
保留 offset
保留 source metadata
chunk hash
重建索引
```

### 15.4 EmbeddingRuntime

```text
OpenAI-compatible embeddings
Ollama embeddings
Google embeddings
Cohere embeddings
llama.cpp embeddings
vLLM embeddings
本地 HTTP embedding
embedding model metadata
dimension 检查
provider 切换重建索引
```

### 15.5 LocalVectorStore

```text
collection
vectors.jsonl
metadata.json
cosine similarity
topK
score threshold
metadata filter
scope filter
lazy loading
index rebuild
delete by document
delete by scope
tombstone compaction
```

### 15.6 RetrievalRuntime

```text
query from last user message
query from recent chat window
query rewrite，如后续
hybrid search，如后续
rerank，如后续
MMR 去重，如后续
RAG Prompt 注入
RAG debug trace
```

---

## 16. Generation / Provider / Network

### 16.1 ProviderRuntime

内置常见 provider client：

```text
OpenAI-compatible
OpenAI
OpenRouter
Anthropic Claude
Google Gemini
Ollama
llama.cpp
Kobold / KoboldCpp
Text Generation WebUI
NovelAI
Horde
Mistral / Together / custom compatible
Azure OpenAI
Volcengine
MiniMax
nanoGPT
```

### 16.2 Provider Capability

每个 provider/model 必须声明：

```text
supportsStreaming
supportsSystemPrompt
supportsTools
supportsReasoning
supportsVisionInput
supportsImageOutput
supportsJsonSchema
supportsLogprobs
supportsSeed
supportsStopStrings
supportsAssistantPrefill
supportsTextCompletion
supportsChatCompletion
maxContext
tokenizer
```

### 16.3 Request / Response Mapper

```text
通用 LLMRequest
provider-specific request
stream chunk normalizer
tool call mapper
reasoning mapper
error mapper
usage mapper
stop sequence mapper
sampler mapper
```

---

## 17. Streaming 流式输出

StreamingRuntime 必须支持：

```text
SSE parser
raw provider stream
normalized stream chunk
stream accumulator
smooth streaming
message snapshot
partial persistence
UI event throttle
storage throttle
abort
retry
failed
interrupted
completed
reasoning_delta
text_delta
tool_call_delta
attachment_added
```

### 17.1 UI 事件

UI 不接收底层 provider chunk，只接收：

```text
message.stream.started
message.stream.delta
message.stream.snapshot
message.stream.reasoning_delta
message.stream.tool_call_delta
message.stream.completed
message.stream.failed
task.updated
```

---

## 18. Reasoning

ReasoningRuntime 必须支持：

```text
message.reasoning
reasoning metadata
reasoning signature
reasoning visibility
reasoning prompt policy
reasoning parser
reasoning formatter
reasoning streaming accumulator
reasoning display event
reasoning edit
reasoning copy
reasoning include/exclude from prompt
```

---

## 19. Tool Calling / Function Calling

ToolCallingRuntime 必须支持：

```text
ToolRegistry
ToolSchema
ToolPermission
ToolCallRuntime
ToolCallLoop
ToolCallRecursionGuard
ToolResultFormatter
ToolResultMessage
Stealth Tool Call
Tool follow-up generation
Tool error handling
Tool event trace
```

工具来源：

```text
内置工具
插件注册工具
STscript 注册工具
WebSearch 工具
ImageGeneration 工具
TTS 工具
ASR 工具
RAG 工具
Memory 工具
```

---

## 20. Plugin / Extension / Server Plugin Compat

### 20.1 PluginRuntime

必须支持：

```text
插件安装
插件卸载
插件启用
插件禁用
插件更新
插件生命周期
插件设置
插件数据目录
插件权限
插件日志
插件错误隔离
插件事件监听
插件 transform hook
插件 interceptor
插件 command 注册
插件 macro 注册
插件 tool 注册
插件 prompt injection
插件 background job
```

### 20.2 Extension Compat

支持 SillyTavern UI extension 的 headless 兼容子集：

```text
manifest
settings
event bus
getContext-compatible API subset
command registration
tool registration
prompt injection
extension data
extension assets
```

不原样支持：

```text
DOM
jQuery
直接操作 Web UI
无限制网络
无限制文件系统
```

### 20.3 Server Plugin Compat

将原 Server Plugin 能力改造成受控能力：

```text
受控 service route
受控 command
受控 tool
受控 background job
受控 storage scope
受控 network policy
```

---

## 21. Quick Reply

QuickReplyRuntime 必须支持：

```text
quick reply set
quick reply item
按钮展示数据
执行命令
执行 STscript
自动触发
条件显示
作用域：global / chat / character / group / plugin
导入导出
插件注册 quick reply
```

---

## 22. Regex

RegexRuntime 必须支持：

```text
regex script
查找替换
作用域
placement
ephemerality
显示前替换
保存前替换
Prompt 前替换
模型输出后替换
reasoning 替换
TTS 前替换
翻译前后替换
debug trace
```

---

## 23. 多媒体 Runtime

### 23.1 ImageGenerationRuntime

```text
Stable Diffusion WebUI
ComfyUI
OpenAI image
Workers AI image，如配置
prompt macro
negative prompt
preset
size
steps
cfg
seed
cancel task
progress
result attachment
metadata
```

### 23.2 ImageCaption / Vision

```text
图片 caption
vision model request
caption prompt macro
caption attachment
caption prompt injection
自动 caption
手动 caption
```

### 23.3 TTSRuntime

```text
message to speech
voice profile
voice list
skip code block
streaming sentence TTS，如后续
audio attachment
cache
retry
cancel
```

### 23.4 ASRRuntime

```text
audio to text
full transcript
streaming transcript，如后续
auto send after transcript
manual transcript
language metadata
confidence metadata
```

### 23.5 TranslationRuntime

```text
用户输入翻译
模型输出翻译
保留原文
保留译文
Prompt translation policy
TTS translation policy
DataBank translation policy
translation cache
```

---

## 24. Settings / Profiles / Presets / Secrets

### 24.1 SettingsRuntime

设置作用域：

```text
global
user
chat
character
group
plugin
connection profile
runtime
```

### 24.2 PresetRuntime

必须支持：

```text
generation preset
instruct preset
context template
system prompt preset
sampler preset
logit bias preset
cfg preset
reasoning preset
tool calling preset
tokenizer preset
request compression preset
导入导出
迁移
绑定到角色/聊天/群聊/profile
```

### 24.3 ConnectionProfileRuntime

必须支持保存：

```text
API type
model
server URL
secretRef
generation preset
system prompt preset
context template
instruct template
tokenizer
stop strings
reasoning formatting
tool calling settings
proxy settings
additional headers
```

### 24.4 SecretRuntime

```text
secretRef
provider binding
scope
create/update/delete/rotate
安全存储
日志脱敏
普通 JSON 不存明文 key
```

---

## 25. UI Bridge

SDK 无 UI，但必须支持 UIRequestEvent：

```text
DialogRequest
InputRequest
ConfirmRequest
SelectRequest
FilePickerRequest
ToastRequest
LoaderRequest
ProgressRequest
MediaPreviewRequest
AudioPlaybackRequest
ClipboardRequest
NavigationRequest
PermissionRequest
```

UI 根据这些请求自行展示。

---

## 26. 权限、安全、沙箱

必须实现：

```text
PermissionRuntime
PluginPermission
CommandPermission
ToolPermission
SecretPermission
StoragePermission
NetworkPermission
FilePermission
MediaPermission
UserConsentRuntime
AuditLogRuntime
SandboxRuntime
ExecutionTimeout
NetworkPolicy
FileAccessPolicy
DangerousApiBlocklist
PluginCrashIsolation
```

---

## 27. 任务系统

TaskRuntime 必须管理所有异步任务：

```text
text_generation
image_generation
image_caption
tts
asr
translation
embedding
vector_index
document_import
backup
restore
plugin_job
web_search
summary
memory_extract
```

状态：

```text
pending
running
paused
completed
failed
cancelled
interrupted
recovering
```

每个任务保存：

```text
taskId
taskType
status
input
partialOutput
progress
error
createdAt
updatedAt
retryCount
sessionId
messageId
pluginId
```

---

## 28. 备份、恢复、迁移

必须支持：

```text
完整用户数据备份
角色备份
聊天备份
世界书备份
预设备份
插件配置备份
DataBank 备份
Vector metadata 备份
媒体资源备份
迁移前备份
恢复前校验
dry run migration
rollback plan
migration report
```

---

## 29. 搜索、索引、统计

### 29.1 IndexRuntime

必须维护：

```text
角色索引
聊天索引
消息全文索引
世界书关键词索引
附件索引
插件索引
预设索引
DataBank 文档索引
任务索引
```

### 29.2 SearchRuntime

```text
搜索角色
搜索聊天
搜索消息
搜索世界书
搜索附件
搜索 Data Bank
全文搜索
标签搜索
metadata 搜索
```

### 29.3 StatsRuntime

```text
token 统计
聊天长度统计
消息数量
生成耗时
provider 错误率
RAG 命中统计
插件错误统计
存储大小
缓存大小
```

---

## 30. Diagnostics / Observability

DiagnosticsRuntime 必须支持：

```text
PromptInspector
EventInspector
PluginInspector
CommandDebugger
ScriptTrace
ToolCallTrace
StreamTrace
TaskTrace
Adapter/Provider Health Check
StorageInspector
WorldInfoDebugTrace
RagDebugTrace
ErrorReport
Diagnostic Bundle Export
```

日志策略：

```text
不记录敏感密钥
Prompt 可选脱敏
请求可选脱敏
插件日志隔离
用户可导出诊断包
```

---

## 31. i18n / 本地化

必须支持：

```text
错误消息本地化
命令帮助本地化
插件信息本地化
设置项本地化
导入导出提示本地化
UIRequest message key
LocaleRegistry
TranslationBundle
```

---

## 32. Capability Runtime

必须支持能力协商：

```text
Runtime capability
Provider capability
Model capability
Plugin capability
Tool capability
Media capability
Vector capability
FeatureGuard
UnsupportedFeatureFallback
CapabilityDiagnostics
```

---

## 33. Lifecycle Runtime

宿主 App 必须能通知：

```text
runtime.init
runtime.ready
runtime.pause
runtime.resume
runtime.shutdown
app foreground
app background
network changed
permission changed
low memory
low battery
process restored
```

Runtime 必须处理：

```text
保存 runtime-state
暂停任务
恢复任务
中断 stream
恢复 interrupted message
重建索引
刷新 secret
```

---

## 34. 兼容数据层

内部格式和 SillyTavern 原格式分离：

```text
SillyTavern raw format
  ↓
CompatCodec
  ↓
SDK normalized model
  ↓
Runtime
  ↓
CompatCodec
  ↓
SillyTavern export format
```

每个对象必须保留：

```text
normalized fields
raw fields
unknown extensions
migration metadata
compat version
schema version
```

---

## 35. Feature Parity 要求

必须维护独立对齐矩阵：

```text
Source Parity Matrix
Endpoint Service Mapping
Frontend Runtime Mapping
Extension Compatibility Mapping
STscript Command Coverage
Runtime Event Catalog
Settings Schema Dictionary
File Format Compatibility Matrix
Provider Capability Matrix
Differential Test Plan
```

---

## 36. 测试策略

### 36.1 单元测试

覆盖：

```text
JSON/JSONL store
atomic write
migration
Character codec
Chat codec
WorldBook codec
Prompt pipeline
Macro
WorldInfo
RAG
Streaming
TaskRuntime
PluginRuntime
CommandRuntime
RegexRuntime
QuickReplyRuntime
ToolCallingRuntime
```

### 36.2 Golden Snapshot

```text
Prompt snapshot
WorldInfo trace
RAG trace
provider request body
chat export
backup export
```

### 36.3 Differential Test

用同一输入对比：

```text
SillyTavern 原版
Headless Runtime
```

对比：

```text
Prompt
WorldInfo activation
RAG retrieval
request body
stop strings
stream events
chat JSONL
export file
```

---

## 37. 开发阶段

### v0.1：本地文件运行时底座

```text
FileStore
JsonStore
JsonlStore
IndexStore
AtomicWrite
RuntimeManifest
Backup
Migration
```

### v0.2：运行时基础设施

```text
EventBus
TaskRuntime
LockManager
TransactionManager
RuntimeState
ErrorRuntime
Logger
PermissionRuntime
CapabilityRuntime
```

### v0.3：角色和聊天

```text
CharacterRuntime
PersonaRuntime
ChatRuntime
MessageRuntime
AttachmentRuntime
Swipe
Branch
Checkpoint
JSONL chat storage
```

### v0.4：Prompt 和世界书

```text
PromptRuntime
PromptManager
MacroRuntime
WorldInfoRuntime
TokenBudget
PromptDebug
PromptSnapshot
```

### v0.5：文本生成和流式输出

```text
ProviderRuntime
OpenAI-compatible Client
StreamingRuntime
SSE Parser
Abort
Continue
Regenerate
Partial Persistence
Reasoning Stream
Tool Call Stream
```

### v0.6：本地 RAG

```text
DocumentRuntime
ChunkRuntime
EmbeddingRuntime
LocalVectorStore
RetrievalRuntime
RagPromptInjector
RagDebug
```

### v0.7：插件、命令、脚本

```text
PluginRuntime
HookPipeline
CommandRuntime
STscript 基础版
VariableRuntime
QuickReplyRuntime
RegexRuntime
ToolCallingRuntime
```

### v0.8：多媒体

```text
ImageGenerationRuntime
ImageCaptionRuntime
TTSRuntime
ASRRuntime
TranslationRuntime
MediaTask
MediaAttachment
```

### v0.9：兼容和迁移

```text
Character Card V1/V2
PNG metadata
charx
WorldBook
Chat JSONL
Preset
ConnectionProfile
QuickReply
Regex
Plugin Settings
Backup / Restore
```

### v1.0：完整 Headless Runtime

```text
完整本地文件存储
完整聊天系统
完整 Prompt 系统
完整流式生成
RAG
插件
命令
多媒体
导入导出
诊断
稳定 API
鸿蒙 UI 接入示例
```

---

## 38. 验收标准

v1.0 交付时必须满足：

```text
1. 不依赖 Node.js server.js。
2. 不需要 WebView 承载 SillyTavern UI。
3. Runtime 可在 OpenOHOS / 鸿蒙项目内初始化。
4. 数据完整保存在沙箱文件中。
5. 可导入常见 SillyTavern 角色卡、世界书、聊天、预设。
6. 可流式生成 AI 回复。
7. 可停止、继续、重新生成、切换 swipe。
8. 可使用 WorldInfo。
9. 可使用本地 RAG。
10. 可使用插件、命令、Quick Reply、Regex。
11. 可执行基础 STscript。
12. 可执行图片生成、Caption、TTS、ASR、翻译流程。
13. 可执行 Tool Calling。
14. 可导出 SillyTavern 兼容格式。
15. 有完整 Prompt Debug。
16. 有任务恢复和失败恢复。
17. 有备份和迁移。
18. 有诊断包导出。
19. 有 Feature Parity Matrix。
20. 有 Differential Test 基线。
```

---

## 39. 最终结论

本项目最终实现的是：

```text
OpenOHOS-native
本地文件型
无 UI
完整后台运行时
SillyTavern-compatible
```

它内部实现 SillyTavern 后台能力，数据保存到沙箱 JSON / JSONL / 二进制文件中，RAG 和向量检索本地实现，网络请求通过 OpenOHOS 平台层实现，UI 只负责调用 Runtime API、响应 UIRequestEvent、订阅 RuntimeEvent 并渲染界面。
