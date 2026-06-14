import type { ImageFormat, ImageMetadata, ImageMetadataChunk, MetadataExtractResult, MetadataWriteParams } from './ImageMetadataModels';

/**
 * 描述 PNG 图片数据块在二进制文件中的位置和大小。
 */
interface PngChunkInfo {
  /**
   * 数据块在文件中的起始偏移量（字节）。
   */
  offset: number;
  /**
   * 数据块中数据部分的长度（字节，不含 type 和 CRC）。
   */
  length: number;
  /**
   * 数据块类型标识，如 IHDR、tEXt、IEND。
   */
  type: string;
  /**
   * 数据块中实际数据内容的起始偏移量。
   */
  dataOffset: number;
  /**
   * 数据块总长度（length + 12 字节头部）。
   */
  totalLength: number;
}

/**
 * 描述 WebP RIFF chunk 在文件中的位置和大小。
 */
interface WebpChunkInfo {
  /**
   * chunk 在文件中的起始偏移量（字节）。
   */
  offset: number;
  /**
   * chunk 数据部分的长度（字节）。
   */
  length: number;
  /**
   * chunk 类型标识，如 VP8、EXIF。
   */
  type: string;
  /**
   * chunk 中实际数据内容的起始偏移量。
   */
  dataOffset: number;
  /**
   * chunk 总长度（含填充）。
   */
  totalLength: number;
}

/**
 * 提供图片元数据相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 支持从 PNG 和 WebP 图片中提取嵌入式元数据（包括角色卡数据），以及将角色卡 JSON 写回图片文件。
 * 外部调用方（如角色卡导入/导出流程、图片信息查看页）通过此类完成元数据操作。
 */
export class ImageMetadataRuntime {
  /**
   * 通过读取文件头部特征字节判断图片格式（PNG/WebP/JPEG）。
   * 由 extractMetadata() 等方法内部调用，作为元数据提取流程的第一步——确定解析策略。
   * @param data 原始图片二进制数据，来自文件读取或外部输入。
   * @returns 识别的图片格式类型，'unknown' 表示无法识别。
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
   * 从图片二进制数据中提取完整元数据，包括格式、数据块列表和角色卡标记。
   * 由 extractCharacterCard() 内部调用，或单独用于图片信息展示场景（如查看图片的 chunk 结构）。
   * @param data 原始图片二进制数据，支持 PNG 和 WebP 两种格式。
   * @returns 包含格式、数据块信息（rawChunks）和角色卡标记（hasCharacterCard）的元数据对象。
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
    // 简单尺寸估计（暂未实现实际解析，返回 0）
    return { format, width: 0, height: 0, hasCharacterCard: hasCard, rawChunks: chunks };
  }

  /**
   * 从图片二进制数据中提取角色卡 JSON 字符串和元数据。
   * 由角色卡导入流程（如从 PNG/WebP 图片导入角色）调用，从图片的 tEXt 或 EXIF chunk 中解析角色卡数据。
   * @param data 原始图片二进制数据（PNG 或 WebP 格式），通常来自文件读取或剪贴板。
   * @returns 包含完整元数据和角色卡 JSON 字符串的结果对象，调用方可根据 characterCardJson 是否为空判断是否成功。
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
   * 将角色卡 JSON 写入图片元数据，返回包含角色卡的新图片二进制数据。
   * 由角色卡导出/保存流程（如导出角色为 PNG/WebP 图片）调用，将角色卡数据嵌入图片元数据区。
   * @param params 写入参数，包括图片格式、角色卡 JSON 字符串和源图片数据，决定写入算法和输出。
   * @returns 包含角色卡元数据的图片二进制数据，可用于写入文件系统或导出到外部。
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
   * 将角色卡 JSON 写入 PNG 图片的 IEND 块之前，生成新的 PNG 二进制数据。
   * 由 writeMetadata() 在 format 为 png 时内部调用，在 IEND chunk 前插入 chara 关键字 tEXt 块。
   * @param data 源 PNG 图片二进制数据。
   * @param characterCardJson 角色卡 JSON 字符串，将被 Base64 编码后写入 tEXt 块。
   * @returns 包含角色卡元数据的新 PNG 二进制数据，可直接写入文件。
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
   * 将角色卡 JSON 写入 WebP 图片的 EXIF chunk 中，生成新的 WebP 二进制数据。
   * 由 writeMetadata() 在 format 为 webp 时内部调用，在 RIFF 容器末尾追加 EXIF chunk。
   * @param data 源 WebP 图片二进制数据。
   * @param characterCardJson 角色卡 JSON 字符串，将被 Base64 编码后写入 EXIF chunk 的 data 区。
   * @returns 包含角色卡元数据的新 WebP 二进制数据。
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
   * 判断图片二进制数据是否为受支持的图片格式（非 unknown）。
   * 由角色卡导入流程在开始提取元数据前调用，快速校验输入数据是否有效。
   * @param data 原始图片二进制数据。
   * @returns 是有效图片格式时返回 true，可用于前置校验。
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
   * 判断 PNG tEXt 块的关键字是否为角色卡标识（chara 或 ccv3）。
   * @param bytes PNG 文件完整二进制数据。
   * @param chunk 待检查的 PNG 数据块信息。
   * @returns 是角色卡文本块时返回 true。
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
   * 从 PNG 图片的 tEXt 块中提取角色卡 JSON 字符串。
   * @param bytes PNG 文件完整二进制数据。
   * @returns 角色卡 JSON 字符串，未找到时返回空字符串。
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
   * 创建 PNG tEXt 文本块二进制数据，包含关键字和 Base64 编码的文本内容。
   * @param keyword tEXt 块关键字，如 chara。
   * @param text Base64 编码的文本数据。
   * @returns 完整的 PNG tEXt 块二进制数据（含长度、类型、CRC）。
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
   * 从大端 Uint8Array 中读取 4 字节无符号整数。
   * @param bytes 二进制数据源。
   * @param offset 读取起始偏移量（字节）。
   * @returns 4 字节大端无符号整数值。
   */
  private readUint32(bytes: Uint8Array, offset: number): number {
    return bytes[offset] * 16777216 + bytes[offset + 1] * 65536 + bytes[offset + 2] * 256 + bytes[offset + 3];
  }
  private readUint32LittleEndian(bytes: Uint8Array, offset: number): number {
    return bytes[offset] + bytes[offset + 1] * 256 + bytes[offset + 2] * 65536 + bytes[offset + 3] * 16777216;
  }

  /**
   * 将 4 字节大端无符号整数写入 Uint8Array 的指定偏移位置。
   * @param bytes 目标二进制数组。
   * @param offset 写入起始偏移量（字节）。
   * @param value 要写入的 4 字节大端无符号整数值。
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
   * 在指定范围内的字节数组中查找第一个空字节（0x00）的位置。
   * @param bytes 二进制数据源。
   * @param offset 搜索起始偏移量。
   * @param length 搜索范围长度（字节）。
   * @returns 空字节的位置索引，未找到时返回 -1。
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
  /**
   * 从 Uint8Array 的指定范围提取 ASCII 字符串。
   * @param bytes 二进制数据源。
   * @param offset 提取起始偏移量。
   * @param length 提取长度（字节数）。
   * @returns 提取的 ASCII 字符串。
   */
  private bytesToAscii(bytes: Uint8Array, offset: number, length: number): string {
    let result = '';
    const end = offset + length;
    for (let index = offset; index < end; index += 1) {
      result += String.fromCharCode(bytes[index]);
    }
    return result;
  }
  /**
   * 将 ASCII 字符串转换为字节数组。
   * @param value 要转换的 ASCII 字符串。
   * @returns 对应的 Uint8Array 字节数组。
   */
  private asciiStringToBytes(value: string): Uint8Array {
    const bytes = new Uint8Array(value.length);
    for (let index = 0; index < value.length; index += 1) {
      bytes[index] = value.charCodeAt(index) & 0xff;
    }
    return bytes;
  }
  /**
   * 将 UTF-8 字符串转换为字节数组（支持代理对编码）。
   * @param value 要转换的 UTF-8 字符串。
   * @returns 对应的 Uint8Array 字节数组。
   */
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
   * 从 Uint8Array 的指定位置复制一段字节。
   * @param bytes 源二进制数组。
   * @param offset 复制起始偏移量。
   * @param length 复制长度（字节数）。
   * @returns 复制出的新 Uint8Array。
   */
  private copyBytes(bytes: Uint8Array, offset: number, length: number): Uint8Array {
    const result = new Uint8Array(length);
    for (let index = 0; index < length; index += 1) {
      result[index] = bytes[offset + index];
    }
    return result;
  }
  /**
   * 拼接多个 Uint8Array 为一个连续的字节数组。
   * @param parts 待拼接的 Uint8Array 数组。
   * @returns 拼接后的完整 Uint8Array。
   */
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
