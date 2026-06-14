import { EventBus } from '../runtime/EventBus';
import type {
  PromptTemplateDerivation,
  PromptTemplateRecord,
  PromptTemplateRegistrationParams,
  PromptTemplateRenderedPayload,
} from './PromptTemplateModels';

/**
 * 已知 chat template 哈希值的缓存条目，用于快速匹配无需重复推导的模板。
 */
interface PromptTemplateKnownHash {
  /**
   * chat template 内容的 SHA-256 哈希值，用作缓存查找的键。
   */
  hash: string;
  /**
   * 该哈希对应的系统上下文模板名称，匹配后直接返回而无需再次推导。
   */
  context: string | null;
  /**
   * 该哈希对应的指令模板名称，匹配后直接返回而无需再次推导。
   */
  instruct: string | null;
}

/**
 * 提供Prompt 模板相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class PromptTemplateRuntime {
  /**
   * 事件总线，用于发布模板渲染完成事件通知宿主和其他 Runtime 模块。
   */
  private events: EventBus;
  /**
   * 已注册的 Prompt 模板字典，键为模板 ID，值为模板记录——由 registerTemplate 方法填充。
   */
  private templates: Map<string, PromptTemplateRecord> = new Map<string, PromptTemplateRecord>();
  private knownHashes: Array<PromptTemplateKnownHash> = [
    this.makeHash('e10ca381b1ccc5cf9db52e371f3b6651576caee0a630b452e2816b2d404d4b65', 'Llama 3 Instruct'),
    this.makeHash('5816fce10444e03c2e9ee1ef8a4a1ea61ae7e69e438613f3b17b69d0426223a4', 'Llama 3 Instruct'),
    this.makeHash('73e87b1667d87ab7d7b579107f01151b29ce7f3ccdd1018fdc397e78be76219d', 'Llama 3 Instruct'),
    this.makeHash('e16746b40344d6c5b5265988e0328a0bf7277be86f1c335156eae07e29c82826', 'Mistral V2 & V3'),
    this.makeHash('26a59556925c987317ce5291811ba3b7f32ec4c647c400c6cc7e3a9993007ba7', 'Mistral V2 & V3'),
    this.makeHash('e4676cb56dffea7782fd3e2b577cfaf1e123537e6ef49b3ec7caa6c095c62272', 'Mistral V3-Tekken'),
    this.makeHash('3c4ad5fa60dd8c7ccdf82fa4225864c903e107728fcaf859fa6052cb80c92ee9', 'Mistral V7'),
    this.makeHash('3934d199bfe5b6fab5cba1b5f8ee475e8d5738ac315f21cb09545b4e665cc005', 'Mistral V7'),
    this.makeHash('ecd6ae513fe103f0eb62e8ab5bfa8d0fe45c1074fa398b089c93a7e70c15cfd6', 'Gemma 2'),
    this.makeHash('87fa45af6cdc3d6a9e4dd34a0a6848eceaa73a35dcfe976bd2946a5822a38bf3', 'Gemma 2'),
    this.makeHash('7de1c58e208eda46e9c7f86397df37ec49883aeece39fb961e0a6b24088dd3c4', 'Gemma 2'),
    this.makeHash('3b54f5c219ae1caa5c0bb2cdc7c001863ca6807cf888e4240e8739fa7eb9e02e', 'Command R'),
    this.makeHash('ac7498a36a719da630e99d48e6ebc4409de85a77556c2b6159eeb735bcbd11df', 'Tulu'),
    this.makeHash('54d400beedcd17f464e10063e0577f6f798fa896266a912d8a366f8a2fcc0bca', 'DeepSeek-V2.5'),
    this.makeHash('b6835114b7303ddd78919a82e4d9f7d8c26ed0d7dfc36beeb12d524f6144eab1', 'DeepSeek-V2.5'),
    this.makeHash('854b703e44ca06bdb196cc471c728d15dbab61e744fe6cdce980086b61646ed1', 'GLM-4'),
    this.makeHash('aab20feb9bc6881f941ea649356130ffbc4943b3c2577c0991e1fba90de5a0fc', 'Moonshot AI'),
    this.makeHash('70da0d2348e40aaf8dad05f04a316835fd10547bd7e3392ce337e4c79ba91c01', 'OpenAI Harmony'),
    this.makeHash('a4c9919cbbd4acdd51ccffe22da049264b1b73e59055fa58811a99efbd7c8146', 'OpenAI Harmony'),
  ];

  /**
   * 初始化当前运行时实例，清空模板字典。
   * @param events 事件总线实例，用于发布 promptTemplate.rendered 事件。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 从 chat template 字符串推导出 context 和 instruct 模板名称。
   * 优先检查已知哈希缓存，再按特征标记匹配常见模板格式（Moonshot AI、OpenAI Harmony、ChatML 等）。
   * 在连接新 LLM 获取到 chat_template 元数据时由外部模块调用。
   * @param chatTemplate LLM 返回的原始 chat_template 字符串，用于推导模板类型。
   * @param hash chat_template 内容的哈希值，用于命中已知模板缓存以跳过重复推导。
   */
  deriveTemplatesFromChatTemplate(chatTemplate: string, hash: string): PromptTemplateDerivation {
    if (chatTemplate.trim().length === 0) {
      return this.none();
    }
    const known = this.findKnownHash(hash);
    if (known !== undefined) {
      return this.cloneKnownHash(known);
    }

    if (this.containsAll(chatTemplate, ['<|im_user|>user<|im_middle|>', '<|im_assistant|>assistant<|im_middle|>', '<|im_end|>'])) {
      return this.same('Moonshot AI');
    }
    if (this.containsAll(chatTemplate, ['<|start|>user<|message|>', '<|start|>assistant<|channel|>final<|message|>', '<|end|>'])) {
      return this.same('OpenAI Harmony');
    }
    if (this.containsAll(chatTemplate, ['<|im_start|>user', '<|im_start|>assistant', '<|im_end|>'])) {
      return this.same('ChatML');
    }

    return this.none();
  }

  /**
   * 注册一个 Prompt 模板，写入内部字典以供后续渲染使用。由外部模块（如角色加载流程）在初始化时调用。
   * @param params 包含模板 ID 和模板内容的注册参数。
   */
  registerTemplate(params: PromptTemplateRegistrationParams): PromptTemplateRecord {
    if (params.id.length === 0) {
      throw new Error('Template id is required.');
    }
    const record: PromptTemplateRecord = {
      id: params.id,
      content: params.content,
    };
    this.templates.set(record.id, record);
    return this.cloneRecord(record);
  }

  /**
   * 按 ID 查询已注册的 Prompt 模板，不存在时返回 undefined。由渲染流程（renderTemplate）或 UI 预览逻辑调用。
   * @param id 模板唯一标识，与 registerTemplate 写入的 ID 对应。
   * @returns 匹配的模板记录副本，或 undefined。
   */
  getTemplate(id: string): PromptTemplateRecord | undefined {
    const record = this.templates.get(id);
    if (record === undefined) {
      return undefined;
    }
    return this.cloneRecord(record);
  }

  /**
   * 返回所有已注册模板 ID 的排序列表。用于 UI 列表展示或批量操作前的枚举。
   * @returns 按字典序排列的模板 ID 数组。
   */
  listTemplateIds(): Array<string> {
    return Array.from(this.templates.keys()).sort();
  }

  /**
   * 使用给定数据渲染模板，将模板中的 {{key}} 占位符替换为实际值，并发布渲染事件。
   * 在组装最终 Prompt 发送给 LLM 之前由格式化流程调用。
   * @param id 模板唯一标识，用于查找已注册的模板内容。
   * @param data 键值对映射，用于替换模板中的 {{key}} 占位符——键名对应 {{key}} 中的 key，值为实际文本。
   */
  renderTemplate(id: string, data: Map<string, string>): string {
    const record = this.templates.get(id);
    if (record === undefined) {
      throw new Error(`Template not found: ${id}`);
    }
    const output = this.renderContent(record.content, data);
    const payload: PromptTemplateRenderedPayload = {
      templateId: id,
      output: output,
    };
    this.events.publish<PromptTemplateRenderedPayload>('promptTemplate.rendered', payload);
    return output;
  }

  /**
   * 对给定的内容字符串执行 {{key}} 占位符替换，返回渲染后的文本。被 renderTemplate 内部调用，也可单独用于占位符替换。
   * @param content 包含 {{key}} 占位符的模板内容字符串，其中 key 将替换为 data 对应值。
   * @param data 键值对映射，用于替换占位符；缺失的键替换为空字符串。
   */
  renderContent(content: string, data: Map<string, string>): string {
    let output = '';
    let cursor = 0;
    while (cursor < content.length) {
      const start = content.indexOf('{{', cursor);
      if (start < 0) {
        output += content.substring(cursor);
        break;
      }
      const end = content.indexOf('}}', start + 2);
      if (end < 0) {
        output += content.substring(cursor);
        break;
      }
      output += content.substring(cursor, start);
        // 从模板内容中提取占位符键名：{{key}} 中被 trim 后的部分。
      const key = content.substring(start + 2, end).trim();
      const value = data.get(key);
      output += value === undefined ? '' : value;
      cursor = end + 2;
    }
    return output;
  }

  /**
   * 根据哈希值在已知模板缓存中查找匹配项，命中则返回缓存条目；否则返回 undefined。
   */
  private findKnownHash(hash: string): PromptTemplateKnownHash | undefined {
    for (let index = 0; index < this.knownHashes.length; index += 1) {
      const known = this.knownHashes[index];
      if (known.hash === hash) {
        return known;
      }
    }
    return undefined;
  }

  /**
   * 检查字符串是否包含所有指定的子串，用于识别 chat template 的格式特征。
   * @param value 待检查的 chat template 字符串。
   * @param tokens 需要在该字符串中全部出现的子串列表。
   * @returns 当所有子串都在 value 中出现时返回 true，否则返回 false。
   */
  private containsAll(value: string, tokens: Array<string>): boolean {
    for (let index = 0; index < tokens.length; index += 1) {
      if (value.indexOf(tokens[index]) < 0) {
        return false;
      }
    }
    return true;
  }
  private makeHash(hash: string, templateName: string): PromptTemplateKnownHash {
    return {
      hash: hash,
      context: templateName,
      instruct: templateName,
    };
  }
  private same(templateName: string): PromptTemplateDerivation {
    return {
      context: templateName,
      instruct: templateName,
    };
  }
  private none(): PromptTemplateDerivation {
    return {
      context: null,
      instruct: null,
    };
  }

  /**
   * 深拷贝已知哈希条目为模板推导结果，防止外部修改缓存内容。
   */
  private cloneKnownHash(known: PromptTemplateKnownHash): PromptTemplateDerivation {
    return {
      context: known.context,
      instruct: known.instruct,
    };
  }

  /**
   * 深拷贝模板记录对象，防止外部修改内部存储的原始记录。
   * @param record 待拷贝的模板记录。
   */
  private cloneRecord(record: PromptTemplateRecord): PromptTemplateRecord {
    return {
      id: record.id,
      content: record.content,
    };
  }
}
