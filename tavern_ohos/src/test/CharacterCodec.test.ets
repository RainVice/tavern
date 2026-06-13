import { describe, it, expect } from '@ohos/hypium';
import { CharacterCodecRuntime, type CharacterCodecResult } from '../../Index';

export default function characterCodecUnitTest() {
  describe('CharacterCodecRuntime', () => {
    it('解析 V2 角色卡', 0, () => {
      const runtime = new CharacterCodecRuntime();
      const v2 = '{"spec":"chara_card_v2","spec_version":"2.0","data":{"name":"测试","description":"描述","personality":"性格","scenario":"场景","first_mes":"你好","mes_example":"示例","tags":["tag1"],"extensions":{"talkativeness":0.8}}}';
      const result = runtime.parseCharacterJson(v2);
      expect(result.format).assertEqual('v2');
      expect(result.name).assertEqual('测试');
      expect(result.tags[0]).assertEqual('tag1');
      expect(result.extensions['talkativeness']).assertEqual('0.8');
    });

    it('保留 V2 角色卡中的未知 extensions 字段', 0, () => {
      const runtime = new CharacterCodecRuntime();
      const v2 = '{"spec":"chara_card_v2","spec_version":"2.0","data":{"name":"扩展","extensions":{"talkativeness":0.7,"fav":true,"world":"main"}}}';

      const result = runtime.parseCharacterJson(v2);

      expect(result.extensions['talkativeness']).assertEqual('0.7');
      expect(result.extensions['fav']).assertEqual('true');
      expect(result.extensions['world']).assertEqual('main');
    });

    it('解析 V1 角色卡', 0, () => {
      const runtime = new CharacterCodecRuntime();
      const v1 = JSON.stringify({ name: 'V1角色', description: 'V1描述', personality: '', scenario: '', first_mes: '你好', mes_example: '' });
      const result = runtime.parseCharacterJson(v1);
      expect(result.format).assertEqual('v1');
      expect(result.name).assertEqual('V1角色');
    });

    it('识别卡片格式', 0, () => {
      const runtime = new CharacterCodecRuntime();
      expect(runtime.detectFormat(JSON.stringify({ spec: 'chara_card_v2' }))).assertEqual('v2');
      expect(runtime.detectFormat(JSON.stringify({ name: 'test' }))).assertEqual('v1');
      expect(runtime.detectFormat(JSON.stringify({ spec: 'charx', characters: [] }))).assertEqual('charx');
      expect(runtime.detectFormat('invalid')).assertEqual('unknown');
    });

    it('导出为 V2 格式', 0, () => {
      const runtime = new CharacterCodecRuntime();
      const src: CharacterCodecResult = { format: 'v2', raw: '', name: '导出', description: 'D', personality: 'P', scenario: 'S', firstMessage: 'F', exampleDialogue: 'E', creatorNotes: '', systemPrompt: '', postHistoryInstructions: '', creator: '', characterVersion: '', tags: ['a'], alternateGreetings: [], extensions: {} };
      const json = runtime.exportToV2(src);
      expect(json).assertContain('"spec":"chara_card_v2"');
      expect(json).assertContain('"name":"导出"');
      expect(json).assertContain('"tags":["a"]');
    });

    it('解析 CharacterBook', 0, () => {
      const runtime = new CharacterCodecRuntime();
      const book = runtime.parseCharacterBook('{"name":"测试书","entries":[{"id":"1","keys":["key1"],"content":"内容","enabled":true}]}');
      expect(book.name).assertEqual('测试书');
      expect(book.entries.length).assertEqual(1);
      expect(book.entries[0].keys[0]).assertEqual('key1');
    });

    it('导出并解析 PNG metadata 角色卡', 0, () => {
      const runtime = new CharacterCodecRuntime();
      const src: CharacterCodecResult = { format: 'v2', raw: '', name: 'PNG角色', description: 'D', personality: 'P', scenario: 'S', firstMessage: 'F', exampleDialogue: 'E', creatorNotes: '', systemPrompt: '', postHistoryInstructions: '', creator: '', characterVersion: '', tags: ['png'], alternateGreetings: [], extensions: {} };

      const png = runtime.exportToPng(src, makeMinimalPng());
      const parsed = runtime.parsePngCharacterCard(png);

      expect(runtime.detectBinaryFormat(png)).assertEqual('png_metadata');
      expect(parsed.format).assertEqual('png_metadata');
      expect(parsed.name).assertEqual('PNG角色');
      expect(parsed.tags[0]).assertEqual('png');
    });
  });
}

function makeMinimalPng(): ArrayBuffer {
  const bytes = new Uint8Array(20);
  bytes[0]=0x89; bytes[1]=0x50; bytes[2]=0x4E; bytes[3]=0x47;
  bytes[4]=0x0D; bytes[5]=0x0A; bytes[6]=0x1A; bytes[7]=0x0A;
  bytes[8]=0x00; bytes[9]=0x00; bytes[10]=0x00; bytes[11]=0x00;
  bytes[12]=0x49; bytes[13]=0x45; bytes[14]=0x4E; bytes[15]=0x44;
  bytes[16]=0xAE; bytes[17]=0x42; bytes[18]=0x60; bytes[19]=0x82;
  return bytes.buffer;
}
