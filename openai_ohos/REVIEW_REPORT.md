# openai_ohos 模块代码审查报告

> 审查日期：2026-05-28
> 审查范围：`src/main/ets/` 全部源码（client/core、client/resources、models 三层，共 55 个 .ets 文件）
> 审查方式：6 个并行 opus 子代理分区审查 + 异常处理专项审查

---

## 审查总览

| 层级 | 修改文件数 | 高优问题 | 中优问题 | 低优问题 |
|------|-----------|---------|---------|---------|
| client/core | 4 | 5 | 3 | 1 |
| client/resources | 10 | 1 | ~30 | 4 |
| models | 6 | 7 | 12 | 10+ |
| **合计** | **20** | **13** | **~45** | **15+** |

---

## 一、client/core 层修改

### 1. OpenAIRequestClient.ets

**发现问题：**
1. **[高] postText 污染外部 headers** — `extraHeaders` 被直接赋值给 `headers`，后续 `headers['Content-Type'] = contentType` 修改了调用方对象
2. **[高] 重试逻辑不覆盖网络错误** — `executeRequest` 仅在 transport 返回后检查状态码，网络超时/DNS 失败等异常直接穿透，与 `maxRetries` 文档承诺不符
3. **[低] 409 不应重试** — 409 Conflict 表示资源状态冲突，重试无意义且可能放大问题

**修改内容：**
- 第 131 行：`headers = extraHeaders` → `headers = { ...extraHeaders }`（浅拷贝避免引用污染）
- 第 333-345 行：`executeRequest` 添加 try-catch，网络错误时进入重试循环；`OpenAIAPIError` 直接抛出不重试
- 第 348 行：`isRetryableStatus` 移除 `statusCode === 409`

---

### 2. OpenAIRealtimeWebSocket.ets

**发现问题：**
1. **[高] JSON.parse 无 try-catch** — 第 64 行畸形 JSON 会导致未捕获异常，可能崩溃
2. **[中] close 失败创建悬空 socket** — 第 48-50 行 `socket.close().catch` 创建新 WebSocket 实例但从未使用，资源泄漏

**修改内容：**
- 第 64 行：JSON.parse 包裹 try-catch，失败时调用 `handlers.onError`
- 第 48-50 行：close 失败不再创建新 socket，改为静默处理

---

### 3. OpenAIRealtimeWebRTC.ets

**发现问题：**
1. **[高] JSON.parse 无 try-catch** — 第 136 行，同 WebSocket 问题
2. **[高] audioSource 资源泄漏** — 第 124 行创建后未保存引用
3. **[高] connect 失败不自动清理** — 第 43-65 行中途异常时已分配资源未释放
4. **[中] data channel 缺少 onerror 处理器** — 对比 WebSocket 缺少错误事件监听

**修改内容：**
- 第 136 行：JSON.parse 包裹 try-catch
- 第 130-143 行：新增 `dataChannel.onerror` 处理器
- 第 43-65 行：`connect()` 用 try-catch 包裹，失败时自动调用 `close()` 释放资源

---

### 4. HarmonyHttpTransport.ets

**发现问题：**
1. **[中] 流错误时不调用 onDone** — 第 104-112 行 `requestInStream` reject 后仅调 onError，不调 onDone，导致调用方永远收不到"流结束"通知

**修改内容：**
- 第 104-112 行：catch 块中在 onError 之后增加 `onDone()` 调用

---

## 二、client/resources 层修改

### 5. BetaResource.ets

**发现问题：**
1. **[高] params.stream = true 副作用** — 第 182、278、285 行直接修改传入参数对象，污染调用方持有的引用

**修改内容：**
- 三处 `params.stream = true` 改为 `const streamParams = { ...params, stream: true }`，后续使用 `streamParams`

---

### 6. RealtimeResource.ets

**发现问题：**
1. **[中] connectWebSocket/connectWebRTC 修改传入 options** — 第 64-76 行直接设置 `options.apiKey` 和 `options.url`，污染调用方对象

**修改内容：**
- 方法开头 `const opts = { ...options }`，后续操作 `opts` 而非 `options`

---

### 7. OrganizationResource.ets

**发现问题：**
1. **[严重] OrganizationProjectRolesResource.buildBasePath 路径错误** — 第 730 行缺少 `/organization` 前缀，请求发送到错误端点

**修改内容：**
- `'/projects/' + encodeURIComponent(projectID) + '/roles'` → `'/organization/projects/' + encodeURIComponent(projectID) + '/roles'`

---

### 8. ModelsResource.ets

**发现问题：**
1. **[中] model 参数未 encodeURIComponent** — 第 56、61 行

**修改内容：**
- 2 处路径拼接加 `encodeURIComponent(model)`

---

### 9. ResponsesResource.ets

**发现问题：**
1. **[中] responseID 未 encodeURIComponent** — 第 60、65、71 行

**修改内容：**
- 3 处路径拼接加 `encodeURIComponent(responseID)`

---

### 10. UploadsResource.ets

**发现问题：**
1. **[中] uploadID 未 encodeURIComponent** — 第 51、57、71 行

**修改内容：**
- 3 处路径拼接加 `encodeURIComponent(uploadID)`

---

### 11. VectorStoresResource.ets

**发现问题：**
1. **[中] vectorStoreID/fileID/batchID 未 encodeURIComponent** — 共 11 处

**修改内容：**
- 11 处路径拼接全部加 `encodeURIComponent()`

---

### 12. VideosResource.ets

**发现问题：**
1. **[中] videoID/characterID 未 encodeURIComponent** — 共 6 处

**修改内容：**
- 6 处路径拼接加 `encodeURIComponent()`

---

### 13. EvalsResource.ets

**发现问题：**
1. **[中] order_by 查询参数未 encodeURIComponent** — 第 153 行手动拼接，与其他使用 `appendStringQuery` 的地方不一致

**修改内容：**
- `query.push('order_by=' + params.order_by)` → `appendStringQuery(query, 'order_by', params.order_by)`

---

### 14. WebhooksResource.ets

**发现问题：**
1. **[中] hmacSha256 catch 块吞掉所有异常** — 第 151 行加密框架错误静默返回 null，调试困难

**修改内容：**
- catch 块增加 `console.error('HMAC-SHA256 computation failed:', String(error))`

---

## 三、models 层修改

### 15. Assistants.ets

**发现问题：**
1. **[高] AssistantUpdateParams extends AssistantCreateParams** — 第 50 行继承导致 model 在更新时必填，与 API 不一致

**修改内容：**
- `AssistantUpdateParams` 改为独立接口定义，所有字段可选，`model?: OpenAIModel`

---

### 16. Chat.ets

**发现问题：**
1. **[高] ChatCompletionChunk.choices 为 Array<JsonObject>** — 第 736 行缺少结构化类型，调用方无类型提示

**修改内容：**
- 新增 `ChatCompletionChunkDelta` 和 `ChatCompletionChunkChoice` 接口
- `choices` 类型改为 `Array<ChatCompletionChunkChoice>`

---

### 17. Completions.ets

**发现问题：**
1. **[高] CompletionCreateParams.prompt 标为可选** — 第 32 行但 API 必填

**修改内容：**
- `prompt?:` → `prompt:`，去掉 `| null`

---

### 18. FineTuning.ets

**发现问题：**
1. **[高] FineTuningJobStatus 缺少 'paused'** — Resource 层有 pause/resume 方法但状态类型无 paused
2. **[中] FineTuningCheckpointPermission.object 含 | string** — 字面量失效
3. **[中] FineTuningCheckpointPermissionDeleted.object 同上**

**修改内容：**
- FineTuningJobStatus 联合添加 `'paused'`
- 两处 object 字段去掉 `| string`

---

### 19. Images.ets

**发现问题：**
1. **[高] ImagePartialImages 含 | number** — 第 25 行使字面量 0/1/2/3 完全失效
2. **[高] ImageStreamingEventBase 多字段含 | string** — 第 364-388 行 size/quality/background/output_format 字面量失效

**修改内容：**
- `0 | 1 | 2 | 3 | number` → `0 | 1 | 2 | 3`
- 4 个字段去掉 `| string`

---

### 20. Responses.ets

**发现问题：**
1. **[高] ResponseCreateParams.model 标为可选** — 第 844 行但 API 必填
2. **[高] ResponseApplyPatchOperation.type 含 | string** — 第 1236 行字面量失效

**修改内容：**
- `model?:` → `model:`
- type 字段去掉 `| string`

---

## 四、已知问题（未在本次修改，需后续关注）

### 低优先级 / 设计权衡

| 问题 | 涉及文件 | 说明 |
|------|---------|------|
| `JSON.parse(body) as Xxx` 不安全类型断言 | 全部 Resource 文件 | 统一模式，短期可接受 |
| `| string` 尾部类型退化 | 多处 models 文件 | 响应对象层保留兼容服务端扩展，请求参数层已清理 |
| `EmptyRequestBody` 局部接口冗余 | BatchesResource, BetaResource, ChatKitResource | 不影响功能 |
| ImagesResource 代码重复 | ImagesResource.ets | 3 个方法复制了 RequestUtils 已有实现 |
| BatchesResource.list() 不支持分页参数 | BatchesResource.ets | Resource 层无参但模型层已定义 BatchListParams |
| OpenAIRealtimeWebRTC audioSource 未保存引用 | OpenAIRealtimeWebRTC.ets | 依赖 track.stop() 隐式释放，取决于 WebRTC API 实现 |

---

## 五、第二轮深度审查（10 个 opus 子代理）

> 审查日期：2026-05-28
> 审查方式：10 个并行 opus 子代理，覆盖第一轮未深入的文件、验证修改回归、安全扫描、测试覆盖

### 第一轮修改回归验证

**9 个已修改文件全部通过回归验证**，未引入新 bug。重试逻辑的 try-catch 分支、浅拷贝、JSON.parse 保护等修改均逻辑正确。

---

### 5.1 client/core 层新发现

#### Types.ets

| 严重度 | 问题 | 说明 |
|--------|------|------|
| **高** | `OpenAIStream.close()` 缺状态查询 | 主动 close 后调用方无法区分"正常结束"和"主动取消"；`close()` 是同步 void 无法保证资源释放 |
| **中** | `OpenAIRequestOptions.timeout` 是死字段 | transport 实现只消费 `readTimeout` 和 `connectTimeout`，`timeout` 从未被使用 |
| **中** | `toHttpDataType` 参数为 `string` 而非 `OpenAIResponseDataType` | 丧失穷尽检查保护 |
| **中** | `request()` vs `stream()` 错误模式不一致 | 前者 Promise 报错，后者回调报错 |

#### Common.ets

| 严重度 | 问题 | 说明 |
|--------|------|------|
| **高** | `JsonFieldValue` 嵌套限制 | 只支持 2 层嵌套，无法描述函数参数 schema、JSON Schema 等真实 API payload。根因：ArkTS 不允许递归 type alias |
| **中** | 5 个 JSON 类型中 3 个从未被使用 | `JsonPrimitive`、`JsonArray`、`JsonValue` 从未被 model 引用，只有 `JsonObject` 被广泛使用 |

#### OpenAISSEParser.ets

**结论：SSE 解析器逻辑正确，无生产缺陷。** `findSeparator`、`flush()`、换行符处理、注释行过滤均经推演确认正确。仅存在理论层面的改进点（不支持 `retry:` 字段、不维护 `lastEventId`），OpenAI API 不使用这些特性，实际无影响。

#### OpenAIRealtimeWebRTC.ets

| 严重度 | 问题 | 说明 |
|--------|------|------|
| **低** | `sendEvent` 返回 `void` 而非 `Promise<void>` | 与 WebSocket 版接口签名不一致 |

---

### 5.2 client/resources 层新发现

#### ChatResource.ets

| 严重度 | 问题 | 说明 |
|--------|------|------|
| **高** | stream 方法完全缺失 | `ChatCompletionCreateParams` 有 `stream` 字段，Chunk 类型已定义，但 `ChatResource` 没有 `createStream()` 方法。对比 `BetaResource` assistants 已有流式支持 |

#### ImagesResource.ets

| 严重度 | 问题 | 说明 |
|--------|------|------|
| **高** | 3 个方法重复实现 | `textPart()`/`filePart()`/`fileNameFromPath()` 完全复制了 `RequestUtils` 中的同名函数 |
| **高** | `buildEditParts()` 遗漏父类字段 | 缺少 `background`、`moderation`、`output_compression`、`stream`、`style` 字段的序列化 |
| **中** | Content-Type 硬编码 `application/octet-stream` | 应使用正确的 MIME 类型 |

#### AudioResource.ets

| 严重度 | 问题 | 说明 |
|--------|------|------|
| **中** | `buildTranscriptionParts()` 遗漏字段 | `timestamp_granularities` 和 `stream` 未序列化到 multipart parts |

#### ContainersResource.ets

| 严重度 | 问题 | 说明 |
|--------|------|------|
| **高** | `content()` 无法处理二进制文件 | 使用 `client.get()` 返回字符串，二进制文件会损坏。应提供 `getBinary()` 选项 |

---

### 5.3 models 层新发现

#### Realtime.ets

| 严重度 | 问题 | 说明 |
|--------|------|------|
| **高** | 缺少客户端事件 `conversation.item.truncate` | 音频中断场景必需 |
| **高** | 缺少客户端事件 `output_audio_buffer.clear` | WebRTC 场景必需 |
| **高** | 缺少服务端事件 `output_audio_buffer.started/stopped/cleared` | WebRTC 必需 |
| **高** | `transcription_session.created` 不应在服务端事件联合中 | 官方 SDK 无此事件 |
| **中** | `RealtimeConversationItem.type` 的 `\| string` 退化 | 字面量联合失效 |

#### Evals.ets

| 严重度 | 问题 | 说明 |
|--------|------|------|
| **高** | `EvalDeleted.eval_id` 字段名 | 应为 `id`（与其他 Deleted 响应一致） |
| **高** | `EvalRunDeleted.run_id` 字段名 | 同上 |

#### Responses.ets（剩余问题）

| 严重度 | 问题 | 说明 |
|--------|------|------|
| **中** | 3 个 output type 字段可选性过宽 | `ResponseCodeInterpreterToolCall`/`ResponseImageGenerationCall`/`ResponseMCPToolCall` 的 `id` 应为必选 |
| **中** | `ResponseStreamEvent.type: string` 过于通用 | 应改为事件类型联合 |

#### Containers.ets / Webhooks.ets / Organization.ets / Files.ets

| 严重度 | 文件 | 问题 |
|--------|------|------|
| **中** | Containers.ets | `ContainerStatus \| string` 和 `ContainerFileSource \| string` 退化 |
| **中** | Webhooks.ets | `OpenAIWebhookEventType \| string` 退化 |
| **中** | Files.ets | `FileObject.status` 应为 `'uploaded' \| 'processed' \| 'error'` |
| **中** | Organization.ets | 8 个 List Params 未继承 `CursorPageParams` |
| **低** | Organization.ets | `OrganizationCertificateDeleted` 缺少 `deleted: boolean` 字段 |

#### Batches.ets / Moderations.ets

| 严重度 | 文件 | 问题 |
|--------|------|------|
| **中** | Batches.ets | `completion_window` 限 `'24h'`，应为 `string` |
| **中** | Moderations.ets | 缺少 `'omni-moderation-2025-02-15'` 模型枚举 |

---

### 5.4 安全扫描结果

| 扫描项 | 结果 |
|--------|------|
| eval 注入 | 安全 |
| 动态代码执行 | 安全 |
| as any 类型断言 | 安全（0 处） |
| @ts-ignore 类型压制 | 安全（0 处） |
| JSON.stringify 循环引用 | 风险低 |
| URL 拼接 SSRF/路径遍历 | 需加固（baseURL 协议校验） |
| 文件 I/O 路径注入 | 需加固（filePath 规范化） |
| null 检查覆盖 | 良好 |

**总体安全评级：良好。** 无高危漏洞。

---

### 5.5 测试覆盖评估

| 项目 | 状态 |
|------|------|
| Index.ets 导出完整性 | 通过（22 resource + 23 model 全部导出） |
| OpenAI.ets 初始化 | 通过（22 个 resource 全部实例化） |
| 现有断言正确性 | 通过（无错误断言） |
| ChatCompletionChunk 类型测试 | **缺失** |
| 多个 Resource 的 list/retrieve/update/delete 测试 | **缺失** |

---

## 六、第二轮修复记录

> 修复日期：2026-05-28
> 修复方式：7 个 opus 子代理并行修复 + 4 个 opus 子代理验证
> 总计：29 个文件修改，428 行新增，163 行删除

### 修复清单

| # | 文件 | 问题 | 修复内容 |
|---|------|------|---------|
| 1 | ChatResource.ets | stream 方法缺失 | 新增 `createStream()` 方法和 `ChatCompletionStreamHandlers` 接口 |
| 2 | Realtime.ets | 缺少 5 个事件类型 | 新增 `conversation.item.truncate`、`output_audio_buffer.clear/started/stopped/cleared`；修复 `\| string` 退化 |
| 3 | ContainersResource.ets | content() 不支持二进制 | 支持 `responseDataType: 'arraybuffer'` 分发到 `getBinary()`；补全 encodeURIComponent |
| 4 | ImagesResource.ets | 重复代码 + 遗漏字段 | 删除 3 个重复方法改用 RequestUtils；`buildEditParts` 补充 5 个父类字段 |
| 5 | Evals.ets | eval_id/run_id 字段名 | 改为 `id`；修复 3 处 `\| string` 退化；更新测试 |
| 6 | Types.ets | OpenAIStream 缺 closed | 新增 `readonly closed: boolean` 接口属性 |
| 7 | HarmonyHttpTransport.ets | HarmonyOpenAIStream 缺 closed | 通过闭包实现 `get closed()` getter |
| 8 | OpenAIRealtimeWebSocket.ets | 缺 closed getter | `_closed` + getter + connect 守卫 |
| 9 | OpenAIRealtimeWebRTC.ets | 缺 closed getter | 同上 |
| 10 | AudioResource.ets | buildTranscriptionParts 遗漏字段 | 补充 `timestamp_granularities` 和 `stream` 序列化 |
| 11 | Models.test.ets | eval_id 测试 | mock 改为 `id`，断言更新 |
| 12 | ReturnValues.test.ets | OpenAIStream mock | 添加 `closed` 属性实现 |

### 验证结果

4 个 opus 验证子代理全部通过：
- client 层 6 个文件：import 正确、streamPost 参数匹配、浅拷贝/encode/二进制分发无误
- models 层 4 个文件：事件类型完整、字段名修复正确、测试断言匹配
- 导出链路：ChatCompletionStreamHandlers + 5 个 Realtime 事件接口全部通过 Index.ets 可达
- closed getter：3 个实现类全链路贯通
