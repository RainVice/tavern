import type { ImageFormat, ImageMetadata, ImageMetadataChunk, MetadataExtractResult, MetadataWriteParams } from './ImageMetadataModels';

/**
 * 描述图片元数据模块在运行时交换的数据结构。
 */
interface PngChunkInfo {
  /**
   * offset 值，由当前实例内部维护。
   */
  offset: number;
  /**
   * length 值，由当前实例内部维护。
   */
  length: number;
  /**
   * type 值，由当前实例内部维护。
   */
  type: string;
  /**
   * data Offset 值，由当前实例内部维护。
   */
  dataOffset: number;
  /**
   * total Length 值，由当前实例内部维护。
   */
  totalLength: number;
}

/**
 * 提供图片元数据相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class ImageMetadataRuntime {
  /**
   * 识别输入数据的Format 值，供导入流程选择后续解析方式。
   * @param data 导入或恢复使用的序列化数据。
   */
  detectFormat(data: ArrayBuffer): ImageFormat {
    const bytes = new Uint8Array(data);
    if (bytes.length>=8 && bytes[0]===0x89 && bytes[1]===0x50 && bytes[2]===0x4E && bytes[3]===0x47) return 'png';
    if (bytes.length>=12 && bytes[0]===0x52 && bytes[1]===0x49 && bytes[2]===0x46 && bytes[3]===0x46 &&
        bytes[8]===0x57 && bytes[9]===0x45 && bytes[10]===0x42 && bytes[11]===0x50) return 'webp';
    if (bytes.length>=2 && bytes[0]===0xFF && bytes[1]===0xD8) return 'jpeg';
    return 'unknown';
  }

  /**
   * 解析或导入元数据数据，转换为当前 SDK 可使用的结构。
   * @param data 导入或恢复使用的序列化数据。
   */
  extractMetadata(data: ArrayBuffer): ImageMetadata {
    const format = this.detectFormat(data);
    const chunks = new Array<ImageMetadataChunk>();
    let hasCard = false;
    if (format === 'png') {
      const bytes = new Uint8Array(data);
      const parsedChunks = this.scanPngChunks(bytes);
      for (let index = 0; index < parsedChunks.length; index += 1) {
        const chunkInfo = parsedChunks[index];
        const type = chunkInfo.type;
        const length = chunkInfo.length;
        const chunk: ImageMetadataChunk = { type: type, size: length };
        chunks.push(chunk);
        if (this.isCharacterCardTextChunk(bytes, chunkInfo)) {
          hasCard = true;
        }
      }
    }
    // 简单尺寸估计
    return { format, width: 0, height: 0, hasCharacterCard: hasCard, rawChunks: chunks };
  }

  /**
   * 解析或导入角色卡数据，转换为当前 SDK 可使用的结构。
   * @param data 导入或恢复使用的序列化数据。
   */
  extractCharacterCard(data: ArrayBuffer): MetadataExtractResult {
    const metadata = this.extractMetadata(data);
    const result: MetadataExtractResult = {
      metadata: metadata,
      characterCardJson: '',
    };
    if (metadata.format === 'png') {
      result.characterCardJson = this.extractPngCharacterCardJson(new Uint8Array(data));
    }
    return result;
  }

  /**
   * 写入Metadata 值，持久化当前运行时状态。
   * @param params 创建、更新或执行操作所需的参数对象。
   */
  writeMetadata(params: MetadataWriteParams): ArrayBuffer {
    if (params.sourceData === undefined) {
      throw new Error('缺少源图片数据');
    }
    if (params.format !== 'png') {
      throw new Error(`暂不支持写入该图片元数据格式: ${params.format}`);
    }
    return this.writePngCharacterCard(params.sourceData, params.characterCardJson);
  }

  /**
   * 写入Png Character Card 值，持久化当前运行时状态。
   * @param data 导入或恢复使用的序列化数据。
   * @param characterCardJson character Card JSON 字符串。
   */
  writePngCharacterCard(data: ArrayBuffer, characterCardJson: string): ArrayBuffer {
    const bytes = new Uint8Array(data);
    if (this.detectFormat(data) !== 'png') {
      throw new Error('不是有效 PNG 图片');
    }
    const chunks = this.scanPngChunks(bytes);
    const cardChunk = this.createTextChunk('chara', this.base64Encode(this.stringToUtf8Bytes(characterCardJson)));
    const parts = new Array<Uint8Array>();
    parts.push(this.copyBytes(bytes, 0, 8));
    let inserted = false;
    let copiedOffset = 8;
    for (let index = 0; index < chunks.length; index += 1) {
      const chunk = chunks[index];
      if (chunk.offset > copiedOffset) {
        parts.push(this.copyBytes(bytes, copiedOffset, chunk.offset - copiedOffset));
      }
      if (!inserted && chunk.type === 'IEND') {
        parts.push(cardChunk);
        inserted = true;
      }
      if (!this.isCharacterCardTextChunk(bytes, chunk)) {
        parts.push(this.copyBytes(bytes, chunk.offset, chunk.totalLength));
      }
      copiedOffset = chunk.offset + chunk.totalLength;
    }
    if (!inserted) {
      if (copiedOffset < bytes.length) {
        parts.push(this.copyBytes(bytes, copiedOffset, bytes.length - copiedOffset));
      }
      parts.push(cardChunk);
    }
    return this.concatBytes(parts).buffer;
  }

  /**
   * 判断Valid Image 值是否满足条件。
   * @param data 导入或恢复使用的序列化数据。
   * @returns 条件命中时返回 true，否则返回 false。
   */
  isValidImage(data: ArrayBuffer): boolean {
    return this.detectFormat(data) !== 'unknown';
  }
  private scanPngChunks(bytes: Uint8Array): Array<PngChunkInfo> {
    const chunks = new Array<PngChunkInfo>();
    let offset = 8;
    while (offset <= bytes.length - 12) {
      const length = this.readUint32(bytes, offset);
      const totalLength = length + 12;
      if (offset + totalLength > bytes.length) {
        break;
      }
      const type = this.bytesToAscii(bytes, offset + 4, 4);
      const chunkInfo: PngChunkInfo = {
        offset: offset,
        length: length,
        type: type,
        dataOffset: offset + 8,
        totalLength: totalLength,
      };
      chunks.push(chunkInfo);
      offset += totalLength;
      if (type === 'IEND') {
        break;
      }
    }
    return chunks;
  }

  /**
   * 判断Character Card Text Chunk 值是否满足条件。


   * @returns 条件命中时返回 true，否则返回 false。
   */
  private isCharacterCardTextChunk(bytes: Uint8Array, chunk: PngChunkInfo): boolean {
    if (chunk.type !== 'tEXt') {
      return false;
    }
    const separator = this.findNullByte(bytes, chunk.dataOffset, chunk.length);
    if (separator < 0) {
      return false;
    }
    const keyword = this.bytesToAscii(bytes, chunk.dataOffset, separator - chunk.dataOffset);
    return keyword === 'chara' || keyword === 'ccv3';
  }

  /**
   * 解析或导入JSON数据，转换为当前 SDK 可使用的结构。
   */
  private extractPngCharacterCardJson(bytes: Uint8Array): string {
    const chunks = this.scanPngChunks(bytes);
    for (let index = 0; index < chunks.length; index += 1) {
      const chunk = chunks[index];
      if (!this.isCharacterCardTextChunk(bytes, chunk)) {
        continue;
      }
      const separator = this.findNullByte(bytes, chunk.dataOffset, chunk.length);
      if (separator < 0) {
        continue;
      }
      const keyword = this.bytesToAscii(bytes, chunk.dataOffset, separator - chunk.dataOffset);
      const textStart = separator + 1;
      const textLength = chunk.dataOffset + chunk.length - textStart;
      const text = this.bytesToAscii(bytes, textStart, textLength);
      if (keyword === 'ccv3' && text.startsWith('{')) {
        return text;
      }
      try {
        return this.utf8BytesToString(this.base64Decode(text));
      } catch (error) {
        return text;
      }
    }
    return '';
  }

  /**
   * 创建新的文本Chunk记录，写入存储并返回副本。

   * @param text 文本内容。
   * @returns 更新或读取后的记录副本。
   */
  private createTextChunk(keyword: string, text: string): Uint8Array {
    const keywordBytes = this.asciiStringToBytes(keyword);
    const textBytes = this.asciiStringToBytes(text);
    const dataLength = keywordBytes.length + 1 + textBytes.length;
    const chunk = new Uint8Array(dataLength + 12);
    this.writeUint32(chunk, 0, dataLength);
    chunk[4] = 0x74;
    chunk[5] = 0x45;
    chunk[6] = 0x58;
    chunk[7] = 0x74;
    for (let index = 0; index < keywordBytes.length; index += 1) {
      chunk[8 + index] = keywordBytes[index];
    }
    chunk[8 + keywordBytes.length] = 0;
    for (let index = 0; index < textBytes.length; index += 1) {
      chunk[9 + keywordBytes.length + index] = textBytes[index];
    }
    const crcInput = this.copyBytes(chunk, 4, dataLength + 4);
    const crc = this.crc32(crcInput);
    this.writeUint32(chunk, dataLength + 8, crc);
    return chunk;
  }

  /**
   * 读取Uint32 值，并转换为运行时使用的数据结构。

   * @param offset 分页起始偏移量。
   */
  private readUint32(bytes: Uint8Array, offset: number): number {
    return bytes[offset] * 16777216 + bytes[offset + 1] * 65536 + bytes[offset + 2] * 256 + bytes[offset + 3];
  }

  /**
   * 写入Uint32 值，持久化当前运行时状态。

   * @param offset 分页起始偏移量。
   * @param value 要保存或比较的字段值。
   */
  private writeUint32(bytes: Uint8Array, offset: number, value: number): void {
    bytes[offset] = Math.floor(value / 16777216) & 0xff;
    bytes[offset + 1] = Math.floor(value / 65536) & 0xff;
    bytes[offset + 2] = Math.floor(value / 256) & 0xff;
    bytes[offset + 3] = value & 0xff;
  }

  /**
   * 在当前集合中查找Null Byte 值，未命中时返回空值或默认位置。

   * @param offset 分页起始偏移量。
   */
  private findNullByte(bytes: Uint8Array, offset: number, length: number): number {
    const end = offset + length;
    for (let index = offset; index < end; index += 1) {
      if (bytes[index] === 0) {
        return index;
      }
    }
    return -1;
  }
  private bytesToAscii(bytes: Uint8Array, offset: number, length: number): string {
    let result = '';
    const end = offset + length;
    for (let index = offset; index < end; index += 1) {
      result += String.fromCharCode(bytes[index]);
    }
    return result;
  }
  private asciiStringToBytes(value: string): Uint8Array {
    const bytes = new Uint8Array(value.length);
    for (let index = 0; index < value.length; index += 1) {
      bytes[index] = value.charCodeAt(index) & 0xff;
    }
    return bytes;
  }
  private stringToUtf8Bytes(value: string): Uint8Array {
    const output = new Array<number>();
    for (let index = 0; index < value.length; index += 1) {
      let code = value.charCodeAt(index);
      if (code >= 0xd800 && code <= 0xdbff && index + 1 < value.length) {
        const next = value.charCodeAt(index + 1);
        if (next >= 0xdc00 && next <= 0xdfff) {
          code = 0x10000 + (code - 0xd800) * 0x400 + (next - 0xdc00);
          index += 1;
        }
      }
      if (code <= 0x7f) {
        output.push(code);
      } else if (code <= 0x7ff) {
        output.push(0xc0 | (code >> 6));
        output.push(0x80 | (code & 0x3f));
      } else if (code <= 0xffff) {
        output.push(0xe0 | (code >> 12));
        output.push(0x80 | ((code >> 6) & 0x3f));
        output.push(0x80 | (code & 0x3f));
      } else {
        output.push(0xf0 | (code >> 18));
        output.push(0x80 | ((code >> 12) & 0x3f));
        output.push(0x80 | ((code >> 6) & 0x3f));
        output.push(0x80 | (code & 0x3f));
      }
    }
    const bytes = new Uint8Array(output.length);
    for (let index = 0; index < output.length; index += 1) {
      bytes[index] = output[index];
    }
    return bytes;
  }
  private utf8BytesToString(bytes: Uint8Array): string {
    let result = '';
    let index = 0;
    while (index < bytes.length) {
      const first = bytes[index];
      let code = 0;
      if (first < 0x80) {
        code = first;
        index += 1;
      } else if ((first & 0xe0) === 0xc0 && index + 1 < bytes.length) {
        code = ((first & 0x1f) << 6) | (bytes[index + 1] & 0x3f);
        index += 2;
      } else if ((first & 0xf0) === 0xe0 && index + 2 < bytes.length) {
        code = ((first & 0x0f) << 12) | ((bytes[index + 1] & 0x3f) << 6) | (bytes[index + 2] & 0x3f);
        index += 3;
      } else if ((first & 0xf8) === 0xf0 && index + 3 < bytes.length) {
        code = ((first & 0x07) << 18) | ((bytes[index + 1] & 0x3f) << 12) | ((bytes[index + 2] & 0x3f) << 6) | (bytes[index + 3] & 0x3f);
        index += 4;
      } else {
        code = 0xfffd;
        index += 1;
      }
      if (code <= 0xffff) {
        result += String.fromCharCode(code);
      } else {
        const adjusted = code - 0x10000;
        result += String.fromCharCode(0xd800 + Math.floor(adjusted / 0x400));
        result += String.fromCharCode(0xdc00 + (adjusted % 0x400));
      }
    }
    return result;
  }
  private base64Encode(bytes: Uint8Array): string {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let output = '';
    for (let index = 0; index < bytes.length; index += 3) {
      const first = bytes[index];
      const second = index + 1 < bytes.length ? bytes[index + 1] : 0;
      const third = index + 2 < bytes.length ? bytes[index + 2] : 0;
      const triple = first * 65536 + second * 256 + third;
      output += alphabet.charAt(Math.floor(triple / 262144) & 0x3f);
      output += alphabet.charAt(Math.floor(triple / 4096) & 0x3f);
      output += index + 1 < bytes.length ? alphabet.charAt(Math.floor(triple / 64) & 0x3f) : '=';
      output += index + 2 < bytes.length ? alphabet.charAt(triple & 0x3f) : '=';
    }
    return output;
  }
  private base64Decode(value: string): Uint8Array {
    const output = new Array<number>();
    let buffer = 0;
    let bits = 0;
    for (let index = 0; index < value.length; index += 1) {
      const code = value.charAt(index);
      if (code === '=' || code === '\n' || code === '\r' || code === ' ' || code === '\t') {
        continue;
      }
      const digit = this.base64Digit(code);
      if (digit < 0) {
        throw new Error('无效 Base64 数据');
      }
      buffer = buffer * 64 + digit;
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        output.push((Math.floor(buffer / Math.pow(2, bits))) & 0xff);
        buffer = buffer % Math.pow(2, bits);
      }
    }
    const bytes = new Uint8Array(output.length);
    for (let index = 0; index < output.length; index += 1) {
      bytes[index] = output[index];
    }
    return bytes;
  }
  private base64Digit(value: string): number {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    return alphabet.indexOf(value);
  }
  private crc32(bytes: Uint8Array): number {
    let crc = 0xffffffff;
    for (let index = 0; index < bytes.length; index += 1) {
      crc = (crc >>> 8) ^ this.crcTableValue((crc ^ bytes[index]) & 0xff);
    }
    return (crc ^ 0xffffffff) >>> 0;
  }
  private crcTableValue(index: number): number {
    let value = index;
    for (let bit = 0; bit < 8; bit += 1) {
      if ((value & 1) !== 0) {
        value = (0xedb88320 ^ (value >>> 1)) >>> 0;
      } else {
        value = value >>> 1;
      }
    }
    return value >>> 0;
  }

  /**
   * 复制Bytes 列表，避免外部修改内部状态。

   * @param offset 分页起始偏移量。
   */
  private copyBytes(bytes: Uint8Array, offset: number, length: number): Uint8Array {
    const result = new Uint8Array(length);
    for (let index = 0; index < length; index += 1) {
      result[index] = bytes[offset + index];
    }
    return result;
  }
  private concatBytes(parts: Array<Uint8Array>): Uint8Array {
    let length = 0;
    for (let index = 0; index < parts.length; index += 1) {
      length += parts[index].length;
    }
    const result = new Uint8Array(length);
    let offset = 0;
    for (let partIndex = 0; partIndex < parts.length; partIndex += 1) {
      const part = parts[partIndex];
      for (let index = 0; index < part.length; index += 1) {
        result[offset + index] = part[index];
      }
      offset += part.length;
    }
    return result;
  }
}
