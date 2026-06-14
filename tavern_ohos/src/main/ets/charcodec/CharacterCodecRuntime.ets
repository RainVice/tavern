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
   * 将输入 JSON 解析为统一结构 CharacterCodecResult，自动检测 V1 / V2 / charx 格式。
   * @param json 角色卡原始 JSON 字符串。
   * @returns 解析后的统一结果结构。
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
   * 从 PNG 图片中提取并解析角色卡数据。
   * @param data PNG 图片的 ArrayBuffer 数据。
   * @returns 解析后的统一结果结构。
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
   * 从 WebP 图片中提取并解析角色卡数据。
   * @param data WebP 图片的 ArrayBuffer 数据。
   * @returns 解析后的统一结果结构。
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
   * 将 CharacterCodecResult 导出为 V2 格式的 JSON 字符串。
   * @param result 待导出的角色卡结果。
   * @returns V2 格式 JSON 字符串，可用于持久化或传输。
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
   * 将角色卡数据写入 PNG 图片中，生成携带 metadata 的 PNG 文件。
   * @param result 待导出的角色卡结果。
   * @param sourcePng 源 PNG 图片的 ArrayBuffer 数据。
   * @returns 写入角色卡后的 PNG 图片数据。
   */
  exportToPng(result: CharacterCodecResult, sourcePng: ArrayBuffer): ArrayBuffer {
    const metadata = new ImageMetadataRuntime();
    return metadata.writePngCharacterCard(sourcePng, this.exportToV2(result));
  }

  /**
   * 将角色卡数据写入 WebP 图片中，生成携带 metadata 的 WebP 文件。
   * @param result 待导出的角色卡结果。
   * @param sourceWebp 源 WebP 图片的 ArrayBuffer 数据。
   * @returns 写入角色卡后的 WebP 图片数据。
   */
  exportToWebp(result: CharacterCodecResult, sourceWebp: ArrayBuffer): ArrayBuffer {
    const metadata = new ImageMetadataRuntime();
    return metadata.writeWebpCharacterCard(sourceWebp, this.exportToV2(result));
  }

  /**
   * 检测 JSON 字符串所属的角色卡格式类型，供导入流程选择后续解析方式。
   * @param data 角色卡原始 JSON 字符串。
   * @returns 格式标识，如 'v1'、'v2'、'charx' 或 'unknown'。
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
   * 检测二进制数据（PNG/WebP）中是否嵌入了角色卡 metadata。
   * @param data 图片文件的 ArrayBuffer 数据。
   * @returns 格式标识，如 'png_metadata'、'webp_metadata' 或 'unknown'。
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
   * 解析角色书 JSON，将输入结构转换为运行时使用的 CharacterBook。
   * @param json 角色书原始 JSON 字符串。
   * @returns 解析后的角色书结构。
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
   * 将 CharacterBook 序列化为 JSON 字符串。
   * @param book 待导出的角色书。
   * @returns 角色书 JSON 字符串。
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
