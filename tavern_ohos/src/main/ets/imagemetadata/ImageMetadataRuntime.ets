import type { ImageFormat, ImageMetadata, ImageMetadataChunk, ImageMetadataChunkType, MetadataExtractResult, MetadataWriteParams } from './ImageMetadataModels';

/**
 * PNG 图片中单个 chunk 的偏移和长度信息，用于遍历和定位元数据块。
 */
interface PngChunkInfo {
  /**
   * chunk 在文件中的起始偏移量（字节数）。
   */
  offset: number;
  /**
   * chunk 数据段长度（不含 type、CRC 等头部尾部）。
   */
  length: number;
  /**
   * chunk 类型标识符（如 tEXt、IEND）。
   */
  type: ImageMetadataChunkType;
  /**
   * chunk 数据段起始位置（offset + 8 字节头部）。
   */
  dataOffset: number;
  /**
   * chunk 在文件中占用的总长度（length + 12 字节头部尾部）。
   */
  totalLength: number;
}

/**
 * WebP RIFF 文件中单个 chunk 的偏移和长度信息，用于遍历和定位元数据块。
 */
interface WebpChunkInfo {
  /**
   * chunk 在文件中的起始偏移量（字节数）。
   */
  offset: number;
  /**
   * chunk 数据段长度（不含 type 和 size 头部）。
   */
  length: number;
  /**
   * chunk 类型标识符（如 EXIF、VP8）。
   */
  type: ImageMetadataChunkType;
  /**
   * chunk 数据段起始位置（offset + 8 字节头部）。
   */
  dataOffset: number;
  /**
   * chunk 在文件中占用的总长度（含对齐填充，length + 8 字节头部）。
   */
  totalLength: number;
}

/**
 * 提供图片元数据相关的无 UI 运行时能力，负责检测图片格式、提取元数据与角色卡、以及写入角色卡数据。
 */
export class ImageMetadataRuntime {
  /**
   * 通过读取文件头魔数，检测传入 ArrayBuffer 的图片编码格式。
   * @param data 待检测的原始图片数据（ArrayBuffer）。
   * @returns 识别出的图片格式，无法识别时返回 'unknown'。
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
   * 从原始图片数据中提取元数据摘要，包括格式、原始 chunk 列表以及是否包含角色卡。
   * @param data 原始图片数据的 ArrayBuffer。
   * @returns 包含格式、chunk 列表和角色卡标记的 ImageMetadata 对象。
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
    } else if (format === 'webp') {
      const bytes = new Uint8Array(data);
      const parsedChunks = this.scanWebpChunks(bytes);
      for (let index = 0; index < parsedChunks.length; index += 1) {
        const chunkInfo = parsedChunks[index];
        const chunk: ImageMetadataChunk = { type: chunkInfo.type, size: chunkInfo.length };
        chunks.push(chunk);
        if (this.isCharacterCardWebpChunk(bytes, chunkInfo)) {
          hasCard = true;
        }
      }
    }
    // 简单尺寸估计
    return { format, width: 0, height: 0, hasCharacterCard: hasCard, rawChunks: chunks };
  }

  /**
   * 从原始图片数据中提取完整的元数据结果，包括元数据摘要及其嵌入的角色卡 JSON。
   * @param data 原始图片数据的 ArrayBuffer。
   * @returns 包含元数据摘要和角色卡 JSON 字符串的 MetadataExtractResult 对象。
   */
  extractCharacterCard(data: ArrayBuffer): MetadataExtractResult {
    const metadata = this.extractMetadata(data);
    const result: MetadataExtractResult = {
      metadata: metadata,
      characterCardJson: '',
    };
    if (metadata.format === 'png') {
      result.characterCardJson = this.extractPngCharacterCardJson(new Uint8Array(data));
    } else if (metadata.format === 'webp') {
      result.characterCardJson = this.extractWebpCharacterCardJson(new Uint8Array(data));
    }
    return result;
  }

  /**
   * 将角色卡 JSON 写入图片文件的元数据块中，支持 PNG 和 WebP 格式。
   * @param params 写入参数，需指定目标格式、角色卡 JSON、输出路径，以及源图片数据。
   * @returns 写入角色卡后的完整图片数据（ArrayBuffer）。
   */
  writeMetadata(params: MetadataWriteParams): ArrayBuffer {
    if (params.sourceData === undefined) {
      throw new Error('缺少源图片数据');
    }
    if (params.format === 'webp') {
      return this.writeWebpCharacterCard(params.sourceData, params.characterCardJson);
    }
    if (params.format !== 'png') {
      throw new Error(`暂不支持写入该图片元数据格式: ${params.format}`);
    }
    return this.writePngCharacterCard(params.sourceData, params.characterCardJson);
  }

  /**
   * 将角色卡 JSON 写入 PNG 图片的 tEXt chunk 中（关键字 chara，Base64 编码）。
   * @param data 原始 PNG 图片数据。
   * @param characterCardJson 待写入的角色卡 JSON 字符串。
   * @returns 写入角色卡后的完整 PNG 图片数据（ArrayBuffer）。
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
   * 将角色卡 JSON 写入 WebP 图片的 EXIF chunk 中（关键字 chara，Base64 编码）。
   * @param data 原始 WebP 图片数据。
   * @param characterCardJson 待写入的角色卡 JSON 字符串。
   * @returns 写入角色卡后的完整 WebP 图片数据（ArrayBuffer）。
   */
  writeWebpCharacterCard(data: ArrayBuffer, characterCardJson: string): ArrayBuffer {
    const bytes = new Uint8Array(data);
    if (this.detectFormat(data) !== 'webp') {
      throw new Error('不是有效 WebP 图片');
    }
    const chunks = this.scanWebpChunks(bytes);
    const cardChunk = this.createWebpMetadataChunk(characterCardJson);
    const parts = new Array<Uint8Array>();
    parts.push(this.copyBytes(bytes, 0, 12));
    let copiedOffset = 12;
    for (let index = 0; index < chunks.length; index += 1) {
      const chunk = chunks[index];
      if (chunk.offset > copiedOffset) {
        parts.push(this.copyBytes(bytes, copiedOffset, chunk.offset - copiedOffset));
      }
      if (!this.isCharacterCardWebpChunk(bytes, chunk)) {
        parts.push(this.copyBytes(bytes, chunk.offset, chunk.totalLength));
      }
      copiedOffset = chunk.offset + chunk.totalLength;
    }
    if (copiedOffset < bytes.length) {
      parts.push(this.copyBytes(bytes, copiedOffset, bytes.length - copiedOffset));
    }
    parts.push(cardChunk);
    const result = this.concatBytes(parts);
    this.writeUint32LittleEndian(result, 4, result.length - 8);
    return result.buffer;
  }

  /**
   * 判断传入的 ArrayBuffer 是否为有效的图片数据（PNG、WebP 或 JPEG）。
   * @param data 待检测的图片数据。
   * @returns 能识别为有效图片格式时返回 true，否则返回 false。
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

  private scanWebpChunks(bytes: Uint8Array): Array<WebpChunkInfo> {
    const chunks = new Array<WebpChunkInfo>();
    let offset = 12;
    while (offset <= bytes.length - 8) {
      const type = this.bytesToAscii(bytes, offset, 4);
      const length = this.readUint32LittleEndian(bytes, offset + 4);
      const paddedLength = length + (length % 2);
      const totalLength = paddedLength + 8;
      if (offset + totalLength > bytes.length) {
        break;
      }
      const chunkInfo: WebpChunkInfo = {
        offset: offset,
        length: length,
        type: type,
        dataOffset: offset + 8,
        totalLength: totalLength,
      };
      chunks.push(chunkInfo);
      offset += totalLength;
    }
    return chunks;
  }

  /**
   * 判断 PNG 图片的指定 chunk 是否为角色卡文本块（关键字为 chara 或 ccv3）。
   * @param bytes PNG 图片的字节数组。
   * @param chunk 待判断的 chunk 信息。
   * @returns 是角色卡文本块时返回 true，否则返回 false。
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
   * 从 PNG 图片的 tEXt chunk 中提取角色卡 JSON 字符串。
   * 优先尝试 Base64 解码，若失败则返回原始文本。
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

  private isCharacterCardWebpChunk(bytes: Uint8Array, chunk: WebpChunkInfo): boolean {
    if (chunk.type !== 'EXIF') {
      return false;
    }
    const separator = this.findNullByte(bytes, chunk.dataOffset, chunk.length);
    if (separator < 0) {
      return false;
    }
    const keyword = this.bytesToAscii(bytes, chunk.dataOffset, separator - chunk.dataOffset);
    return keyword === 'chara' || keyword === 'ccv3';
  }

  private extractWebpCharacterCardJson(bytes: Uint8Array): string {
    const chunks = this.scanWebpChunks(bytes);
    for (let index = 0; index < chunks.length; index += 1) {
      const chunk = chunks[index];
      if (!this.isCharacterCardWebpChunk(bytes, chunk)) {
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
   * 创建 PNG tEXt chunk 的完整字节序列（含 length、type、data 和 CRC）。
   * @param keyword chunk 关键字（如 chara）。
   * @param text 待写入的文本数据。
   * @returns 完整的 tEXt chunk 字节数组。
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

  private createWebpMetadataChunk(characterCardJson: string): Uint8Array {
    const keywordBytes = this.asciiStringToBytes('chara');
    const textBytes = this.asciiStringToBytes(this.base64Encode(this.stringToUtf8Bytes(characterCardJson)));
    const dataLength = keywordBytes.length + 1 + textBytes.length;
    const paddedLength = dataLength + (dataLength % 2);
    const chunk = new Uint8Array(8 + paddedLength);
    chunk[0] = 0x45;
    chunk[1] = 0x58;
    chunk[2] = 0x49;
    chunk[3] = 0x46;
    this.writeUint32LittleEndian(chunk, 4, dataLength);
    for (let index = 0; index < keywordBytes.length; index += 1) {
      chunk[8 + index] = keywordBytes[index];
    }
    chunk[8 + keywordBytes.length] = 0;
    for (let index = 0; index < textBytes.length; index += 1) {
      chunk[9 + keywordBytes.length + index] = textBytes[index];
    }
    if (paddedLength > dataLength) {
      chunk[8 + paddedLength - 1] = 0;
    }
    return chunk;
  }

  /**
   * 以大端序读取 Uint8Array 中指定偏移位置的 4 字节无符号整数。
   * @param offset 读取起始偏移量。
   */
  private readUint32(bytes: Uint8Array, offset: number): number {
    return bytes[offset] * 16777216 + bytes[offset + 1] * 65536 + bytes[offset + 2] * 256 + bytes[offset + 3];
  }
  private readUint32LittleEndian(bytes: Uint8Array, offset: number): number {
    return bytes[offset] + bytes[offset + 1] * 256 + bytes[offset + 2] * 65536 + bytes[offset + 3] * 16777216;
  }

  /**
   * 以大端序将 4 字节无符号整数写入 Uint8Array 的指定偏移位置。
   * @param offset 写入起始偏移量。
   * @param value 待写入的整数。
   */
  private writeUint32(bytes: Uint8Array, offset: number, value: number): void {
    bytes[offset] = Math.floor(value / 16777216) & 0xff;
    bytes[offset + 1] = Math.floor(value / 65536) & 0xff;
    bytes[offset + 2] = Math.floor(value / 256) & 0xff;
    bytes[offset + 3] = value & 0xff;
  }
  private writeUint32LittleEndian(bytes: Uint8Array, offset: number, value: number): void {
    bytes[offset] = value & 0xff;
    bytes[offset + 1] = Math.floor(value / 256) & 0xff;
    bytes[offset + 2] = Math.floor(value / 65536) & 0xff;
    bytes[offset + 3] = Math.floor(value / 16777216) & 0xff;
  }

  /**
   * 在 Uint8Array 的指定范围内查找第一个值为 0 的字节偏移量。
   * @param offset 查找的起始偏移量。
   * @param length 查找范围长度。
   * @returns 找到的偏移量，未找到时返回 -1。
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
   * 从 Uint8Array 指定位置复制指定长度的字节序列。
   * @param offset 复制起始偏移量。
   * @param length 复制长度。
   * @returns 新创建的字节数组副本。
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
