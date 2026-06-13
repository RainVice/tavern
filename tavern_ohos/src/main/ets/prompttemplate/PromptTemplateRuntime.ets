import { EventBus } from '../runtime/EventBus';
import type {
  PromptTemplateDerivation,
  PromptTemplateRecord,
  PromptTemplateRegistrationParams,
  PromptTemplateRenderedPayload,
} from './PromptTemplateModels';

interface PromptTemplateKnownHash {
  hash: string;
  context: string | null;
  instruct: string | null;
}

export class PromptTemplateRuntime {
  private events: EventBus;
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

  constructor(events: EventBus) {
    this.events = events;
  }

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

  getTemplate(id: string): PromptTemplateRecord | undefined {
    const record = this.templates.get(id);
    if (record === undefined) {
      return undefined;
    }
    return this.cloneRecord(record);
  }

  listTemplateIds(): Array<string> {
    return Array.from(this.templates.keys()).sort();
  }

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
      const key = content.substring(start + 2, end).trim();
      const value = data.get(key);
      output += value === undefined ? '' : value;
      cursor = end + 2;
    }
    return output;
  }

  private findKnownHash(hash: string): PromptTemplateKnownHash | undefined {
    for (let index = 0; index < this.knownHashes.length; index += 1) {
      const known = this.knownHashes[index];
      if (known.hash === hash) {
        return known;
      }
    }
    return undefined;
  }

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

  private cloneKnownHash(known: PromptTemplateKnownHash): PromptTemplateDerivation {
    return {
      context: known.context,
      instruct: known.instruct,
    };
  }

  private cloneRecord(record: PromptTemplateRecord): PromptTemplateRecord {
    return {
      id: record.id,
      content: record.content,
    };
  }
}
