import { BaseStore } from '../base/BaseStore';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { zlib } from '@kit.BasicServicesKit';
import { FileUtil, JSONUtil, LogUtil, ObjectUtil } from '@pura/harmony-utils';

/**
 * 角色卡列表中的单个文件。
 */
export interface RoleCardListItem {
  /** 角色名。 */
  name: string;
  /** 同名角色的递增序号。 */
  index: number;
  /** 角色卡 PNG 在应用沙箱中的完整文件路径。 */
  filePath: string;
}

/**
 * 角色卡 PNG 文件名中保存的紧凑标识。
 *
 * name 为角色名，index 为同名角色的递增序号；序列化后使用 Base64URL 编码，
 * 既可逆，又能避免文件名包含路径分隔符等特殊字符。
 */
interface RoleCardFileNameData {
  /** 角色名。 */
  name?: string;
  /** 同名角色序号。 */
  index?: number;
}

export class RoleCardStore extends BaseStore.Dir {
  /**
   * 角色卡存储单例。
   */
  private static _instance: RoleCardStore | undefined = undefined;
  /**
   * SillyTavern V1/V2 角色卡在 PNG tEXt 块中使用的元数据键。
   */
  private static readonly CHARA_METADATA_KEY: string = 'chara';
  /**
   * Character Card V3 在 PNG tEXt 块中使用的元数据键。
   */
  private static readonly CCV3_METADATA_KEY: string = 'ccv3';
  /**
   * PNG 文件固定的八字节签名，用于识别 PNG 文件。
   *
   * 前四个字节是 PNG 标识，后四个控制字节用于发现常见的文本模式转换错误。
   */
  private static readonly PNG_SIGNATURE: number[] = [
    0x89, // PNG 二进制文件的专用起始字节。
    0x50, // ASCII 字符 P。
    0x4E, // ASCII 字符 N。
    0x47, // ASCII 字符 G。
    0x0D, // 回车控制字符。
    0x0A, // 换行控制字符。
    0x1A, // 文件结束控制字符。
    0x0A// 换行控制字符。
  ];
  /**
   * PNG 块中“数据长度”字段的字节数。
   *
   * 该字段是一个四字节的大端无符号整数。
   */
  private static readonly PNG_CHUNK_LENGTH_FIELD_LENGTH: number = 4;
  /**
   * PNG 块中“块类型”字段的字节数。
   *
   * 例如 tEXt、IEND 都由四个 ASCII 字符组成。
   */
  private static readonly PNG_CHUNK_TYPE_FIELD_LENGTH: number = 4;
  /**
   * PNG 块头长度：四字节数据长度加四字节块类型。
   */
  private static readonly PNG_CHUNK_HEADER_LENGTH: number =
    RoleCardStore.PNG_CHUNK_LENGTH_FIELD_LENGTH + RoleCardStore.PNG_CHUNK_TYPE_FIELD_LENGTH;
  /**
   * PNG 块尾 CRC 校验码长度，固定为四字节。
   */
  private static readonly PNG_CHUNK_CRC_LENGTH: number = 4;
  /**
   * 单个字节可表示的数值进制，即 2 的 8 次方。
   */
  private static readonly PNG_BYTE_RADIX: number = 256;
  /**
   * PNG 四字节大端无符号长度中最高位字节的权重，即 256 的三次方。
   */
  private static readonly PNG_UINT32_HIGHEST_BYTE_FACTOR: number =
    RoleCardStore.PNG_BYTE_RADIX * RoleCardStore.PNG_BYTE_RADIX * RoleCardStore.PNG_BYTE_RADIX;
  /**
   * PNG 四字节大端无符号长度中第二个字节的权重，即 256 的二次方。
   */
  private static readonly PNG_UINT32_SECOND_BYTE_FACTOR: number =
    RoleCardStore.PNG_BYTE_RADIX * RoleCardStore.PNG_BYTE_RADIX;
  /**
   * PNG 四字节大端无符号长度中第三个字节的权重，即 256。
   */
  private static readonly PNG_UINT32_THIRD_BYTE_FACTOR: number = RoleCardStore.PNG_BYTE_RADIX;
  /**
   * PNG tEXt 块的四字节类型标识。
   */
  private static readonly PNG_TEXT_CHUNK_TYPE: string = 'tEXt';
  /**
   * PNG 文件结束块的四字节类型标识。
   */
  private static readonly PNG_IEND_CHUNK_TYPE: string = 'IEND';
  /**
   * PNG tEXt 块中 keyword 与 text 之间的 NUL 分隔字节。
   */
  private static readonly PNG_TEXT_SEPARATOR: number = 0;
  /**
   * PNG tEXt 块中 NUL 分隔字节本身占用一个字节。
   */
  private static readonly PNG_TEXT_SEPARATOR_LENGTH: number = 1;
  /**
   * 本地角色卡文件名的固定前缀，用于快速排除不属于当前格式的 PNG 文件。
   */
  private static readonly ROLE_CARD_FILE_PREFIX: string = 'rc_';
  /**
   * 角色卡图片使用的 PNG 文件扩展名。
   */
  private static readonly PNG_FILE_EXTENSION: string = '.png';
  /**
   * Base64 每组编码固定包含四个字符；解码无填充的 Base64URL 时据此补齐末尾填充符。
   */
  private static readonly BASE64_ENCODE_GROUP_LENGTH: number = 4;
  /**
   * 标准 Base64 的末尾填充字符。
   */
  private static readonly BASE64_PADDING_CHARACTER: string = '=';
  /**
   * 应用私有角色卡存储目录。
   */
  protected readonly dirname: string = 'setting/character_card';

  public static instance(): RoleCardStore {
    if (RoleCardStore._instance === undefined) {
      RoleCardStore._instance = new RoleCardStore();
    }
    return RoleCardStore._instance;
  }

  /**
   * 获取角色卡存储目录中的角色卡列表。
   *
   * 文件名使用 Base64URL 保存角色名与同名序号。本方法只解析文件名，不读取 PNG 元数据；
   * 无法解析或不符合当前格式的文件名会被跳过。
   *
   * @returns 按角色名、序号排序的角色卡列表；目录为空或读取失败时返回空数组。
   */
  public getCardList(): RoleCardListItem[] {
    const directoryPath = this.getDirPath();
    if (directoryPath === undefined) {
      return [];
    }
    const fileNames = this.list() ?? [];
    const textDecoder = util.TextDecoder.create('utf-8');
    const base64Helper = new util.Base64Helper();
    const cards: RoleCardListItem[] = [];
    for (let fileIndex = 0; fileIndex < fileNames.length; fileIndex++) {
      const card = this.parseRoleCardListItem(fileNames[fileIndex], directoryPath, textDecoder, base64Helper);
      if (card !== undefined) {
        cards.push(card);
      }
    }
    cards.sort((left: RoleCardListItem, right: RoleCardListItem): number => {
      if (left.name < right.name) {
        return -1;
      }
      if (left.name > right.name) {
        return 1;
      }
      return left.index - right.index;
    });
    return cards;
  }

  /**
   * 解析一个使用 Base64URL 命名的角色卡文件。
   *
   * 该解析由列表读取和写入序号分配共同使用，因此集中在这里，避免两个流程的
   * Base64URL 还原规则出现差异。
   *
   * @param fileName 角色卡目录中的文件名。
   * @param directoryPath 角色卡目录的完整路径。
   * @param textDecoder 用于还原 UTF-8 JSON 的解码器。
   * @param base64Helper 用于还原 Base64URL 内容的工具。
   * @returns 可解析时返回角色卡列表项，否则返回 undefined。
   */
  private parseRoleCardListItem(
    fileName: string,
    directoryPath: string,
    textDecoder: util.TextDecoder,
    base64Helper: util.Base64Helper
  ): RoleCardListItem | undefined {
    if (!fileName.startsWith(RoleCardStore.ROLE_CARD_FILE_PREFIX) ||
      !fileName.endsWith(RoleCardStore.PNG_FILE_EXTENSION)) {
      return undefined;
    }
    try {
      const encodedStart = RoleCardStore.ROLE_CARD_FILE_PREFIX.length;
      const encodedEnd = fileName.length - RoleCardStore.PNG_FILE_EXTENSION.length;
      const encodedFileNameData = fileName.substring(encodedStart, encodedEnd);
      let base64FileNameData = '';
      for (let characterIndex = 0; characterIndex < encodedFileNameData.length; characterIndex++) {
        const character = encodedFileNameData[characterIndex];
        if (character === '-') {
          base64FileNameData += '+';
        } else if (character === '_') {
          base64FileNameData += '/';
        } else {
          base64FileNameData += character;
        }
      }
      const base64Remainder = base64FileNameData.length % RoleCardStore.BASE64_ENCODE_GROUP_LENGTH;
      if (base64Remainder > 0) {
        for (let paddingIndex = base64Remainder;
          paddingIndex < RoleCardStore.BASE64_ENCODE_GROUP_LENGTH; paddingIndex++) {
          base64FileNameData += RoleCardStore.BASE64_PADDING_CHARACTER;
        }
      }
      const fileNameJson = textDecoder.decodeToString(base64Helper.decodeSync(base64FileNameData));
      const fileNameData = JSONUtil.jsonToBean<RoleCardFileNameData>(fileNameJson);
      if (fileNameData === undefined) {
        return undefined;
      }

      const name = fileNameData.name;
      const index = fileNameData.index;
      if (typeof name !== 'string' || typeof index !== 'number' || Math.floor(index) !== index || index < 1) {
        return undefined;
      }
      return {
        name: name,
        index: index,
        filePath: `${directoryPath}${FileUtil.separator}${fileName}`
      };
    } catch (error) {
      LogUtil.warn(this.className, '跳过无法解析的角色卡文件名：', fileName, error);
      return undefined;
    }
  }


  /**
   * 读取 PNG 角色卡元数据，解码 JSON 并标准化为当前角色卡模型。
   *
   * SillyTavern 将 V1/V2 数据保存到 chara tEXt 块，将 V3 数据保存到 ccv3 tEXt 块。
   * 两者同时存在时优先使用 ccv3；块中的文本是 UTF-8 JSON 的 Base64 编码结果。
   *
   * @param fileUri 图片选择器或文件选择器返回的 PNG URI。
   * 解码完成后依次尝试 V3、V2、V1 模型。V1/V2 成功后会立即升级为当前模型，
   * 因此调用方始终只会拿到 CharacterCard。
   *
   * @returns 标准化后的当前角色卡；读取、解析或模型校验失败时返回 undefined。
   */
  public async readCard(fileUri: string): Promise<CharacterCard | undefined> {
    let png: fileIo.File | undefined = undefined;
    try {
      // 图片选择器返回的是临时授权 URI，必须在当前回调中以只读方式打开。
      png = await FileUtil.open(fileUri, fileIo.OpenMode.READ_ONLY);
      const stat = await FileUtil.stat(png.fd);
      // 文件大小为 0 表示没有任何可供解析的 PNG 字节。
      if (stat.size <= 0) {
        throw new Error('角色卡文件为空');
      }

      // 一次性读取 PNG 原始字节，后续按 PNG 块结构定位角色卡 tEXt 元数据。
      const buffer = new ArrayBuffer(stat.size);
      // offset 为 0，表示从图片文件的第一个字节开始读取。
      const bytesRead = await FileUtil.read(png.fd, buffer, { offset: 0, length: stat.size });
      if (bytesRead !== stat.size) {
        throw new Error('角色卡文件未完整读取');
      }

      const bytes = new Uint8Array(buffer);
      // PNG 的前八个字节是固定文件签名，先排除非 PNG 文件。
      if (bytes.length < RoleCardStore.PNG_SIGNATURE.length) {
        throw new Error('角色卡文件不是有效的 PNG');
      }
      for (let index = 0; index < RoleCardStore.PNG_SIGNATURE.length; index++) {
        if (bytes[index] !== RoleCardStore.PNG_SIGNATURE[index]) {
          throw new Error('角色卡文件不是有效的 PNG');
        }
      }

      const textDecoder = util.TextDecoder.create('utf-8', { fatal: true });
      // 保留两个版本的候选值，以便在遍历完成后按规范优先使用 ccv3。
      let ccv3Metadata: string | undefined = undefined;
      let charaMetadata: string | undefined = undefined;
      let offset = RoleCardStore.PNG_SIGNATURE.length;
      let hasIendChunk = false;
      while (offset + RoleCardStore.PNG_CHUNK_HEADER_LENGTH + RoleCardStore.PNG_CHUNK_CRC_LENGTH <= bytes.length) {
        // 每个 PNG 块依次由四字节大端长度、四字节类型、数据和四字节 CRC 组成。
        // 第 1、2、3、4 个长度字节的权重依次是 256 的 3、2、1、0 次方。
        const chunkLength =
          bytes[offset] * RoleCardStore.PNG_UINT32_HIGHEST_BYTE_FACTOR +
            bytes[offset + 1] * RoleCardStore.PNG_UINT32_SECOND_BYTE_FACTOR +
            bytes[offset + 2] * RoleCardStore.PNG_UINT32_THIRD_BYTE_FACTOR + bytes[offset + 3];
        const chunkTypeOffset = offset + RoleCardStore.PNG_CHUNK_LENGTH_FIELD_LENGTH;
        const chunkDataOffset = offset + RoleCardStore.PNG_CHUNK_HEADER_LENGTH;
        if (chunkLength > bytes.length - chunkDataOffset - RoleCardStore.PNG_CHUNK_CRC_LENGTH) {
          throw new Error('PNG 块长度越界');
        }

        // 块类型固定为四个 ASCII 字节；解码后直接用 tEXt、IEND 字符串判断，避免散落的 ASCII 数值。
        const chunkType = textDecoder.decodeToString(
          bytes.slice(chunkTypeOffset, chunkTypeOffset + RoleCardStore.PNG_CHUNK_TYPE_FIELD_LENGTH)
        );
        const isTextChunk = chunkType === RoleCardStore.PNG_TEXT_CHUNK_TYPE;
        const isIendChunk = chunkType === RoleCardStore.PNG_IEND_CHUNK_TYPE;
        if (isTextChunk && (ccv3Metadata === undefined || charaMetadata === undefined)) {
          const chunkEnd = chunkDataOffset + chunkLength;
          let keyEnd = chunkDataOffset;
          // tEXt 数据格式为 keyword、空字节和 text，先查找分隔 keyword 的空字节。
          while (keyEnd < chunkEnd && bytes[keyEnd] !== RoleCardStore.PNG_TEXT_SEPARATOR) {
            keyEnd++;
          }
          if (keyEnd < chunkEnd) {
            // SillyTavern 对键名忽略大小写，因此统一转为小写后再匹配。
            const key = textDecoder.decodeToString(bytes.slice(chunkDataOffset, keyEnd)).toLowerCase();
            // 跳过 keyword 后紧随的一个 NUL 分隔字节，剩余内容才是角色卡 Base64 文本。
            const textStart = keyEnd + RoleCardStore.PNG_TEXT_SEPARATOR_LENGTH;
            const text = textDecoder.decodeToString(bytes.slice(textStart, chunkEnd));
            if (key === RoleCardStore.CCV3_METADATA_KEY && ccv3Metadata === undefined) {
              ccv3Metadata = text;
            } else if (key === RoleCardStore.CHARA_METADATA_KEY && charaMetadata === undefined) {
              charaMetadata = text;
            }
          }
        }

        if (isIendChunk) {
          // IEND 后不应再读取后续内容；缺少它的文件视为截断或损坏。
          hasIendChunk = true;
          break;
        }
        offset = chunkDataOffset + chunkLength + RoleCardStore.PNG_CHUNK_CRC_LENGTH;
      }

      if (!hasIendChunk) {
        throw new Error('PNG 文件缺少 IEND 块');
      }
      // V3 的 ccv3 优先于 V1/V2 的 chara，符合角色卡规范和 SillyTavern 的读取行为。
      const encodedJson = ccv3Metadata ?? charaMetadata;
      if (encodedJson === undefined) {
        throw new Error('PNG 中不存在 ccv3 或 chara 角色卡元数据');
      }
      // tEXt 中保存的是 Base64 文本：先还原 UTF-8 JSON 字符串，再按角色卡版本转换模型。
      const jsonBytes = new util.Base64Helper().decodeSync(encodedJson);
      const json = textDecoder.decodeToString(jsonBytes);
      const rootValue = JSONUtil.jsonToBean<ExtensionValue>(json);
      if (rootValue === undefined || rootValue === null || Array.isArray(rootValue) || typeof rootValue !== 'object') {
        throw new Error('角色卡 JSON 根值必须是对象');
      }

      // JSONUtil 只负责反序列化，不会根据角色卡规范拒绝缺失字段的对象。
      // 因此每个模型的 fromJson 都会校验自身版本和必需字段，再决定是否允许降级尝试。
      const v3Card = CharacterCard.fromJson(json, CharacterCardSpec.V3);
      if (v3Card !== undefined) {
        return v3Card;
      }
      const v2Card = CharacterCard.fromJson(json, CharacterCardSpec.V2);
      if (v2Card !== undefined) {
        return v2Card.toV3();
      }
      const v1Card = CharacterCardV1.fromJson(json);
      if (v1Card !== undefined) {
        return v1Card.toV3();
      }
      throw new Error('PNG 元数据不是受支持的 V1、V2 或 V3 角色卡');
    } catch (error) {
      LogUtil.error(this.className, '读取角色卡元数据失败：', fileUri, error);
      return undefined;
    } finally {
      if (png !== undefined) {
        try {
          await FileUtil.close(png.fd);
        } catch (error) {
          LogUtil.error(this.className, '关闭角色卡文件失败：', fileUri, error);
        }
      }
    }
  }

  /**
   * 将当前角色卡模型写入新的 PNG 角色卡文件。
   *
   * 写入时遵循 SillyTavern 的双块兼容策略：移除已有的 chara 与 ccv3 tEXt 块，
   * 保留 PNG 的其他块，并在 IEND 前依次写入 V2 兼容块和完整 V3 块。
   * 源 PNG 全程只读；生成的新图片会保存到本类 dirname 对应的应用沙箱目录，
   * 不会修改用户选择的源文件。
   *
   * @param sourcePngUri 提供头像和其他 PNG 块的源文件 URI。
   * @param card 要写入的当前角色卡模型。
   * @param deleteSourceFile 是否在新图片写入、同步并关闭后删除源文件，默认不删除。
   * 文件选择器返回的 URI 可能没有删除权限；此时保留新文件并返回 false。
   * @returns 写入成功且（请求删除时）源文件也删除成功时返回 true；否则返回 false。
   */
  public async writeCard(
    sourcePngUri: string,
    card: CharacterCard,
    deleteSourceFile: boolean = false
  ): Promise<boolean> {
    let readablePng: fileIo.File | undefined = undefined;
    let writablePng: fileIo.File | undefined = undefined;
    let targetPngPath = '';
    try {
      if (!CharacterCardCommonData.hasRequiredFields(card.data)) {
        throw new Error('待写入的角色卡缺少必需字段');
      }

      // 先完整读取原图，重组时只替换角色卡元数据，不重新编码图片像素和其他 PNG 块。
      readablePng = await FileUtil.open(sourcePngUri, fileIo.OpenMode.READ_ONLY);
      const stat = await FileUtil.stat(readablePng.fd);
      if (stat.size <= 0) {
        throw new Error('角色卡文件为空');
      }
      const inputBuffer = new ArrayBuffer(stat.size);
      const bytesRead = await FileUtil.read(readablePng.fd, inputBuffer, { offset: 0, length: stat.size });
      if (bytesRead !== stat.size) {
        throw new Error('角色卡文件未完整读取');
      }
      await FileUtil.close(readablePng.fd);
      readablePng = undefined;

      const inputBytes = new Uint8Array(inputBuffer);
      if (inputBytes.length < RoleCardStore.PNG_SIGNATURE.length) {
        throw new Error('角色卡文件不是有效的 PNG');
      }
      for (let index = 0; index < RoleCardStore.PNG_SIGNATURE.length; index++) {
        if (inputBytes[index] !== RoleCardStore.PNG_SIGNATURE[index]) {
          throw new Error('角色卡文件不是有效的 PNG');
        }
      }

      // ccv3 保存完整的当前模型；chara 使用同一主体数据和 V2 标识，供旧版读取器兼容读取。
      const v3Card = card.toV3();
      const v3Json = JSON.stringify(v3Card);
      if (v3Json === undefined) {
        throw new Error('角色卡 V3 JSON 序列化失败');
      }
      const v2Card = new CharacterCard();
      v2Card.spec = CharacterCardSpec.V2;
      v2Card.spec_version = CharacterCard.V2_SPEC_VERSION;
      v2Card.data = v3Card.data;
      const v2Json = JSON.stringify(v2Card);
      if (v2Json === undefined) {
        throw new Error('角色卡 V2 兼容 JSON 序列化失败');
      }

      const textEncoder = new util.TextEncoder('utf-8');
      const textDecoder = util.TextDecoder.create('utf-8');
      const base64Helper = new util.Base64Helper();
      const checksum = zlib.createChecksumSync();
      const textChunkTypeBytes = textEncoder.encodeInto(RoleCardStore.PNG_TEXT_CHUNK_TYPE);

      // 这个局部函数只服务于当前写入流程，用于组装 PNG 规定的 tEXt 块和 CRC32 校验值。
      const createTextChunk = async (key: string, text: string): Promise<Uint8Array> => {
        const keyBytes = textEncoder.encodeInto(key);
        const textBytes = textEncoder.encodeInto(text);
        const chunkDataLength = keyBytes.length + RoleCardStore.PNG_TEXT_SEPARATOR_LENGTH + textBytes.length;
        const chunk = new Uint8Array(
          RoleCardStore.PNG_CHUNK_HEADER_LENGTH + chunkDataLength + RoleCardStore.PNG_CHUNK_CRC_LENGTH
        );

        // PNG 块长度使用四字节大端无符号整数，按 256 的 3、2、1、0 次方写入。
        chunk[0] = Math.floor(chunkDataLength / RoleCardStore.PNG_UINT32_HIGHEST_BYTE_FACTOR) %
          RoleCardStore.PNG_BYTE_RADIX;
        chunk[1] = Math.floor(chunkDataLength / RoleCardStore.PNG_UINT32_SECOND_BYTE_FACTOR) %
          RoleCardStore.PNG_BYTE_RADIX;
        chunk[2] = Math.floor(chunkDataLength / RoleCardStore.PNG_UINT32_THIRD_BYTE_FACTOR) %
          RoleCardStore.PNG_BYTE_RADIX;
        chunk[3] = chunkDataLength % RoleCardStore.PNG_BYTE_RADIX;
        const chunkTypeOffset = RoleCardStore.PNG_CHUNK_LENGTH_FIELD_LENGTH;
        const chunkDataOffset = RoleCardStore.PNG_CHUNK_HEADER_LENGTH;
        chunk.set(textChunkTypeBytes, chunkTypeOffset);
        chunk.set(keyBytes, chunkDataOffset);
        // keyword 与 Base64 文本之间必须有一个 NUL 分隔字节。
        const textOffset = chunkDataOffset + keyBytes.length + RoleCardStore.PNG_TEXT_SEPARATOR_LENGTH;
        chunk.set(textBytes, textOffset);

        const crcDataEnd = chunkDataOffset + chunkDataLength;
        // PNG CRC32 的输入是四字节块类型和数据区，不包含长度字段及 CRC 字段本身。
        const crcInput = chunk.slice(chunkTypeOffset, crcDataEnd);
        const crcValue = (await checksum.crc32(0, crcInput.buffer)) >>> 0;
        const crcOffset = crcDataEnd;
        chunk[crcOffset] = Math.floor(crcValue / RoleCardStore.PNG_UINT32_HIGHEST_BYTE_FACTOR) %
          RoleCardStore.PNG_BYTE_RADIX;
        chunk[crcOffset + 1] = Math.floor(crcValue / RoleCardStore.PNG_UINT32_SECOND_BYTE_FACTOR) %
          RoleCardStore.PNG_BYTE_RADIX;
        chunk[crcOffset + 2] = Math.floor(crcValue / RoleCardStore.PNG_UINT32_THIRD_BYTE_FACTOR) %
          RoleCardStore.PNG_BYTE_RADIX;
        chunk[crcOffset + 3] = crcValue % RoleCardStore.PNG_BYTE_RADIX;
        return chunk;
      };

      const v2Text = base64Helper.encodeToStringSync(textEncoder.encodeInto(v2Json));
      const v3Text = base64Helper.encodeToStringSync(textEncoder.encodeInto(v3Json));
      const v2TextChunk = await createTextChunk(RoleCardStore.CHARA_METADATA_KEY, v2Text);
      const v3TextChunk = await createTextChunk(RoleCardStore.CCV3_METADATA_KEY, v3Text);
      const outputPieces: Uint8Array[] = [inputBytes.slice(0, RoleCardStore.PNG_SIGNATURE.length)];
      let offset = RoleCardStore.PNG_SIGNATURE.length;
      let hasIendChunk = false;
      while (offset + RoleCardStore.PNG_CHUNK_HEADER_LENGTH + RoleCardStore.PNG_CHUNK_CRC_LENGTH <= inputBytes.length) {
        const chunkLength =
          inputBytes[offset] * RoleCardStore.PNG_UINT32_HIGHEST_BYTE_FACTOR +
            inputBytes[offset + 1] * RoleCardStore.PNG_UINT32_SECOND_BYTE_FACTOR +
            inputBytes[offset + 2] * RoleCardStore.PNG_UINT32_THIRD_BYTE_FACTOR + inputBytes[offset + 3];
        const chunkTypeOffset = offset + RoleCardStore.PNG_CHUNK_LENGTH_FIELD_LENGTH;
        const chunkDataOffset = offset + RoleCardStore.PNG_CHUNK_HEADER_LENGTH;
        if (chunkLength > inputBytes.length - chunkDataOffset - RoleCardStore.PNG_CHUNK_CRC_LENGTH) {
          throw new Error('PNG 块长度越界');
        }
        const chunkEnd = chunkDataOffset + chunkLength + RoleCardStore.PNG_CHUNK_CRC_LENGTH;
        const chunkType = textDecoder.decodeToString(
          inputBytes.slice(chunkTypeOffset, chunkTypeOffset + RoleCardStore.PNG_CHUNK_TYPE_FIELD_LENGTH)
        );
        if (chunkType === RoleCardStore.PNG_IEND_CHUNK_TYPE) {
          // IEND 没有数据区，且必须是 PNG 的最后一个块；否则不对损坏输入执行写入。
          if (chunkLength !== 0 || chunkEnd !== inputBytes.length) {
            throw new Error('PNG 文件的 IEND 块无效');
          }
          // 新角色卡块必须位于 IEND 之前。
          outputPieces.push(v2TextChunk);
          outputPieces.push(v3TextChunk);
          outputPieces.push(inputBytes.slice(offset, chunkEnd));
          hasIendChunk = true;
          break;
        }

        let isRoleCardTextChunk = false;
        if (chunkType === RoleCardStore.PNG_TEXT_CHUNK_TYPE) {
          const chunkDataEnd = chunkDataOffset + chunkLength;
          let keyEnd = chunkDataOffset;
          while (keyEnd < chunkDataEnd && inputBytes[keyEnd] !== RoleCardStore.PNG_TEXT_SEPARATOR) {
            keyEnd++;
          }
          if (keyEnd < chunkDataEnd) {
            const key = textDecoder.decodeToString(inputBytes.slice(chunkDataOffset, keyEnd)).toLowerCase();
            // 同时删除大小写不同的旧 chara 与 ccv3，避免同一个 PNG 存在多个冲突版本。
            isRoleCardTextChunk = key === RoleCardStore.CHARA_METADATA_KEY || key === RoleCardStore.CCV3_METADATA_KEY;
          }
        }
        if (!isRoleCardTextChunk) {
          outputPieces.push(inputBytes.slice(offset, chunkEnd));
        }
        offset = chunkEnd;
      }

      if (!hasIendChunk) {
        throw new Error('PNG 文件缺少 IEND 块');
      }
      let outputLength = 0;
      for (let index = 0; index < outputPieces.length; index++) {
        outputLength += outputPieces[index].length;
      }
      const outputBytes = new Uint8Array(outputLength);
      let outputOffset = 0;
      for (let index = 0; index < outputPieces.length; index++) {
        const piece = outputPieces[index];
        outputBytes.set(piece, outputOffset);
        outputOffset += piece.length;
      }

      // 读取已有文件名中可逆的角色名与序号，为同名角色分配下一个连续序号。
      const cardName = card.data.name;
      let nextCardIndex = 1;
      const existingCards = this.getCardList();
      for (let cardIndex = 0; cardIndex < existingCards.length; cardIndex++) {
        const existingCard = existingCards[cardIndex];
        if (existingCard.name === cardName && existingCard.index >= nextCardIndex) {
          nextCardIndex = existingCard.index + 1;
        }
      }

      // 文件名只保存角色名与序号的紧凑 JSON；Base64URL 不含 /、+、=，可直接作为文件名主体。
      let targetFileName = '';
      do {
        const fileNameData: RoleCardFileNameData = { name: cardName, index: nextCardIndex };
        const fileNameJson = JSON.stringify(fileNameData);
        if (fileNameJson === undefined) {
          throw new Error('角色卡文件名 JSON 序列化失败');
        }
        const base64FileNameData = base64Helper.encodeToStringSync(textEncoder.encodeInto(fileNameJson));
        let base64UrlFileNameData = '';
        for (let characterIndex = 0; characterIndex < base64FileNameData.length; characterIndex++) {
          const character = base64FileNameData[characterIndex];
          if (character === '+') {
            base64UrlFileNameData += '-';
          } else if (character === '/') {
            base64UrlFileNameData += '_';
          } else if (character !== RoleCardStore.BASE64_PADDING_CHARACTER) {
            base64UrlFileNameData += character;
          }
        }
        targetFileName = `${RoleCardStore.ROLE_CARD_FILE_PREFIX}${base64UrlFileNameData}` +
          RoleCardStore.PNG_FILE_EXTENSION;
        targetPngPath = FileUtil.getFilesDirPath(this.dirname, targetFileName);
        nextCardIndex++;
      } while (FileUtil.accessSync(targetPngPath));

      // 目标文件是新建的沙箱文件；源 PNG 此时已关闭，因此写入过程不会修改用户导入的原图。
      writablePng = await FileUtil.open(
        targetPngPath,
        fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
      );
      const bytesWritten = await fileIo.write(writablePng.fd, outputBytes.buffer, {
        offset: 0,
        length: outputBytes.length
      });
      if (bytesWritten !== outputBytes.length) {
        throw new Error('角色卡文件未完整写入');
      }
      await fileIo.fsync(writablePng.fd);
      // 先关闭新文件再删除源文件，确保“删除源文件”选项不会影响已写入内容的可见性。
      await FileUtil.close(writablePng.fd);
      writablePng = undefined;
      if (deleteSourceFile) {
        await FileUtil.unlink(FileUtil.getFilePath(sourcePngUri));
      }
      return true;
    } catch (error) {
      LogUtil.error(this.className, '写入角色卡元数据失败：', sourcePngUri, targetPngPath, error);
      return false;
    } finally {
      if (writablePng !== undefined) {
        try {
          await FileUtil.close(writablePng.fd);
        } catch (error) {
          LogUtil.error(this.className, '关闭角色卡写入文件失败：', targetPngPath, error);
        }
      }
      if (readablePng !== undefined) {
        try {
          await FileUtil.close(readablePng.fd);
        } catch (error) {
          LogUtil.error(this.className, '关闭角色卡读取文件失败：', sourcePngUri, error);
        }
      }
    }
  }

}


/**
 * 扩展字段允许保存的数据类型。
 *
 * Object 可以表示：
 * - 普通对象
 * - 数组
 * - 自定义数据对象
 */
export type ExtensionValue = string | number | boolean | Object | null;


/**
 * 扩展字段集合。
 *
 * 用于保存 SillyTavern 或其他应用添加的自定义字段。
 */
export type ExtensionRecord = Record<string, ExtensionValue>;


/**
 * 模型层级：
 *
 * CharacterCard
 * └─ data: CharacterCardData（继承 CharacterCardCommonData）
 *    ├─ character_book: CharacterBook
 *    │  └─ entries: CharacterBookEntry[]
 *    └─ assets: CharacterCardAsset[]
 *
 * CharacterCardV1（继承 CharacterCardCommonData）
 */


/**
 * 当前角色卡顶层数据模型。
 *
 * 当前模型的对外输出对应 Character Card V3 规范。读取时也可暂存 V2 输入，
 * 因为两者的顶层结构和 data 字段兼容；V2 输入随后通过 toV3 升级为当前格式。
 */
export class CharacterCard {
  /**
   * 新建角色卡或将 V1/V2 升级为当前格式时使用的默认规范版本。
   *
   * 读取 V3 卡时会保留原始 spec_version，以兼容未来的非破坏性修订版本。
   */
  public static readonly DEFAULT_SPEC_VERSION: string = '3.0';
  /**
   * 写入 chara 兼容块时使用的 Character Card V2 规范版本。
   */
  public static readonly V2_SPEC_VERSION: string = '2.0';

  /**
   * 将 JSON 字符串解析为指定规范的角色卡。
   *
   * JSONUtil 仅负责把 JSON 映射为对象，不会校验角色卡规范；这里必须确认
   * spec 与期望规范一致，且 data 包含角色卡共有的六个基础字段，避免把任意 JSON
   * 误判为 V2 或 V3。
   *
   * @param json PNG 元数据解码后的 JSON 字符串。
   * @param expectedSpec 期望解析的 V2 或 V3 规范标识。
   * @returns 有效的角色卡；不符合期望规范结构时返回 undefined。
   */
  public static fromJson(json: string, expectedSpec: CharacterCardSpec): CharacterCard | undefined {
    const source = JSONUtil.jsonToBean(json, CharacterCard);
    if (source?.spec !== expectedSpec || !CharacterCardCommonData.hasRequiredFields(source.data)) {
      return undefined;
    }

    const result = new CharacterCard();
    result.spec = expectedSpec;
    if (typeof source.spec_version === 'string') {
      result.spec_version = source.spec_version;
    }
    result.data = CharacterCardData.fromSource(source.data);
    return result;
  }

  /**
   * 将临时承载的 V2 输入升级为当前 V3 角色卡。
   *
   * 已经是 V3 时直接返回自身；V2 时新建 V3 根对象，从而写入当前默认的
   * spec 和 spec_version，同时保留已经标准化的 data。
   *
   * @returns 当前 V3 角色卡。
   */
  public toV3(): CharacterCard {
    if (this.spec === CharacterCardSpec.V3) {
      return this;
    }
    const result = new CharacterCard();
    result.data = CharacterCardData.fromSource(this.data);
    return result;
  }

  /**
   * 角色卡规范标识。
   *
   * JSON 字段名：spec
   * 对外输出固定为 chara_card_v3；读取 V2 时会在 toV3 前临时保留 chara_card_v2。
   */
  public spec: CharacterCardSpec = CharacterCardSpec.V3;
  /**
   * 角色卡规范版本。
   *
   * JSON 字段名：spec_version
   * 新建卡片默认使用 3.0；读取 V3 卡时会保留原始版本字符串。
   * V2 输入的原始值只在转换过程临时保留，toV3 后会写入当前默认版本。
   */
  public spec_version: string = CharacterCard.DEFAULT_SPEC_VERSION;
  /**
   * 角色卡主体数据。
   *
   * JSON 字段名：data
   */
  public data: CharacterCardData = new CharacterCardData();
}


/**
 * V1、V2 与当前角色卡共有的角色基础数据。
 */
export class CharacterCardCommonData {
  /**
   * 角色名称。
   *
   * JSON 字段名：name
   */
  public name: string = '';
  /**
   * 角色详细描述。
   *
   * JSON 字段名：description
   */
  public description: string = '';
  /**
   * 角色性格。
   *
   * JSON 字段名：personality
   */
  public personality: string = '';
  /**
   * 当前对话场景或故事背景。
   *
   * JSON 字段名：scenario
   */
  public scenario: string = '';
  /**
   * 角色发送的第一条消息。
   *
   * JSON 字段名：first_mes
   */
  public first_mes: string = '';
  /**
   * 示例对话。
   *
   * JSON 字段名：mes_example
   */
  public mes_example: string = '';

  /**
   * 判断对象是否具备角色卡三个版本共有的六个必需文本字段。
   *
   * JSONUtil 不会校验字段类型。此处只承担“是否足以认定为角色卡”的最小校验，
   * 其他可选字段由各版本模型在转换时保留默认值或原始值。
   *
   * @param value 待校验的数据对象。
   * @returns 六个基础字段均为字符串时返回 true。
   */
  public static hasRequiredFields(value: Object | undefined | null): boolean {
    if (value === undefined || value === null || Array.isArray(value) || typeof value !== 'object') {
      return false;
    }
    const data = value as CharacterCardCommonData;
    return typeof data.name === 'string' && typeof data.description === 'string' &&
      typeof data.personality === 'string' && typeof data.scenario === 'string' &&
      typeof data.first_mes === 'string' && typeof data.mes_example === 'string';
  }

  /**
   * 复制三个版本共有的六个基础字段。
   *
   * V1 的字段位于根对象，V2/V3 位于 data；将这段映射收敛到共同父类后，
   * V1 升级逻辑不再需要在存储层重复按 JSON 字段名搬运。
   *
   * @param target 接收基础字段的当前数据模型。
   */
  protected copyCommonFieldsTo(target: CharacterCardCommonData): void {
    target.name = this.name;
    target.description = this.description;
    target.personality = this.personality;
    target.scenario = this.scenario;
    target.first_mes = this.first_mes;
    target.mes_example = this.mes_example;
  }
}

/**
 * 当前角色卡的主体数据模型。
 *
 * 字段包含 V2 的共有定义与当前 V3 规范的新增定义；从 V1/V2 读取时，
 * 新版字段保持各自的兼容默认值。
 */
export class CharacterCardData extends CharacterCardCommonData {
  /**
   * 角色卡作者备注。
   *
   * JSON 字段名：creator_notes
   */
  public creator_notes: string = '';
  /**
   * 角色专属系统提示词。
   *
   * JSON 字段名：system_prompt
   */
  public system_prompt: string = '';
  /**
   * 对话历史之后插入的附加指令。
   *
   * JSON 字段名：post_history_instructions
   */
  public post_history_instructions: string = '';
  /**
   * 备选开场白列表。
   *
   * JSON 字段名：alternate_greetings
   */
  public alternate_greetings: string[] = [];
  /**
   * 角色卡内嵌世界书。
   *
   * JSON 字段名：character_book
   */
  public character_book: CharacterBook | undefined = undefined;
  /**
   * 角色标签列表。
   *
   * JSON 字段名：tags
   */
  public tags: string[] = [];
  /**
   * 角色卡作者名称。
   *
   * JSON 字段名：creator
   */
  public creator: string = '';
  /**
   * 角色卡自身版本。
   *
   * JSON 字段名：character_version
   */
  public character_version: string = '';
  /**
   * 角色卡扩展字段。
   *
   * JSON 字段名：extensions
   */
  public extensions: ExtensionRecord = {};
  // 以下字段由当前 V3 规范新增；缺失时使用上述类字段定义的默认值。
  /**
   * 角色卡关联资源列表。
   *
   * 字段缺失时保持 undefined。消费端应按 V3 规范把它视为一个指向
   * 当前角色卡图片的默认主头像，而不能把缺失等同于空数组。
   *
   * JSON 字段名：assets
   */
  public assets: CharacterCardAsset[] | undefined = undefined;
  /**
   * 角色昵称。
   *
   * 设置后，提示词中的角色名称占位符可以优先使用该值。
   *
   * JSON 字段名：nickname
   */
  public nickname: string | undefined = undefined;
  /**
   * 多语言作者备注。
   *
   * 键为 ISO 639-1 语言代码，值为对应语言的作者备注。
   *
   * JSON 字段名：creator_notes_multilingual
   */
  public creator_notes_multilingual: Record<string, string> | undefined = undefined;
  /**
   * 角色卡来源标识或地址列表。
   *
   * JSON 字段名：source
   */
  public source: string[] | undefined = undefined;
  /**
   * 仅用于群聊的备选开场白。
   *
   * 这是 V3 必需字段；读取 V1、V2 或不完整 V3 时默认使用空数组。
   *
   * JSON 字段名：group_only_greetings
   */
  public group_only_greetings: string[] = [];
  /**
   * 角色卡创建时间，单位为 UTC Unix 秒。
   *
   * JSON 字段名：creation_date
   */
  public creation_date: number | undefined = undefined;
  /**
   * 角色卡最后修改时间，单位为 UTC Unix 秒。
   *
   * JSON 字段名：modification_date
   */
  public modification_date: number | undefined = undefined;

  /**
   * 将 JSONUtil 反序列化出的 data 普通对象补全为当前数据模型。
   *
   * JSONUtil 的嵌套对象不会自动执行模型字段初始化。这里通过合并到新实例，
   * 让缺失的 V3 字段继续保留类中定义的默认值，并将世界书与资源转换为对应模型。
   *
   * @param source V2/V3 JSON 中的 data 对象。
   * @returns 具有默认值的当前角色卡数据模型。
   */
  public static fromSource(source: Object): CharacterCardData {
    const result = new CharacterCardData();
    ObjectUtil.assign(result, source);
    const sourceData = source as CharacterCardData;

    // 历史导出偶尔把数组字段写成单个字符串；统一在模型层恢复为字符串数组。
    const sourceTags: string[] | string = sourceData.tags as string[] | string;
    result.tags = [];
    if (Array.isArray(sourceTags)) {
      for (let index = 0; index < sourceTags.length; index++) {
        const tag = sourceTags[index];
        if (typeof tag === 'string') {
          result.tags.push(tag);
        }
      }
    } else if (typeof sourceTags === 'string') {
      const tags = sourceTags.split(',');
      for (let index = 0; index < tags.length; index++) {
        const tag = tags[index].trim();
        if (tag.length > 0) {
          result.tags.push(tag);
        }
      }
    }

    const sourceAlternateGreetings: string[] | string =
      sourceData.alternate_greetings as string[] | string;
    result.alternate_greetings = [];
    if (Array.isArray(sourceAlternateGreetings)) {
      for (let index = 0; index < sourceAlternateGreetings.length; index++) {
        const greeting = sourceAlternateGreetings[index];
        if (typeof greeting === 'string') {
          result.alternate_greetings.push(greeting);
        }
      }
    } else if (typeof sourceAlternateGreetings === 'string') {
      result.alternate_greetings.push(sourceAlternateGreetings);
    }

    const sourceGroupOnlyGreetings: string[] | string =
      sourceData.group_only_greetings as string[] | string;
    result.group_only_greetings = [];
    if (Array.isArray(sourceGroupOnlyGreetings)) {
      for (let index = 0; index < sourceGroupOnlyGreetings.length; index++) {
        const greeting = sourceGroupOnlyGreetings[index];
        if (typeof greeting === 'string') {
          result.group_only_greetings.push(greeting);
        }
      }
    } else if (typeof sourceGroupOnlyGreetings === 'string') {
      result.group_only_greetings.push(sourceGroupOnlyGreetings);
    }

    // 嵌套世界书需要单独合并，避免缺失 entries 时丢失空数组默认值。
    result.character_book = undefined;
    const sourceBookValue = sourceData.character_book;
    if (sourceBookValue !== undefined && sourceBookValue !== null && !Array.isArray(sourceBookValue) &&
      typeof sourceBookValue === 'object') {
      const book = new CharacterBook();
      ObjectUtil.assign(book, sourceBookValue as Object);
      if (Array.isArray(sourceBookValue.entries)) {
        const entries: CharacterBookEntry[] = [];
        for (let index = 0; index < sourceBookValue.entries.length; index++) {
          const sourceEntry = sourceBookValue.entries[index];
          if (sourceEntry !== undefined && sourceEntry !== null && !Array.isArray(sourceEntry) &&
            typeof sourceEntry === 'object') {
            const entry = new CharacterBookEntry();
            ObjectUtil.assign(entry, sourceEntry as Object);
            entries.push(entry);
          }
        }
        book.entries = entries;
      } else {
        book.entries = [];
      }
      result.character_book = book;
    }

    // assets 缺失与空数组含义不同：缺失保持 undefined，存在时才逐项补全默认值。
    result.assets = undefined;
    if (Array.isArray(sourceData.assets)) {
      const assets: CharacterCardAsset[] = [];
      for (let index = 0; index < sourceData.assets.length; index++) {
        const sourceAsset = sourceData.assets[index];
        if (sourceAsset !== undefined && sourceAsset !== null && !Array.isArray(sourceAsset) &&
          typeof sourceAsset === 'object') {
          const asset = new CharacterCardAsset();
          ObjectUtil.assign(asset, sourceAsset as Object);
          assets.push(asset);
        }
      }
      result.assets = assets;
    }
    return result;
  }
}


/**
 * Character Card V1 顶层数据模型。
 *
 * V1 没有 spec、spec_version 和 data 包装，六个标准字段直接位于根对象。
 * 其余字段用于承载 SillyTavern 常见的 V1 扩展。
 */
export class CharacterCardV1 extends CharacterCardCommonData {
  /**
   * V1 旧扩展迁移到当前 extensions 时使用的键名。
   */
  private static readonly TALKATIVENESS_EXTENSION_KEY: string = 'talkativeness';
  private static readonly FAVORITE_EXTENSION_KEY: string = 'fav';

  /**
   * V1 不定义该字段；仅用于反序列化后确认输入没有携带 V2/V3 或未知规范标识。
   *
   * JSON 字段名：spec
   */
  public spec: string | undefined = undefined;

  /**
   * SillyTavern V1 作者备注。
   *
   * JSON 字段名：creatorcomment
   */
  public creatorcomment: string | undefined = undefined;
  /**
   * 标签列表。
   *
   * 部分旧导出会写入逗号分隔字符串，因此读取时同时兼容字符串和字符串数组。
   *
   * JSON 字段名：tags
   */
  public tags: string[] | string = [];
  /**
   * SillyTavern 角色发言倾向。
   *
   * JSON 字段名：talkativeness
   */
  public talkativeness: string | number | undefined = undefined;
  /**
   * SillyTavern 收藏状态。
   *
   * JSON 字段名：fav
   */
  public fav: boolean | undefined = undefined;
  /**
   * 已归一化的扩展字段。
   *
   * JSON 字段名：extensions
   */
  public extensions: ExtensionRecord = {};

  /**
   * 将 JSON 字符串解析为 V1 输入模型。
   *
   * V1 没有 spec 字段，且六个基础字段直接位于根对象；两项同时成立才接受，
   * 以免把未知 spec 的对象错误降级为 V1。
   *
   * @param json PNG 元数据解码后的 JSON 字符串。
   * @returns 有效的 V1 输入模型；不符合 V1 结构时返回 undefined。
   */
  public static fromJson(json: string): CharacterCardV1 | undefined {
    const source = JSONUtil.jsonToBean(json, CharacterCardV1);
    if (source === undefined || source.spec !== undefined ||
      !CharacterCardCommonData.hasRequiredFields(source)) {
      return undefined;
    }

    const result = new CharacterCardV1();
    ObjectUtil.assign(result, source);
    return result;
  }

  /**
   * 将 V1 输入模型升级为当前 V3 模型。
   *
   * 共有基础字段由父类统一复制；V1 独有的作者备注和扩展字段在这里映射到
   * 当前字段，避免存储层依赖一长串 JSON 字段名。
   *
   * @returns 当前 V3 角色卡。
   */
  public toV3(): CharacterCard {
    const result = new CharacterCard();
    this.copyCommonFieldsTo(result.data);
    if (typeof this.creatorcomment === 'string') {
      result.data.creator_notes = this.creatorcomment;
    }
    if (Array.isArray(this.tags)) {
      result.data.tags = this.tags;
    } else if (typeof this.tags === 'string') {
      const tags = this.tags.split(',');
      for (let index = 0; index < tags.length; index++) {
        const tag = tags[index].trim();
        if (tag.length > 0) {
          result.data.tags.push(tag);
        }
      }
    }
    if (this.extensions !== null && !Array.isArray(this.extensions) && typeof this.extensions === 'object') {
      ObjectUtil.assign(result.data.extensions, this.extensions);
    }
    if (this.talkativeness !== undefined) {
      result.data.extensions[CharacterCardV1.TALKATIVENESS_EXTENSION_KEY] = this.talkativeness;
    }
    if (this.fav !== undefined) {
      result.data.extensions[CharacterCardV1.FAVORITE_EXTENSION_KEY] = this.fav;
    }
    return result;
  }
}


/**
 * 角色卡规范类型。
 */
export enum CharacterCardSpec {
  /**
   * Character Card V2。
   */
  V2 = 'chara_card_v2',

  /**
   * Character Card V3。
   */
  V3 = 'chara_card_v3'
}


/**
 * 世界书条目的插入位置。
 */
export enum CharacterBookPosition {
  /**
   * 插入到角色定义之前。
   */
  BEFORE_CHAR = 'before_char',

  /**
   * 插入到角色定义之后。
   */
  AFTER_CHAR = 'after_char'
}


/**
 * Character Card V2/V3 世界书条目。
 */
export class CharacterBookEntry {
  /**
   * 主触发关键词列表。
   *
   * 当聊天内容匹配其中任意关键词时，
   * 该条目可能被激活。
   *
   * JSON 字段名：keys
   */
  public keys: string[] = [];
  /**
   * 条目正文。
   *
   * 条目激活后，该内容将被插入模型提示词。
   *
   * JSON 字段名：content
   */
  public content: string = '';
  /**
   * 条目扩展字段。
   *
   * 用于保存应用或插件添加的自定义数据。
   *
   * JSON 字段名：extensions
   */
  public extensions: ExtensionRecord = {};
  /**
   * 是否启用该条目。
   *
   * JSON 字段名：enabled
   */
  public enabled: boolean = true;
  /**
   * 条目插入顺序。
   *
   * 用于确定多个条目同时激活时的排列顺序。
   * 未提供该字段时使用角色卡规范的默认值 100；数值越小越靠前。
   *
   * JSON 字段名：insertion_order
   */
  public insertion_order: number = 100;
  /**
   * 是否把 keys 中的内容作为正则表达式匹配。
   *
   * 这是 V3 世界书条目的必需字段。V1/V2 条目缺失该字段时默认使用 false，
   * 以保留旧版本的普通字符串匹配行为。
   *
   * JSON 字段名：use_regex
   */
  public use_regex: boolean = false;
  /**
   * 关键词匹配时是否区分大小写。
   *
   * JSON 字段名：case_sensitive
   */
  public case_sensitive: boolean | undefined = undefined;
  /**
   * 条目名称。
   *
   * 主要用于界面展示和管理。
   *
   * JSON 字段名：name
   */
  public name: string | undefined = undefined;
  /**
   * 条目优先级。
   *
   * 可以用于决定 Token 预算不足时优先保留哪些条目。
   *
   * JSON 字段名：priority
   */
  public priority: number | undefined = undefined;
  /**
   * 条目唯一编号。
   *
   * V2 只定义数字，V3 同时允许字符串和数字。
   *
   * JSON 字段名：id
   */
  public id: string | number | undefined = undefined;
  /**
   * 条目备注。
   *
   * 主要供用户查看，通常不会插入模型提示词。
   *
   * JSON 字段名：comment
   */
  public comment: string | undefined = undefined;
  /**
   * 是否启用次级关键词筛选。
   *
   * 启用后，除了主关键词之外，
   * 还会结合 secondary_keys 判断是否激活。
   *
   * JSON 字段名：selective
   */
  public selective: boolean | undefined = undefined;
  /**
   * 次级关键词列表。
   *
   * 与 selective 字段配合使用。
   *
   * JSON 字段名：secondary_keys
   */
  public secondary_keys: string[] | undefined = undefined;
  /**
   * 是否始终激活。
   *
   * 设置为 true 时，条目不需要匹配关键词即可生效。
   *
   * JSON 字段名：constant
   */
  public constant: boolean | undefined = undefined;
  /**
   * 条目的插入位置。
   *
   * 可选值：
   * - before_char
   * - after_char
   *
   * JSON 字段名：position
   */
  public position: CharacterBookPosition | undefined = undefined;
}


/**
 * 当前角色卡内嵌世界书。
 */
export class CharacterBook {
  /**
   * 世界书名称。
   *
   * JSON 字段名：name
   */
  public name: string | undefined = undefined;
  /**
   * 世界书描述。
   *
   * JSON 字段名：description
   */
  public description: string | undefined = undefined;
  /**
   * 默认聊天记录扫描深度。
   *
   * 表示检查最近多少条聊天消息以匹配关键词。
   *
   * JSON 字段名：scan_depth
   */
  public scan_depth: number | undefined = undefined;
  /**
   * 世界书可使用的 Token 预算。
   *
   * JSON 字段名：token_budget
   */
  public token_budget: number | undefined = undefined;
  /**
   * 是否启用递归扫描。
   *
   * 启用后，已经激活的世界书内容也可以继续触发其他条目。
   *
   * JSON 字段名：recursive_scanning
   */
  public recursive_scanning: boolean | undefined = undefined;
  /**
   * 世界书扩展字段。
   *
   * 用于保存应用或插件添加的自定义数据。
   *
   * JSON 字段名：extensions
   */
  public extensions: ExtensionRecord = {};
  /**
   * 世界书条目列表。
   *
   * JSON 字段名：entries
   */
  public entries: CharacterBookEntry[] = [];
}


/**
 * 当前角色卡资源描述。
 */
export class CharacterCardAsset {
  /**
   * 资源用途，例如 icon、background 或 emotion。
   *
   * JSON 字段名：type
   */
  public type: string = '';
  /**
   * 资源地址，可以是网络地址、数据地址、内嵌资源地址或 ccdefault:。
   *
   * JSON 字段名：uri
   */
  public uri: string = '';
  /**
   * 资源名称；主头像通常使用 main。
   *
   * JSON 字段名：name
   */
  public name: string = '';
  /**
   * 不带点号的小写扩展名。
   *
   * JSON 字段名：ext
   */
  public ext: string = '';
}
