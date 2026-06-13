import { describe, it, expect } from '@ohos/hypium';
import { ImageMetadataRuntime } from '../../Index';
export default function imageMetadataUnitTest() {
  describe('ImageMetadataRuntime', () => {
    it('检测 PNG 格式', 0, () => {
      const rt = new ImageMetadataRuntime();
      const png = new ArrayBuffer(8);
      const view = new Uint8Array(png);
      view[0]=0x89; view[1]=0x50; view[2]=0x4E; view[3]=0x47;
      view[4]=0x0D; view[5]=0x0A; view[6]=0x1A; view[7]=0x0A;
      expect(rt.detectFormat(png)).assertEqual('png');
      expect(rt.isValidImage(png)).assertTrue();
    });
    it('检测 JPEG 格式', 0, () => {
      const rt = new ImageMetadataRuntime();
      const jpg = new ArrayBuffer(4);
      const v = new Uint8Array(jpg);
      v[0]=0xFF; v[1]=0xD8; v[2]=0x00; v[3]=0x00;
      expect(rt.detectFormat(jpg)).assertEqual('jpeg');
    });
    it('写入并提取 WebP 角色卡 metadata', 0, () => {
      const rt = new ImageMetadataRuntime();
      const webp = makeMinimalWebp();
      const cardJson = '{"spec":"chara_card_v2","data":{"name":"WebP"}}';

      expect(rt.detectFormat(webp)).assertEqual('webp');
      const written = rt.writeMetadata({
        format: 'webp',
        characterCardJson: cardJson,
        outputPath: 'card.webp',
        sourceData: webp,
      });
      const result = rt.extractCharacterCard(written);

      expect(result.metadata.hasCharacterCard).assertTrue();
      expect(result.characterCardJson).assertEqual(cardJson);
    });
    it('未知格式检测', 0, () => {
      const rt = new ImageMetadataRuntime();
      const unknown = new ArrayBuffer(2);
      const u = new Uint8Array(unknown);
      u[0]=0x00; u[1]=0x00;
      expect(rt.detectFormat(unknown)).assertEqual('unknown');
      expect(rt.isValidImage(unknown)).assertFalse();
    });
    it('忽略长度越界的 PNG chunk', 0, () => {
      const rt = new ImageMetadataRuntime();
      const png = new ArrayBuffer(20);
      const v = new Uint8Array(png);
      v[0]=0x89; v[1]=0x50; v[2]=0x4E; v[3]=0x47;
      v[4]=0x0D; v[5]=0x0A; v[6]=0x1A; v[7]=0x0A;
      v[8]=0x00; v[9]=0x00; v[10]=0x00; v[11]=0x20;
      v[12]=0x74; v[13]=0x45; v[14]=0x58; v[15]=0x74;
      const metadata = rt.extractMetadata(png);

      expect(metadata.format).assertEqual('png');
      expect(metadata.rawChunks.length).assertEqual(0);
      expect(metadata.hasCharacterCard).assertFalse();
    });
    it('写入并提取 PNG 角色卡 metadata', 0, () => {
      const rt = new ImageMetadataRuntime();
      // card JSON 字符串。
      const cardJson = '{"spec":"chara_card_v2","data":{"name":"测试"}}';
      const written = rt.writePngCharacterCard(makeMinimalPng(), cardJson);
      const result = rt.extractCharacterCard(written);

      expect(result.metadata.hasCharacterCard).assertTrue();
      expect(result.characterCardJson).assertEqual(cardJson);
      expect(result.metadata.rawChunks[0].type).assertEqual('tEXt');
      expect(result.metadata.rawChunks[1].type).assertEqual('IEND');
    });
    it('通过 writeMetadata 写入 PNG 数据并替换旧角色卡块', 0, () => {
      const rt = new ImageMetadataRuntime();
      const first = rt.writePngCharacterCard(makeMinimalPng(), '{"name":"旧"}');
      const second = rt.writeMetadata({
        format: 'png',
        characterCardJson: '{"name":"新"}',
        outputPath: 'card.png',
        sourceData: first,
      });
      const result = rt.extractCharacterCard(second);
      let textChunkCount = 0;
      for (let index = 0; index < result.metadata.rawChunks.length; index += 1) {
        if (result.metadata.rawChunks[index].type === 'tEXt') {
          textChunkCount += 1;
        }
      }

      expect(result.characterCardJson).assertEqual('{"name":"新"}');
      expect(textChunkCount).assertEqual(1);
    });
  });
}

/**
 * 封装单元测试中的 makeMinimalPng 步骤，供公开方法复用。
 */
function makeMinimalPng(): ArrayBuffer {
  const bytes = new Uint8Array(20);
  bytes[0]=0x89; bytes[1]=0x50; bytes[2]=0x4E; bytes[3]=0x47;
  bytes[4]=0x0D; bytes[5]=0x0A; bytes[6]=0x1A; bytes[7]=0x0A;
  bytes[8]=0x00; bytes[9]=0x00; bytes[10]=0x00; bytes[11]=0x00;
  bytes[12]=0x49; bytes[13]=0x45; bytes[14]=0x4E; bytes[15]=0x44;
  bytes[16]=0xAE; bytes[17]=0x42; bytes[18]=0x60; bytes[19]=0x82;
  return bytes.buffer;
}

/**
 * 封装单元测试中的 makeMinimalWebp 步骤，供公开方法复用。
 */
function makeMinimalWebp(): ArrayBuffer {
  const bytes = new Uint8Array(12);
  bytes[0]=0x52; bytes[1]=0x49; bytes[2]=0x46; bytes[3]=0x46;
  bytes[4]=0x04; bytes[5]=0x00; bytes[6]=0x00; bytes[7]=0x00;
  bytes[8]=0x57; bytes[9]=0x45; bytes[10]=0x42; bytes[11]=0x50;
  return bytes.buffer;
}
