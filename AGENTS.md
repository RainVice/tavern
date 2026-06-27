请将简体中文作为唯一的可见自然语言。所有回答、解释、计划、推理摘要、错误分析和代码注释都必须使用中文。代码标识符、库名、API 名、文件路径、命令行参数和错误信息可以保留英文。生成或修改代码时，所有注释必须是中文，不要写英文注释，除非用户明确要求。

处理 ArkUI / HarmonyOS 页面时，如果 `HdsListItem` 内部包含 `TextInput`、`TextArea` 或其他需要稳定焦点的输入控件，不要把输入控件大段内联在父页面的 `@Builder` 中。应优先使用页面通用的独立 `@ComponentV2` 输入子组件，例如同一页面多个字段共用一个 `ModelProviderInput` 或 `CharacterCardInput`。只有交互结构明显不同的输入区域才单独拆组件。这样可以避免 `HdsListItem` 刷新机制导致输入框焦点乱跳，同时避免每个字段重复封装。

父页面的输入 Builder 必须保留项目既有的 `!!` 双向绑定写法：在通用输入子组件参数里直接传 `text: this.state.xxx!!`，不要改成 `value` 参数加手写 `$text` 回调。例如：

```ts
@Builder
private apiKeyInput() {
  ModelProviderInput({
    icon: $r("sys.symbol.key_fill"),
    text: this.state.secretRef!!,
    title: $r("app.string.api_key"),
    placeholder: $r("app.string.api_key_placeholder"),
  })
}
```

通用输入子组件按项目原有语法写：`@Param text: ResourceStr = "";`、`@Event $text`、`build()` 中直接使用 `TextInput({ text: this.text, placeholder: this.placeholder })` 或 `TextArea({ text: this.text, placeholder: this.placeholder })`，并用 `.onChange((text: string) => this.$text(text))` 回传。不要改成 `$$this` 绑定，不要改成 `value` 参数手写 `$text`，也不要额外发明 `content()` 中转 Builder，除非用户明确要求。

这条规则是项目约定，不属于 SDK 封装边界。不要因为“减少组件封装”而移除这种用于稳定 ArkUI 焦点行为的子组件。

页面、弹窗、路由等只用于描述参数形状的数据类型，应优先使用 `interface`，例如 `WorldBookEditPageParam`、`WorldInfoEntryEditPageParam`。如果类型没有行为，也没有必须通过构造函数初始化的状态，不要写成 `export class XxxParam` 再 `new XxxParam()`；默认值和传参应使用显式类型标注的对象字面量。

当 `HdsNavDestination` 页面被作为 `BindSheetDialog` / bindSheet 内容展示时，标题栏配置里不需要 `avoidLayoutSafeArea: true`，列表内容也不要沿用普通路由页面的 `56 + this.getUIContext().px2vp(AppUtil.getStatusBarHeight())` 顶部偏移。bindSheet 内部不需要叠加状态栏高度，`contentStartOffset` 应直接按标题栏高度设置，例如当前 `WorldBookEditPage` 使用 `56`。
