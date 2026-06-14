import { EventBus } from '../runtime/EventBus';
import type {
  PromptTemplateDerivation,
  PromptTemplateRecord,
  PromptTemplateRegistrationParams,
  PromptTemplateRenderedPayload,
} from './PromptTemplateModels';

/**
 * 描述Prompt 模板模块在运行时交换的数据结构。
 */
interface PromptTemplateKnownHash {
  /**
   * chat_template 字符串的 SHA-256 哈希值，用于快速匹配已知模板。
   */
  hash: string;
  /**
   * 模板推导出的上下文模板名称（如 "Llama 3 Instruct"），为空表示未识别。
   */
  context: string | null;
  /**
   * 模板推导出的指令模板名称，与 context 一致时为同源模板。
   */
  instruct: string | null;
}

/**
 * 提供Prompt 模板相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class PromptTemplateRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus;
  /**
   * 已注册的模板记录映射表，以模板 id 为键维护内存索引。
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
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) {
    this.events = events;
  }

  /**
   * 根据 chat_template 原始文本和 hash 值推导 LLM 模板类型，返回 context 与 instruct 的名称或空值。
   * @param chatTemplate 来自 LLM 的 chat_template 原始字符串。
   * @param hash chat_template 的 hash 值，用于命中已知模板库。
   * @returns 包含 context 和 instruct 模板名称的推导结果；无法识别时两者均为 null。
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
   * 注册一条 prompt 模板记录，供后续渲染或导出使用。
   * @param params 包含模板 id 和 content 的参数对象。
   * @returns 注册成功后返回模板记录的只读副本。
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
   * 读取指定模板记录，不存在时返回 undefined。
   * @param id 模板唯一标识。
   * @returns 模板记录的副本；未找到时返回 undefined。
   */
  getTemplate(id: string): PromptTemplateRecord | undefined {
    const record = this.templates.get(id);
    if (record === undefined) {
      return undefined;
    }
    return this.cloneRecord(record);
  }

  /**
   * 返回所有已注册模板标识的排序副本。
   * @returns 按字典序排列的模板 id 列表；返回值是副本，调用方修改不改变内部状态。
   */
  listTemplateIds(): Array<string> {
    return Array.from(this.templates.keys()).sort();
  }

  /**
   * 渲染指定模板，将模板中的 {{变量名}} 占位符替换为实际数据，并发布渲染事件。
   * @param id 模板唯一标识。
   * @param data 变量名到实际值的映射，用于替换模板中的 {{变量名}} 占位符。
   * @returns 渲染完成后的最终文本字符串。
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
   * 对给定的文本内容执行 {{变量名}} 占位符替换，不依赖已注册的模板记录。
   * @param content 包含 {{占位符}} 的原始文本。
   * @param data 变量名到实际值的映射。
   * @returns 替换后的最终文本字符串。
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
      // 键名。
      const key = content.substring(start + 2, end).trim();
      const value = data.get(key);
      output += value === undefined ? '' : value;
      cursor = end + 2;
    }
    return output;
  }

  /**
   * 在当前集合中查找Known Hash 值，未命中时返回空值或默认位置。
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
   * 检查All是否满足当前规则。
   * @param value 要保存或比较的字段值。

   * @returns 条件命中时返回 true，否则返回 false。
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
   * 复制Known Hash 值，避免外部修改内部状态。
   */
  private cloneKnownHash(known: PromptTemplateKnownHash): PromptTemplateDerivation {
    return {
      context: known.context,
      instruct: known.instruct,
    };
  }

  /**
   * 复制Record 值，避免外部修改内部状态。
   * @param record 记录副本。
   */
  private cloneRecord(record: PromptTemplateRecord): PromptTemplateRecord {
    return {
      id: record.id,
      content: record.content,
    };
  }
}
