# SillyTavern Endpoint / Feature Parity Matrix

> 文档目标：把 SillyTavern `release` 分支中的后端 endpoint、前端 runtime 脚本、内置扩展、tokenizer/vector/png 相关源码目录，映射到 OpenOHOS Headless Runtime SDK 的实现模块。  
> 该文档用于防止全功能复刻时遗漏功能。  
> 状态字段建议在开发过程中维护为：`未开始 / 设计中 / 实现中 / 已实现 / 已测试 / 有差异 / 不复刻，重构实现`。

---

## 0. 维护规则

### 0.1 必须固定上游版本

每次开发大版本必须固定：

```text
SillyTavern branch
SillyTavern commit
SillyTavern release version
文档更新时间
```

### 0.2 状态字段

建议使用：

```text
未开始
设计中
实现中
已实现
已测试
有差异
不复刻，重构实现
```

### 0.3 对齐维度

每个功能至少对齐：

```text
上游源码位置
上游功能
Runtime 模块
本地存储位置
事件
测试类型
实现状态
差异说明
```

---

## 1. src/endpoints 映射表

| 上游 endpoint 文件/目录 | 上游功能域 | Headless Runtime 模块 | 本地文件/目录建议 | 必须实现能力 | 状态 |
|---|---|---|---|---|---|
| `src/endpoints/backends/` | 文本生成后端聚合 | ProviderRuntime | `connection-profiles/`, `presets/` | chat/text/kobold 后端请求映射 | 已实现 |
| `src/endpoints/backends/chat-completions.js` | Chat Completion 后端 | ProviderRuntime | `connection-profiles/` | OpenAI-compatible / chat-completion request mapper | 已测试 |
| `src/endpoints/backends/text-completions.js` | Text Completion 后端 | ProviderRuntime | `connection-profiles/` | text-completion prompt mapping / stop strings | 已测试 |
| `src/endpoints/backends/kobold.js` | Kobold 后端 | ProviderRuntime | `connection-profiles/` | Kobold 请求、模型、采样参数 | 已实现 |
| `src/endpoints/anthropic.js` | Claude/Anthropic API | ProviderRuntime | `connection-profiles/` | Claude messages、stream、tool、reasoning 映射 | 已实现 |
| `src/endpoints/assets.js` | 扩展/资源资产 | AssetRuntime / ContentManagerRuntime | `assets/`, `plugins/` | 资源安装、列举、删除、下载、索引 | 已测试 |
| `src/endpoints/avatars.js` | 头像资源 | AvatarRuntime / AssetRuntime | `characters/*/avatar.png`, `personas/` | 头像上传、删除、裁剪、索引 | 已测试 |
| `src/endpoints/azure.js` | Azure OpenAI | ProviderRuntime | `connection-profiles/` | Azure endpoint、deployment、secretRef | 已实现 |
| `src/endpoints/backgrounds.js` | 背景资源 | BackgroundRuntime / AssetRuntime / ThemeRuntime | `assets/backgrounds/` | 背景导入、删除、索引、主题关联 | 已测试 |
| `src/endpoints/backups.js` | 备份 | BackupRuntime / RestoreRuntime | `backups/` | 完整备份、恢复、校验、迁移前备份 | 已测试 |
| `src/endpoints/caption.js` | 图片 caption | ImageCaptionRuntime | 已实现 | 已实现 |
| `src/endpoints/characters.js` | 角色管理 | CharacterRuntime | `characters/` | CRUD、导入导出、头像、标签、排序、角色卡兼容 | 已测试 |
| `src/endpoints/chats.js` | 聊天管理 | ChatRuntime / MessageRuntime | `chats/` | JSONL 聊天、消息 CRUD、分支、swipe、导入导出 | 已测试 |
| `src/endpoints/classify.js` | 文本分类 | ExpressionRuntime | 已实现 | 已实现 |
| `src/endpoints/content-manager.js` | 内容管理 | ContentManagerRuntime | 已实现 | 已实现 |
| `src/endpoints/data-maid.js` | 数据清理 | DataCleanupRuntime | 清理无效文件、孤立资源、损坏索引 | 已实现 |
| `src/endpoints/extensions.js` | 扩展管理 | PluginRuntime / ExtensionCompatRuntime | `plugins/` | 扩展列举、安装、启用、禁用、设置 | 已实现 |
| `src/endpoints/files.js` | 文件操作 | FileRuntime / AttachmentRuntime | `assets/`, `chats/*/attachments/`, `databank/` | 文件上传、删除、读取、附件化、DataBank 接入 | 已测试 |
| `src/endpoints/google.js` | Google / Gemini | ProviderRuntime | `connection-profiles/` | Gemini 请求、stream、tool、vision、secretRef | 已实现 |
| `src/endpoints/groups.js` | 群聊 | GroupRuntime | `groups/`, `chats/` | 群聊 CRUD、成员、发言者选择、群聊 Prompt | 已测试，已补持久化闭环 |
| `src/endpoints/horde.js` | Horde API | ProviderRuntime | `connection-profiles/` | Horde 文本/图像能力、队列、状态 | 已实现 |
| `src/endpoints/image-metadata.js` | 图片 metadata | ImageMetadataRuntime | PNG / WebP metadata 读写、角色卡 metadata | 已测试 |
| `src/endpoints/images.js` | 图片文件服务 | ImageRuntime / AssetRuntime | `assets/images/`, `thumbnails/` | 图片保存、读取、缩略图、附件绑定 | 已测试 |
| `src/endpoints/minimax.js` | MiniMax API | ProviderRuntime | `connection-profiles/` | MiniMax 文本/语音能力 | 已实现 |
| `src/endpoints/moving-ui.js` | UI 布局状态 | SettingsRuntime / UIStateRuntime | `settings.json` | 保存布局状态；不复刻 DOM 行为 | 不复刻，重构实现 |
| `src/endpoints/nanogpt.js` | NanoGPT API | ProviderRuntime | `connection-profiles/` | nanoGPT 请求/模型/secretRef | 已实现 |
| `src/endpoints/novelai.js` | NovelAI API | ProviderRuntime | `connection-profiles/` | NAI 请求、采样参数、模型设置 | 已实现 |
| `src/endpoints/openai.js` | OpenAI API | ProviderRuntime | `connection-profiles/`, `secrets` | OpenAI chat/text/image/embedding 能力 | 已测试 |
| `src/endpoints/openrouter.js` | OpenRouter API | ProviderRuntime | `connection-profiles/` | OpenRouter 模型列表、请求、stream、tool | 已实现 |
| `src/endpoints/presets.js` | 预设 | PresetRuntime | `presets/` | generation/instruct/context/system preset CRUD | 已测试，已补持久化闭环 |
| `src/endpoints/quick-replies.js` | Quick Reply | QuickReplyRuntime | `quick-replies/` | quick reply set、命令绑定、导入导出 | 已测试，已补持久化闭环 |
| `src/endpoints/search.js` | 搜索 | SearchRuntime / IndexRuntime | `index.json`, `diagnostics/` | 角色/聊天/消息/文件/设置搜索 | 已测试 |
| `src/endpoints/secrets.js` | 密钥 | SecretRuntime | secure store + `secretRef` | secret CRUD、rotate、脱敏、权限控制 | 已测试，已补持久化闭环；生产建议加密存储 |
| `src/endpoints/settings.js` | 设置 | SettingsRuntime | `settings.json` | 全局/用户/聊天/插件设置读写与迁移 | 已测试，已补持久化闭环 |
| `src/endpoints/speech.js` | 语音 | TTSRuntime / ASRRuntime / AudioRuntime | `assets/audio/`, `tasks/` | TTS、ASR、voice list、音频缓存 | 已实现 |
| `src/endpoints/sprites.js` | 角色表情 / sprites | SpriteRuntime / ExpressionRuntime | `characters/*/sprites/` | sprite 上传、绑定、表情状态 | 已测试 |
| `src/endpoints/stable-diffusion.js` | 图片生成 | ImageGenerationRuntime | `assets/images/`, `tasks/` | SD/ComfyUI/图像参数、取消、结果附件 | 已实现 |
| `src/endpoints/stats.js` | 统计 | StatsRuntime | `diagnostics/`, `logs/` | token、消息、文件大小、任务统计 | 已测试 |
| `src/endpoints/themes.js` | 主题 | ThemeRuntime / SettingsRuntime | `assets/themes/`, `settings.json` | 主题导入、选择、导出；UI 自行使用 | 已测试 |
| `src/endpoints/thumbnails.js` | 缩略图 | ThumbnailRuntime / AssetRuntime | `assets/thumbnails/` | 生成、缓存、删除缩略图 | 已测试 |
| `src/endpoints/tokenizers.js` | tokenizer endpoint | TokenizerRuntime | `tokenizers/`, `cache/` | 计数、模型绑定、预算、缓存 | 已测试 |
| `src/endpoints/translate.js` | 翻译 | TranslationRuntime | `tasks/`, `cache/` | 输入/输出翻译、缓存、策略 | 已实现 |
| `src/endpoints/users-admin.js` | 用户管理 admin | UserRuntime / PermissionRuntime | `users/` | 用户管理、多用户预留、权限 | 已测试 |
| `src/endpoints/users-private.js` | 用户私有接口 | UserRuntime | `users/<id>/` | 当前用户私有数据、设置、状态 | 已测试 |
| `src/endpoints/users-public.js` | 用户公开接口 | UserRuntime | `users/` | 公开用户信息、头像、profile | 已测试 |
| `src/endpoints/vectors.js` | 向量/RAG endpoint | VectorRuntime / RagRuntime | `vectors/`, `databank/` | collection、insert、query、delete、RAG 搜索 | 已测试 |
| `src/endpoints/volcengine.js` | Volcengine API | ProviderRuntime | `connection-profiles/` | 火山引擎模型请求、secretRef | 已实现 |
| `src/endpoints/worldinfo.js` | 世界书 | WorldInfoRuntime | `worldbooks/` | worldbook CRUD、entry CRUD、导入导出、触发配置 | 已测试 |

---

## 2. src 顶层辅助模块映射表

| 上游源码 | 功能 | Runtime 模块 | 必须实现能力 | 状态 |
|---|---|---|---|---|
| `src/character-card-parser.js` | 角色卡解析 | CharacterCodecRuntime | V1/V2/PNG metadata/charx 解析 | 已实现 |
| `src/charx.js` | charx 格式 | CharacterCodecRuntime | charx 导入导出 | 已实现 |
| `src/png/` | PNG metadata | ImageMetadataRuntime / CharacterCodec | PNG chunk 读写、角色卡嵌入 | 已实现 |
| `src/tokenizers/` | tokenizer 资源 | TokenizerRuntime | Claude、Llama、Mistral、Gemma 等 tokenizer 资源支持 | 已测试 |
| `src/vectors/` | embedding providers | EmbeddingRuntime | OpenAI、Google、Cohere、Ollama、llama.cpp、vLLM 等 | 已实现 |
| `src/plugin-loader.js` | server plugin 加载 | PluginRuntime | 受控加载 | 已实现 |
| `src/private-request-filter.js` | 请求过滤 | NetworkPolicyRuntime | 私有地址过滤、插件网络权限 | 已测试 |
| `src/request-proxy.js` | 请求代理 | NetworkService / ProxyRuntime | 代理配置、请求转发 | 已测试 |
| `src/additional-headers.js` | 附加请求头 | NetworkService / ConnectionProfileRuntime | headers 配置、脱敏、作用域 | 已测试 |
| `src/server-events.js` | 服务端事件 | EventRuntime | 服务事件映射为 RuntimeEvent | 已测试 |
| `src/server-directory.js` | 目录管理 | FileRuntime | 沙箱目录初始化与路径管理 | 已测试 |
| `src/server-global.js` | 全局状态 | AppRuntime / RuntimeState | runtime manifest、全局状态 | 已测试 |
| `src/server-init.js` | 初始化 | LifecycleRuntime | init / migrate / ready | 已测试 |
| `src/server-main.js` | 主服务逻辑 | AppRuntime | 不复刻 Express，重构为 Runtime Facade | 不复刻，重构实现 |
| `src/server-startup.js` | 启动逻辑 | LifecycleRuntime | 初始化顺序、恢复、迁移 | 已测试 |
| `src/healthcheck.js` | 健康检查 | DiagnosticsRuntime | runtime health check | 已测试 |
| `src/users.js` | 用户体系 | UserRuntime | 用户 scope、多用户预留 | 已测试 |
| `src/prompt-converters.js` | Prompt 转换 | PromptRuntime | chat/text provider prompt conversion | 已实现 |
| `src/transformers.js` | Transformers | EmbeddingRuntime | 预留 | 已实现 |
| `src/byaf.js` | 安全过滤 | SecurityRuntime | 输入安全检查 | 已实现 |
| `recover.js` | 恢复 | RecoveryRuntime | 用户/密码/数据恢复语义 | 已实现 |

---

## 3. public/scripts 前端 Runtime 映射表

> 这些不是全部 UI；其中大量是业务逻辑，必须迁移到 Headless Runtime。DOM/页面渲染部分不复刻。

| 上游前端脚本 | 功能域 | Headless Runtime 模块 | 处理策略 | 状态 |
|---|---|---|---|---|
| `PromptManager.js` | Prompt 管理 | PromptManagerRuntime | 全量复刻业务逻辑 | 已实现 |
| `authors-note.js` | Author Note | AuthorNoteRuntime | 复刻 | 已测试 |
| `bookmarks.js` | 聊天书签 | BookmarkRuntime | 复刻 | 已测试 |
| `chat-backups.js` | 聊天备份 | BackupRuntime | 复刻 | 已实现 |
| `chat-templates.js` | 聊天模板 | PromptTemplateRuntime | 复刻 | 已测试 |
| `chats.js` | 聊天前端逻辑 | ChatRuntime | 不复刻, 重构实现 | 不复刻，重构实现 |
| `group-chats.js` | 群聊 | GroupRuntime | 迁移业务逻辑，去 DOM | 已实现 |
| `world-info.js` | WorldInfo | WorldInfoRuntime | 全量复刻 | 已实现 |
| `macros.js` | 宏 | MacroRuntime | 全量复刻 | 已实现 |
| `macros/` | 宏子模块 | MacroRuntime | 全量复刻 | 已实现 |
| `slash-commands.js` | Slash commands | CommandRuntime | 全量复刻 | 已实现 |
| `slash-commands/` | 命令子模块 | CommandRuntime / STscriptRuntime | 全量复刻 | 已实现 |
| `variables.js` | 变量 | VariableRuntime | 全量复刻 | 已实现 |
| `extensions.js` | 扩展框架 | PluginRuntime | 不复刻, 重构实现 | 已实现 |
| `extensions-slashcommands.js` | 扩展命令 | PluginRuntime / CommandRuntime | 复刻 | 已实现 |
| `events.js` | 事件表 | EventRuntime | 复刻并扩展 RuntimeEvent | 已测试 |
| `st-context.js` | getContext | ExtensionCompatRuntime | 复刻 headless API 子集 | 已实现 |
| `tool-calling.js` | Tool Calling | ToolCallingRuntime | 全量复刻 | 已实现 |
| `reasoning.js` | Reasoning | ReasoningRuntime | 全量复刻 | 已实现 |
| `sse-stream.js` | SSE 流 | StreamingRuntime | 全量复刻 | 已实现 |
| `streaming-display.js` | 流式显示逻辑 | StreamingRuntime / UIBridgeRuntime | 平滑策略保留，DOM 去除 | 已实现 |
| `swipe-picker.js` | swipe UI/逻辑 | SwipeRuntime | 迁移逻辑，UI 自行实现 | 已实现 |
| `itemized-prompts.js` | Prompt 分项 | PromptItemizationRuntime | 复刻 | 已实现 |
| `request-compression.js` | 请求压缩 | PromptCompressionRuntime | 复刻 | 已实现 |
| `cfg-scale.js` | CFG 参数 | SamplerRuntime | 复刻 | 已实现 |
| `logit-bias.js` | logit bias | SamplerRuntime | 复刻 | 已实现 |
| `logprobs.js` | logprobs | SamplerRuntime | 复刻 | 已实现 |
| `samplerSelect.js` | sampler 选择 | SamplerRuntime | 复刻 | 已实现 |
| `preset-manager.js` | 预设管理 | PresetRuntime | 复刻 | 已实现 |
| `textgen-settings.js` | textgen 设置 | ProviderRuntime | 不复刻, 重构实现 | 不复刻，重构实现 |
| `openai.js` | OpenAI 前端配置 | ProviderRuntime | 不复刻, 重构实现 | 不复刻，重构实现 |
| `nai-settings.js` | NovelAI 设置 | ProviderRuntime | 不复刻, 重构实现 | 不复刻，重构实现 |
| `kai-settings.js` | KoboldAI 设置 | ProviderRuntime | 不复刻, 重构实现 | 不复刻，重构实现 |
| `textgen-models.js` | TextGen 模型 | ProviderRuntime | 不复刻, 重构实现 | 不复刻，重构实现 |
| `tokenizers.js` | token 计数 | TokenizerRuntime | 复刻 | 已测试 |
| `secrets.js` | 密钥前端逻辑 | SecretRuntime | 去 UI，保留密钥生命周期 | 已实现 |
| `personas.js` | Persona | PersonaRuntime | 复刻 | 已实现 |
| `tags.js` | 标签 | TagRuntime / IndexRuntime | 复刻 | 已测试 |
| `filters.js` | 过滤 | SearchRuntime / IndexRuntime | 复刻 | 已测试 |
| `stats.js` | 统计 | StatsRuntime | 复刻 | 已测试 |
| `data-maid.js` | 数据维护 | DataCleanupRuntime | 复刻 | 已实现 |
| `scrapers.js` | 抓取 | WebScraperRuntime | 复刻 | 已实现 |
| `custom-request.js` | 自定义请求 | ProviderRuntime | 不复刻, 重构实现 | 不复刻，重构实现 |
| `server-history.js` | 服务器历史 | ConnectionProfileRuntime | 复刻 | 已实现 |
| `sysprompt.js` | 系统提示词 | SystemPromptRuntime | 复刻 | 已测试 |
| `system-messages.js` | 系统消息 | MessageRuntime | 不复刻, 重构实现 | 不复刻，重构实现 |
| `templates.js` | 模板 | PromptTemplateRuntime | 复刻 | 已测试 |
| `instruct-mode.js` | instruct mode | InstructRuntime | 复刻 | 已测试 |
| `input-md-formatting.js` | Markdown 输入格式 | MessageFormattingRuntime | 复刻 | 已实现 |
| `showdown-exclusion.js` | Markdown 排除 | MessageFormattingRuntime | 复刻 | 已实现 |
| `showdown-underscore.js` | Markdown 行为 | MessageFormattingRuntime | 复刻 | 已实现 |
| `audio-player.js` | 音频播放 | AudioRuntime / UIBridgeRuntime | 运行时管理，播放交给 UI | 已实现 |
| `backgrounds.js` | 背景 | BackgroundRuntime / AssetRuntime / ThemeRuntime | 保存状态，UI 自行使用 | 已测试 |
| `dynamic-styles.js` | 动态样式 | ThemeRuntime | 保存配置，不复刻 DOM | 不复刻，重构实现 |
| `moving-ui.js` 对应 endpoint | 移动 UI 状态 | UIStateRuntime | 保存状态，不复刻 DOM | 不复刻，重构实现 |
| `popup.js` | 弹窗 | UIBridgeRuntime | 转 UIRequestEvent | 已测试 |
| `loader.js` | 加载器 | TaskRuntime / UIBridgeRuntime | 转 task display hint | 已实现 |
| `keyboard.js` | 快捷键 | UIBridgeRuntime | UI 自行实现，Runtime 提供命令 | 不复刻，重构实现 |
| `i18n.js` | 本地化 | I18nRuntime | 复刻 | 已测试 |
| `login.js` / `user.js` | 登录/用户 | UserRuntime | 按鸿蒙应用需求实现 | 已测试 |
| `action-loader.js` | 动作加载 | CommandRuntime | 不复刻, 重构实现 | 不复刻，重构实现 |
| `action-loader-slashcommands.js` | 动作命令 | CommandRuntime | 不复刻, 重构实现 | 不复刻，重构实现 |
| `BulkEditOverlay.js` | 批量编辑 | UIBridge | 不复刻, 重构实现 | 不复刻，重构实现 |
| `setting-search.js` | 设置搜索 | SettingsRuntime | 不复刻, 重构实现 | 不复刻，重构实现 |
| `welcome-screen.js` | 欢迎页 | AppRuntime / UIBridge | UI 自行实现 | 不复刻，重构实现 |
| `a11y.js` / `browser-fixes.js` / `dom-handlers.js` / `dragdrop.js` | 浏览器 UI 辅助 | UIBridge / UI 自行实现 | 不复刻 DOM | 不复刻，重构实现 |
| `f-localStorage.js` | 浏览器存储 | StorageService | 改为沙箱文件存储 | 重构实现 |
| `power-user.js` | 高级用户设置 | SettingsRuntime | 复刻设置语义 | 已实现 |
| `constants.js` | 常量 | SharedConstants | 迁移 | 已实现 |
| `utils.js` | 通用工具 | SharedRuntimeUtils | 迁移 | 已实现 |

---

## 4. public/scripts/extensions 内置扩展映射表

| 上游扩展 | 功能 | Headless Runtime 模块 | 必须实现能力 | 状态 |
|---|---|---|---|---|
| `assets` | 扩展资产 | AssetRuntime / ContentManagerRuntime | 资源注册、下载、导入、索引 | 已实现 |
| `attachments` | 附件 | AttachmentRuntime | 消息附件、文件嵌入、Prompt/RAG 接入 | 已测试 |
| `caption` | 图片 caption | ImageCaptionRuntime / VisionRuntime | caption task、prompt、附件结果 | 已实现 |
| `connection-manager` | 连接配置 | ConnectionProfileRuntime | profile 切换、模型、模板、secretRef | 已实现 |
| `expressions` | 角色表情 | ExpressionRuntime | 表情分类、sprite 状态、消息绑定 | 已实现 |
| `gallery` | 角色图库 | GalleryRuntime | 角色 gallery、图片管理 | 已实现 |
| `memory` | 记忆/摘要 | MemoryRuntime | 聊天摘要、长期记忆、Prompt 注入 | 已实现 |
| `quick-reply` | 快捷回复 | QuickReplyRuntime / CommandRuntime | 快捷命令、脚本、自动触发 | 已实现 |
| `regex` | 正则处理 | RegexRuntime | 输入/输出/Prompt/reasoning/TTS 替换 | 已实现 |
| `stable-diffusion` | 图片生成 | ImageGenerationRuntime | SD/ComfyUI/参数/结果附件 | 已实现 |
| `third-party` | 第三方扩展 | PluginRuntime | 不复刻, 重构实现 | 不复刻，重构实现 |
| `token-counter` | Token 统计 | TokenizerRuntime | 不复刻, 重构实现 | 已实现 |
| `translate` | 翻译 | TranslationRuntime | 输入/输出翻译、缓存、策略 | 已实现 |
| `tts` | TTS | TTSRuntime / AudioRuntime | message TTS、voice、缓存、播放请求 | 已实现 |
| `vectors` | Vector Storage / RAG | VectorRuntime / RagRuntime | embedding、vector collection、检索、semantic WI | 已实现 |
| `shared.js` | 扩展共享逻辑 | PluginRuntime | 不复刻, 重构实现 | 已实现 |

---

## 5. src/vectors Embedding Provider 映射表

| 上游文件 | Embedding 来源 | Runtime 模块 | 必须实现能力 | 状态 |
|---|---|---|---|---|
| `cohere-vectors.js` | Cohere | EmbeddingRuntime | Cohere embedding 请求 | 已实现 |
| `embedding.js` | embedding 公共逻辑 | EmbeddingRuntime | provider registry、batch、错误映射 | 已实现 |
| `extras-vectors.js` | Extras embedding | EmbeddingRuntime | 兼容旧 Extras 请求 | 已实现 |
| `google-vectors.js` | Google | EmbeddingRuntime | Google embedding 请求 | 已实现 |
| `llamacpp-vectors.js` | llama.cpp | EmbeddingRuntime | llama.cpp embedding 请求 | 已实现 |
| `nomicai-vectors.js` | Nomic AI | EmbeddingRuntime | Nomic embedding 请求 | 已实现 |
| `ollama-vectors.js` | Ollama | EmbeddingRuntime | Ollama embedding 请求 | 已实现 |
| `openai-vectors.js` | OpenAI | EmbeddingRuntime | OpenAI-compatible embedding 请求 | 已实现 |
| `vllm-vectors.js` | vLLM | EmbeddingRuntime | vLLM embedding 请求 | 已实现 |

---

## 6. src/tokenizers 映射表

| 上游 tokenizer 资源 | Runtime 模块 | 用途 | 状态 |
|---|---|---|---|
| `claude.json` | TokenizerRuntime | Claude token 估算/计数 | 已测试 |
| `gemma.model` | TokenizerRuntime | Gemma tokenizer | 已测试 |
| `jamba.model` | TokenizerRuntime | Jamba tokenizer | 已测试 |
| `llama.model` | TokenizerRuntime | Llama tokenizer | 已测试 |
| `llama3.json` | TokenizerRuntime | Llama 3 tokenizer | 已测试 |
| `mistral.model` | TokenizerRuntime | Mistral tokenizer | 已测试 |
| `nerdstash.model` | TokenizerRuntime | Nerdstash tokenizer | 已测试 |
| `nerdstash_v2.model` | TokenizerRuntime | Nerdstash v2 tokenizer | 已测试 |
| `yi.model` | TokenizerRuntime | Yi tokenizer | 已测试 |

---

## 7. 文件格式兼容矩阵

| 格式 | Runtime | 导入 | 导出 | Round-trip | 未知字段保留 | 状态 |
|---|---|---|---|---|---|---|
| Character Card V1 | CharacterCodec | 必须 | 已实现 |
| Character Card V2 | CharacterCodec | 必须 | 必须 | 必须 | 是 | 已实现 |
| PNG metadata card | CharacterCodec | 必须 | 已实现 |
| WebP metadata card | CharacterCodec | 建议 | 已实现 |
| charx | CharacterCodec | 必须 | 已实现 |
| WorldBook | WorldInfoRuntime | 必须 | 必须 | 必须 | 是 | 已实现 |
| CharacterBook | CharacterCodec | 必须 | 已实现 |
| Chat JSONL | ChatRuntime | 必须 | 必须 | 必须 | 是 | 已实现 |
| Group Chat | GroupRuntime | 必须 | 必须 | 必须 | 是 | 已实现，已补持久化闭环 |
| Preset | PresetRuntime | 必须 | 必须 | 必须 | 是 | 已实现，已补持久化闭环 |
| Context Template | PromptTemplateRuntime | 必须 | 必须 | 必须 | 是 | 已测试 |
| Instruct Template | InstructRuntime | 必须 | 必须 | 必须 | 是 | 已测试 |
| System Prompt | SystemPromptRuntime | 必须 | 必须 | 必须 | 是 | 已测试 |
| Connection Profile | ConnectionProfileRuntime | 必须 | 必须 | 必须 | 是 | 已实现，已补持久化闭环 |
| Quick Reply | QuickReplyRuntime | 必须 | 必须 | 必须 | 是 | 已实现，已补持久化闭环 |
| Regex Script | RegexRuntime | 必须 | 必须 | 必须 | 是 | 已实现 |
| Plugin manifest | PluginRuntime | 已实现 | 已实现 |
| Data Bank document | DataBankRuntime | 必须 | 必须 | 必须 | 是 | 已测试 |
| Vector collection metadata | VectorRuntime | 必须 | 必须 | 可选 | 是 | 已测试 |
| Backup archive | BackupRuntime | 必须 | 必须 | 必须 | 是 | 已测试 |
| Settings snapshot | SettingsRuntime | 必须 | 必须 | 必须 | 是 | 已测试，已补持久化闭环 |

---

## 8. 功能域总览矩阵

| 功能域 | 必须实现模块 | 最小验收标准 | 状态 |
|---|---|---|---|
| 本地沙箱存储 | FileStore / JsonStore / JsonlStore | 可初始化目录、atomic write、JSONL 追加 | 已测试（内存后端） |
| Runtime 基础设施 | EventBus / TaskRuntime / LockManager | 所有异步任务有事件和状态 | 已测试 |
| 角色 | CharacterRuntime | 导入、编辑、导出角色卡 | 已实现 |
| Persona | PersonaRuntime | 切换用户人格并影响 Prompt | 已测试 |
| 聊天 | ChatRuntime / MessageRuntime | JSONL 消息、编辑、删除、恢复 | 已实现 |
| Swipe | SwipeRuntime | 多候选回复、流式 regenerate | 已测试 |
| 分支 | BranchRuntime | 从任意消息创建 branch/checkpoint | 已测试 |
| 群聊 | GroupRuntime | 多角色发言、Prompt 合并 | 已测试 |
| Prompt | PromptRuntime | sections、token budget、debug snapshot | 已实现 |
| Macro | MacroRuntime | 内置宏、变量宏、插件宏 | 已测试 |
| Variable | VariableRuntime | 多作用域变量、pipe、宏读取、导入导出 | 已测试 |
| STscript | STscriptRuntime | 命令、pipe、变量、UIRequest | 已实现 |
| Quick Reply | QuickReplyRuntime | 快捷按钮触发命令/脚本 | 已测试 |
| Regex | RegexRuntime | 多 placement 正则替换 | 已测试 |
| WorldInfo | WorldInfoRuntime | 关键词/secondary/constant/recursive | 已实现 |
| RAG | RagRuntime / VectorRuntime | 文档切分、embedding、检索、Prompt 注入 | 已实现 |
| Provider | ProviderRuntime | OpenAI-compatible stream 生成 | 已实现 |
| Streaming | StreamingRuntime | delta/snapshot/abort/partial persist | 已测试 |
| Reasoning | ReasoningRuntime | reasoning_delta 和消息字段 | 已测试 |
| Tool Calling | ToolCallingRuntime | 工具注册、调用循环、结果注入 | 已实现 |
| Tokenizer | TokenizerRuntime | 计数、模型绑定、token budget、缓存 | 已测试 |
| 图片生成 | ImageGenerationRuntime | SD/ComfyUI/OpenAI image 基础流程 | 已实现 |
| Caption | ImageCaptionRuntime | 图片 caption 后进入 Prompt | 已实现 |
| TTS | TTSRuntime | 消息转语音、音频附件 | 已实现 |
| ASR | ASRRuntime | 音频转文字、可自动发送 | 已实现 |
| 翻译 | TranslationRuntime | 输入/输出翻译、缓存 | 已实现 |
| 插件 | PluginRuntime | hook、command、tool、prompt injection | 已实现 |
| Server Plugin 兼容 | PluginRuntime | 受控 | 已实现 |
| 设置 | SettingsRuntime | schema、迁移、作用域 | 已测试 |
| 预设 | PresetRuntime | generation/instruct/context/system | 已测试 |
| 密钥 | SecretRuntime | secretRef + 安全存储 | 已测试（内存安全值仓） |
| 资产 | AssetRuntime | 图片、音频、背景、主题、缩略图 | 已测试 |
| 备份 | BackupRuntime | 完整备份和恢复 | 已测试 |
| 迁移 | MigrationRuntime | 已实现 | 已实现 |
| 诊断 | DiagnosticsRuntime | prompt/event/plugin/task trace | 已测试 |
| 搜索 | SearchRuntime | 角色/聊天/消息/文件搜索 | 已测试 |
| 统计 | StatsRuntime | token/消息/任务/provider 统计 | 已测试 |
| i18n | I18nRuntime | 错误、命令、插件、设置本地化 | 已测试 |
| 权限 | PermissionRuntime | 插件/命令/工具/密钥/文件权限 | 已测试 |
| 沙箱 | SandboxRuntime | 插件隔离、超时、访问限制 | 已实现 |
| UI Bridge | UIBridgeRuntime | popup/input/file/toast/media request | 已测试 |

---

## 9. STscript Command 覆盖矩阵模板

> 该部分需要在读取上游 `/help slash` 和 STscript 文档后逐条维护。此处定义必须覆盖的命令分类。

| 命令分类 | Runtime | 必须支持内容 | 状态 |
|---|---|---|---|
| 消息命令 | CommandRuntime | 已集成 | 已实现 |
| 聊天命令 | CommandRuntime | 已集成 | 已实现 |
| 角色命令 | CommandRuntime | 已集成 | 已实现 |
| 群聊命令 | CommandRuntime | 已集成 | 已实现 |
| 世界书命令 | CommandRuntime | 已集成 | 已实现 |
| 变量命令 | VariableRuntime / CommandRuntime | local/global/pipe 变量读写 | 已实现 |
| Prompt 命令 | CommandRuntime | 已集成 | 已实现 |
| 生成命令 | CommandRuntime | 已集成 | 已实现 |
| 图片命令 | ImageGenerationRuntime / CommandRuntime | 生图、取消、附件 | 已实现 |
| TTS 命令 | TTSRuntime / CommandRuntime | speak、stop、voice | 已实现 |
| ASR 命令 | ASRRuntime / CommandRuntime | transcript、send | 已实现 |
| 翻译命令 | TranslationRuntime / CommandRuntime | translate input/output | 已实现 |
| UI 命令 | UIBridgeRuntime / CommandRuntime | popup、input、buttons、loader、toast | 已实现 |
| 插件命令 | CommandRuntime | 已集成 | 已实现 |
| 任务命令 | CommandRuntime | 已集成 | 已实现 |
| 调试命令 | DiagnosticsRuntime / CommandRuntime | prompt trace、event trace、debug export | 已实现 |

---

## 10. Runtime Event Catalog 模板

| 事件域 | 事件示例 | Payload 必须包含 | 是否插件可监听 | 是否 UI 可订阅 | 状态 |
|---|---|---|---|---|---|
| `app.*` | `app.ready` | runtime version | 已实现 |
| `settings.*` | `settings.changed` | scope, key, old/new | 是 | 是 | 已测试 |
| `secret.*` | `secret.rotated` | secretRef, providerId | 是，受限 | 否/受限 | 已测试 |
| `character.*` | `character.updated` | characterId | 已实现 |
| `persona.*` | `persona.changed` | personaId | 是 | 是 | 已测试 |
| `chat.*` | `chat.loaded` | chatId | 已实现 |
| `group.*` | `group.member.added` | groupId, characterId | 是 | 是 | 已测试 |
| `message.*` | `message.added` | chatId | 已实现 |
| `message.swipe.*` | `message.swipe.changed` | messageId, swipeIndex | 是 | 是 | 已测试 |
| `message.reasoning.*` | `reasoning.delta` | messageId, delta, snapshot | 是 | 是 | 已测试 |
| `message.attachment.*` | `attachment.added` | messageId, attachmentId | 是 | 是 | 已测试 |
| `prompt.*` | `prompt.built` | promptId, sections, trace | 是 | 是 | 已实现 |
| `worldinfo.*` | `worldinfo.activated` | entries, matches | 是 | 是 | 已实现 |
| `rag.*` | `rag.retrieved` | query, chunks, scores | 是 | 是 | 已测试 |
| `generation.*` | `generation.started` | taskId, chatId | 是 | 是 | 已实现 |
| `stream.*` | `stream.delta` | taskId, messageId, delta, snapshot | 是 | 是 | 已实现 |
| `tool.*` | `tool.called` | toolName, args, result | 是 | 是 | 已测试 |
| `plugin.*` | `plugin.enabled` | pluginId | 已实现 |
| `command.*` | `command.executed` | command, args, result | 是 | 是 | 已测试 |
| `quickReply.*` | `quickReply.executed` | id, command | 是 | 是 | 已测试 |
| `regex.*` | `regex.applied` | scriptId, placement, diff | 是 | 是 | 已测试 |
| `image.*` | `image.generated` | taskId | 已实现 |
| `caption.*` | `caption.completed` | imageId | 已实现 |
| `tts.*` | `tts.completed` | messageId | 已实现 |
| `asr.*` | `asr.completed` | audioId | 已实现 |
| `translation.*` | `translation.completed` | text | 已实现 |
| `task.*` | `task.updated` | taskId, status, progress | 是 | 是 | 已实现 |
| `asset.*` | `asset.deleted` | assetId, type | 是 | 是 | 已测试 |
| `backup.*` | `backup.completed` | backupId, path | 是 | 是 | 已测试 |
| `import.*` | `import.completed` | type | 已实现 |
| `export.*` | `export.completed` | type | 已实现 |
| `diagnostics.*` | `diagnostics.bundle.created` | path | 是 | 是 | 已测试 |

---

## 11. 差异化实现声明

| 上游能力 | Runtime 策略 | 差异说明 |
|---|---|---|
| Web UI DOM | 不复刻 | 宿主鸿蒙 UI 自行实现 |
| jQuery 前端扩展 | 不原样复刻 | 改为 Headless Extension Compat |
| Express endpoint | 不原样复刻 | 改为 Runtime Service / Facade |
| Node server.js | 不复刻运行方式 | OpenOHOS-native Runtime |
| Server Plugin 无限权限 | 不原样复刻 | 改为受控插件权限 |
| 浏览器 localStorage | 不复刻 | 改为沙箱文件存储 |
| localhost HTTP UI 调用 | 不使用 | UI 直接调用 Runtime API |
| UI 布局/主题渲染 | 不复刻渲染 | 保存数据，UI 自行解释 |
| Loader / Popup / Input | 不直接显示 | 转 UIRequestEvent |

---

## 12. Differential Test 对齐表

| 测试输入 | 对比对象 | 期望对齐内容 | 状态 |
|---|---|---|---|
| 标准角色卡 V2 | 原版 ST vs Runtime | Character model / export | 框架依赖（需 ST 原版） |
| PNG 角色卡 | 原版 ST vs Runtime | metadata 解析 / round-trip | 框架依赖（需 ST 原版） |
| 世界书关键词 | 原版 ST vs Runtime | 激活 entry / 插入顺序 | 框架依赖（需 ST 原版） |
| 多轮聊天 | 原版 ST vs Runtime | Prompt sections / token 裁剪 | 框架依赖（需 ST 原版） |
| RAG 文档 | 原版 ST vs Runtime | topK / score / prompt injection | 框架依赖（需 ST 原版） |
| 流式 OpenAI-compatible | 原版 ST vs Runtime | chunk / snapshot / final message | 已测试（本地 SSE） |
| Regex 脚本 | 原版 ST vs Runtime | 替换结果 / placement | 已测试（本地脚本） |
| Quick Reply | 原版 ST vs Runtime | command 执行结果 | 已测试（本地命令） |
| STscript | 原版 ST vs Runtime | pipe / variable / command result | 已实现 |
| Tool Calling | 原版 ST vs Runtime | tool schema / call loop / result | 已测试（本地工具） |
| Chat JSONL export | 原版 ST vs Runtime | 文件结构 / metadata | 框架依赖（需 ST 原版） |
| Backup restore | 原版 ST vs Runtime | 数据完整性 | 框架依赖（需 ST 原版） |

---

## 13. 实施优先级

### P0：基础必做

```text
FileStore
JsonStore
JsonlStore
EventBus
TaskRuntime
LockManager
CharacterRuntime
ChatRuntime
MessageRuntime
PromptRuntime
StreamingRuntime
ProviderRuntime
WorldInfoRuntime
ImportExportRuntime
```

### P1：完整聊天体验

```text
Swipe
Branch
Checkpoint
Persona
Preset
ConnectionProfile
Secret
Tokenizer
TokenBudget
PromptDebug
Reasoning
ToolCalling
```

### P2：SillyTavern 核心生态

```text
RAG
DataBank
PluginRuntime
CommandRuntime
STscript
QuickReply
Regex
ImageGeneration
Caption
TTS
ASR
Translation
```

### P3：完整复刻和长期维护

```text
GroupRuntime
Memory
Summary
Expression
Gallery
ContentManager
PackageRuntime
ServerPluginCompat
Differential Tests
Migration
Diagnostics
Search
Stats
```

---

## 14. 验收标准

该矩阵完成度达到 v1.0 时：

```text
1. 所有 src/endpoints 文件都映射到 Runtime 模块。
2. 所有 public/scripts 业务脚本都有处理策略。
3. 所有内置 extensions 都有 Runtime 对应模块。
4. 所有数据格式都有 codec。
5. 所有核心事件都有 RuntimeEvent。
6. 所有 STscript 命令分类都有覆盖计划。
7. 所有 provider 能力有 capability matrix。
8. 所有不复刻项都有重构说明。
9. 至少有一套 differential test fixture。
10. 每个功能都有实现状态和测试状态。
```
| `instruct-mode.js` | instruct mode | InstructRuntime | 复刻 | 已测试 |
```
```
tavern_ohos/sillytavern_endpoint_feature_parity_matrix.md:189:| `instruct-mode.js` | instruct mode | InstructRuntime | 复刻 | 已测试 |
| `Instruct Template` | InstructRuntime | 必须 | 必须 | 必须 | 是 | 已测试 |
```
```
tavern_ohos/sillytavern_endpoint_feature_parity_matrix.md:285:| Instruct Template | InstructRuntime | 必须 | 必须 | 必须 | 是 | 已测试 |
