import type {
  CharacterBook, CharacterBookEntry, CharacterBookInput, CharacterCardFormat,
  CharacterCardV1, CharacterCardV2Export, CharacterCardV2ExportData,
  CharacterCardV2Input, CharacterCardV2InputData, CharacterCodecResult,
  CharxArchive,
} from './CharacterCodecModels';
import { ImageMetadataRuntime } from '../imagemetadata/ImageMetadataRuntime';

/**
 * 提供角色卡编解码相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class CharacterCodecRuntime {
  /**
   * 解析输入内容并转换为Character JSON 字符串结构。
   * @param json 外部传入的 JSON 字符串。
   */
  parseCharacterJson(json: string): CharacterCodecResult {
    const obj = JSON.parse(json) as CharacterCardV2Input;
    if (obj.spec === 'chara_card_v2') { return this.parseV2(obj); }
    if (obj.spec === 'charx') { return this.parseCharx(JSON.parse(json) as CharxArchive); }
    const v1 = JSON.parse(json) as CharacterCardV1;
    if (v1.name !== undefined) { return this.parseV1(v1); }
    throw new Error('无法识别的角色卡格式');
  }

  /**
   * 解析PngCharacterCard，非法输入会返回失败标记或空结果。
   * @param data 导入或恢复使用的序列化数据。
   */
  parsePngCharacterCard(data: ArrayBuffer): CharacterCodecResult {
    const metadata = new ImageMetadataRuntime();
    const extracted = metadata.extractCharacterCard(data);
    if (extracted.characterCardJson.length === 0) {
      throw new Error('PNG 中未找到角色卡 metadata');
    }
    const parsed = this.parseCharacterJson(extracted.characterCardJson);
    return this.withFormat(parsed, 'png_metadata', extracted.characterCardJson);
  }

  /**
   * 解析 WebP Character Card，非法输入会返回失败标记或空结果。
   * @param data 导入或恢复使用的序列化数据。
   */
  parseWebpCharacterCard(data: ArrayBuffer): CharacterCodecResult {
    const metadata = new ImageMetadataRuntime();
    const extracted = metadata.extractCharacterCard(data);
    if (extracted.characterCardJson.length === 0) {
      throw new Error('WebP 中未找到角色卡 metadata');
    }
    const parsed = this.parseCharacterJson(extracted.characterCardJson);
    return this.withFormat(parsed, 'webp_metadata', extracted.characterCardJson);
  }

  /**
   * 导出为角色卡 V2 结构，用于备份、迁移或与 SillyTavern 数据互通。
   * @param result 返回结果。
   * @returns 可持久化或可传输的导出内容。
   */
  exportToV2(result: CharacterCodecResult): string {
    const data: CharacterCardV2ExportData = {
      name: result.name, description: result.description, personality: result.personality,
      scenario: result.scenario, first_mes: result.firstMessage, mes_example: result.exampleDialogue,
      creator_notes: result.creatorNotes, system_prompt: result.systemPrompt,
      post_history_instructions: result.postHistoryInstructions,
      creator: result.creator, character_version: result.characterVersion,
      tags: result.tags, alternate_greetings: result.alternateGreetings,
      extensions: result.extensions,
    };
    const card: CharacterCardV2Export = {
      spec: 'chara_card_v2', spec_version: '2.0',
      data: data,
    };
    return JSON.stringify(card);
  }

  /**
   * 导出为 PNG 角色卡，用于备份、迁移或与 SillyTavern 数据互通。
   * @param result 返回结果。

   * @returns 可持久化或可传输的导出内容。
   */
  exportToPng(result: CharacterCodecResult, sourcePng: ArrayBuffer): ArrayBuffer {
    const metadata = new ImageMetadataRuntime();
    return metadata.writePngCharacterCard(sourcePng, this.exportToV2(result));
  }

  /**
   * 导出为 WebP 角色卡，用于备份、迁移或与 SillyTavern 数据互通。
   * @param result 返回结果。
   * @param sourceWebp 源 WebP 图片数据。
   */
  exportToWebp(result: CharacterCodecResult, sourceWebp: ArrayBuffer): ArrayBuffer {
    const metadata = new ImageMetadataRuntime();
    return metadata.writeWebpCharacterCard(sourceWebp, this.exportToV2(result));
  }

  /**
   * 识别输入数据的Format 值，供导入流程选择后续解析方式。
   * @param data 导入或恢复使用的序列化数据。
   */
  detectFormat(data: string): CharacterCardFormat {
    try { const obj = JSON.parse(data) as CharacterCardV2Input;
      if (obj.spec==='chara_card_v2') return 'v2';
      if (obj.spec==='charx') return 'charx';
      const v1 = JSON.parse(data) as CharacterCardV1;
      if (v1.name!==undefined) return 'v1';
      return 'unknown';
    } catch { return 'unknown'; }
  }

  /**
   * 识别输入数据的Binary Format 值，供导入流程选择后续解析方式。
   * @param data 导入或恢复使用的序列化数据。
   */
  detectBinaryFormat(data: ArrayBuffer): CharacterCardFormat {
    const metadata = new ImageMetadataRuntime();
    const extracted = metadata.extractCharacterCard(data);
    if (extracted.characterCardJson.length > 0) {
      if (extracted.metadata.format === 'webp') {
        return 'webp_metadata';
      }
      return 'png_metadata';
    }
    return 'unknown';
  }

  /**
   * 解析CharacterBook，非法输入会返回失败标记或空结果。
   * @param json 外部传入的 JSON 字符串。
   */
  parseCharacterBook(json: string): CharacterBook {
    const obj = JSON.parse(json) as CharacterBookInput;
    const entries = new Array<CharacterBookEntry>();
    if (obj.entries !== undefined) {
      for (let i=0;i<obj.entries.length;i++) {
        const e = obj.entries[i];
        entries.push({ id: e.id || '', keys: e.keys !== undefined ? e.keys.slice() : new Array<string>(), content: e.content || '' });
      }
    }
    return { name: obj.name || '', entries: entries };
  }

  /**
   * 导出角色Book，用于备份、迁移或与 SillyTavern 数据互通。

   * @returns 可持久化或可传输的导出内容。
   */
  exportCharacterBook(book: CharacterBook): string { return JSON.stringify(book); }

  /**
   * 解析V1，非法输入会返回失败标记或空结果。
   */
  private parseV1(card: CharacterCardV1): CharacterCodecResult {
    return { format: 'v1', raw: JSON.stringify(card), name: card.name||'', description: card.description||'',
      personality: card.personality||'', scenario: card.scenario||'', firstMessage: card.first_mes||'',
      exampleDialogue: card.mes_example||'', creatorNotes: '', systemPrompt: '', postHistoryInstructions: '',
      creator: '', characterVersion: '', tags: new Array<string>(), alternateGreetings: new Array<string>(),
      extensions: {} };
  }

  /**
   * 解析V2，非法输入会返回失败标记或空结果。
   */
  private parseV2(obj: CharacterCardV2Input): CharacterCodecResult {
    const data: CharacterCardV2InputData = obj.data !== undefined ? obj.data : {};
    const extensions = this.readExtensions(data);
    return { format: 'v2', raw: JSON.stringify(obj), name: data.name || '',
      description: data.description || '', personality: data.personality || '',
      scenario: data.scenario || '', firstMessage: data.first_mes || '',
      exampleDialogue: data.mes_example || '', creatorNotes: data.creator_notes || '',
      systemPrompt: data.system_prompt || '', postHistoryInstructions: data.post_history_instructions || '',
      creator: data.creator || '', characterVersion: data.character_version || '',
      tags: data.tags !== undefined ? data.tags.slice() : new Array<string>(),
      alternateGreetings: data.alternate_greetings !== undefined ? data.alternate_greetings.slice() : new Array<string>(),
      extensions: extensions };
  }

  /**
   * 读取Extensions 列表，并转换为运行时使用的数据结构。
   * @param data 导入或恢复使用的序列化数据。
   */
  private readExtensions(data: CharacterCardV2InputData): Record<string, string> {
    const extensions: Record<string, string> = {};
    if (data.extensions === undefined) {
      return extensions;
    }
    const keys = Object.keys(data.extensions);
    for (let index = 0; index < keys.length; index += 1) {
      // 键名。
      const key = keys[index];
      extensions[key] = String(data.extensions[key]);
    }
    return extensions;
  }

  /**
   * 解析Charx，非法输入会返回失败标记或空结果。
   */
  private parseCharx(archive: CharxArchive): CharacterCodecResult {
    if (archive.characters.length===0) throw new Error('charx 归档中无角色');
    const first = archive.characters[0];
    return { format: 'charx', raw: JSON.stringify(archive), name: first.name || '',
      description: first.description || '', personality: first.personality || '',
      scenario: first.scenario || '', firstMessage: first.first_mes || '',
      exampleDialogue: first.mes_example || '', creatorNotes: '', systemPrompt: '',
      postHistoryInstructions: '', creator: '', characterVersion: '',
      tags: new Array<string>(), alternateGreetings: new Array<string>(), extensions: {} };
  }
  private withFormat(result: CharacterCodecResult, format: CharacterCardFormat, raw: string): CharacterCodecResult {
    const tags = result.tags.slice();
    const alternateGreetings = result.alternateGreetings.slice();
    const extensions = this.copyExtensions(result.extensions);
    return {
      format: format,
      raw: raw,
      name: result.name,
      description: result.description,
      personality: result.personality,
      scenario: result.scenario,
      firstMessage: result.firstMessage,
      exampleDialogue: result.exampleDialogue,
      creatorNotes: result.creatorNotes,
      systemPrompt: result.systemPrompt,
      postHistoryInstructions: result.postHistoryInstructions,
      creator: result.creator,
      characterVersion: result.characterVersion,
      tags: tags,
      alternateGreetings: alternateGreetings,
      extensions: extensions,
    };
  }

  /**
   * 复制Extensions 列表，避免外部修改内部状态。
   */
  private copyExtensions(extensions: Record<string, string>): Record<string, string> {
    const result: Record<string, string> = {};
    const keys = Object.keys(extensions);
    for (let index = 0; index < keys.length; index += 1) {
      result[keys[index]] = extensions[keys[index]];
    }
    return result;
  }
}
