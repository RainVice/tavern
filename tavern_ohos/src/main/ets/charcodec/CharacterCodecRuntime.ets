import type {
  CharacterBook, CharacterBookEntry, CharacterBookInput, CharacterCardFormat,
  CharacterCardV1, CharacterCardV2Export, CharacterCardV2ExportData,
  CharacterCardV2Input, CharacterCardV2InputData, CharacterCodecResult,
  CharxArchive,
} from './CharacterCodecModels';
import { ImageMetadataRuntime } from '../imagemetadata/ImageMetadataRuntime';

/**
 * 提供角色卡编解码相关的无 UI 运行时能力，支持 V1、V2、charx、PNG metadata、WebP metadata 多种格式的解析与导出，
 * 供角色导入/导出流程和角色卡分享功能调用。
 */
export class CharacterCodecRuntime {
  /**
   * 解析 JSON 字符串并自动识别角色卡格式（V1 / V2 / charx），在用户选择角色卡文件导入时调用。
   * 格式识别优先级：V2 > charx > V1，识别失败时抛出"无法识别的角色卡格式"错误。
   * @param json 外部传入的角色卡 JSON 字符串，由用户选择文件或拖拽导入提供。
   * @returns 包含所有角色字段的统一解码结果，供导入流程确认角色信息后继续。
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
   * 从 PNG 图片的 metadata 中提取并解析角色卡数据，在用户选择 PNG 格式角色卡文件导入时调用。
   * 流程：读取 PNG EXIF/ICC/Text chunks -> 提取角色卡 JSON -> 调用 parseCharacterJson 解析。
   * @param data PNG 图片的二进制数据，由图片文件读取提供。
   * @returns 包含格式标记 png_metadata 的解码结果，供导入流程确认角色信息。
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
   * 从 WebP 图片的 metadata 中提取并解析角色卡数据，在用户选择 WebP 格式角色卡文件导入时调用。
   * 流程：读取 WebP EXIF chunks -> 提取角色卡 JSON -> 调用 parseCharacterJson 解析。
   * @param data WebP 图片的二进制数据，由图片文件读取提供。
   * @returns 包含格式标记 webp_metadata 的解码结果，供导入流程确认角色信息。
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
   * 将解码结果导出为 SillyTavern 角色卡 V2 JSON 字符串，在用户导出角色卡时调用。
   * @param result 解码后的角色卡结果，通常来自 parseCharacterJson 等解析方法的输出。
   * @returns 符合角色卡 V2 格式的 JSON 字符串，可用于保存为 .json 文件或嵌入到图片 metadata 中。
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
   * 将角色卡写入 PNG 图片的 metadata 中，在用户导出含角色卡的 PNG 图片时调用。
   * 流程：导出为 V2 JSON -> 将 JSON 写入 PNG 图片的文本 chunk metadata 中。
   * @param result 解码后的角色卡结果，包含要导出的角色数据。
   * @param sourcePng 源 PNG 图片数据，作为角色卡头像载体。
   * @returns 嵌入了角色卡 V2 JSON 的 PNG 数据，可用于分享或保存。
   */
  exportToPng(result: CharacterCodecResult, sourcePng: ArrayBuffer): ArrayBuffer {
    const metadata = new ImageMetadataRuntime();
    return metadata.writePngCharacterCard(sourcePng, this.exportToV2(result));
  }

  /**
   * 将角色卡写入 WebP 图片的 metadata 中，在用户导出含角色卡的 WebP 图片时调用。
   * 流程：导出为 V2 JSON -> 将 JSON 写入 WebP 图片的 EXIF metadata 中。
   * @param result 解码后的角色卡结果，包含要导出的角色数据。
   * @param sourceWebp 源 WebP 图片数据，作为角色卡头像载体。
   * @returns 嵌入了角色卡 V2 JSON 的 WebP 数据，可用于分享或保存。
   */
  exportToWebp(result: CharacterCodecResult, sourceWebp: ArrayBuffer): ArrayBuffer {
    const metadata = new ImageMetadataRuntime();
    return metadata.writeWebpCharacterCard(sourceWebp, this.exportToV2(result));
  }

  /**
   * 识别文本格式的角色卡格式类型，在导入流程中自动选择解析方式。
   * 不抛出异常，未知格式返回 'unknown'，调用方根据返回值决定是否允许导入。
   * @param data 角色卡 JSON 字符串，由外部文件读取提供。
   * @returns 检测到的格式：'v1'、'v2'、'charx' 或 'unknown'。
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
   * 识别图片二进制数据中嵌入的角色卡格式类型（PNG 或 WebP），在导入流程中自动选择解析方式。
   * @param data 图片二进制数据，由文件读取提供。
   * @returns 检测到的格式：'png_metadata'、'webp_metadata' 或 'unknown'。
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
   * 解析角色世界书（Lorebook）JSON 字符串，在用户选择或拖入世界书 JSON 文件时调用。
   * 将外部结构转换为运行时结构，填充缺失字段的默认值为空字符串或空数组。
   * @param json 外部传入的世界书 JSON 字符串，由文件读取提供。
   * @returns 包含条目列表的运行时世界书结构，供世界书编辑和对话上下文注入使用。
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
   * 将运行时世界书结构导出为 JSON 字符串，在用户导出世界书时调用。
   * @param book 运行时世界书结构，由世界书编辑器提供。
   * @returns 可持久化或分享的世界书 JSON 字符串。
   */
  exportCharacterBook(book: CharacterBook): string { return JSON.stringify(book); }

  /**
   * 解析角色卡 V1 格式，提取基础字段。
   */
  private parseV1(card: CharacterCardV1): CharacterCodecResult {
    return { format: 'v1', raw: JSON.stringify(card), name: card.name||'', description: card.description||'',
      personality: card.personality||'', scenario: card.scenario||'', firstMessage: card.first_mes||'',
      exampleDialogue: card.mes_example||'', creatorNotes: '', systemPrompt: '', postHistoryInstructions: '',
      creator: '', characterVersion: '', tags: new Array<string>(), alternateGreetings: new Array<string>(),
      extensions: {} };
  }

  /**
   * 解析角色卡 V2 格式，提取所有字段包括扩展字段。
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
   * 读取角色卡 V2 的扩展字段，将所有值转为字符串类型存储。
   * @param data 角色卡 V2 的 data 字段。
   * @returns 扁平化后的扩展字段键值对。
   */
  private readExtensions(data: CharacterCardV2InputData): Record<string, string> {
    const extensions: Record<string, string> = {};
    if (data.extensions === undefined) {
      return extensions;
    }
    const keys = Object.keys(data.extensions);
    for (let index = 0; index < keys.length; index += 1) {
      const key = keys[index];
      extensions[key] = String(data.extensions[key]);
    }
    return extensions;
  }

  /**
   * 解析 charx 归档格式，提取首个角色的字段数据。
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
   * 复制扩展字段键值对，避免外部修改内部状态。
   * @param extensions 原始扩展字段。
   * @returns 扩展字段的副本。
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
