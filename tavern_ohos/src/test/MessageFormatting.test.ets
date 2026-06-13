import { describe, it, expect } from '@ohos/hypium';
import { MessageFormattingRuntime, type FormattingConfig } from '../../Index';
export default function messageFormattingUnitTest() {
  describe('MessageFormattingRuntime', () => {
    it('格式化文本', 0, () => {
      const rt = new MessageFormattingRuntime();
      const result = rt.formatText('hello **world**');
      expect(result.formatted).assertContain('hello');
      expect(rt.isExtensionEnabled('underline')).assertTrue();
      expect(rt.isExtensionEnabled('exclusion')).assertFalse();
    });
    it('获取代码块语言列表', 0, () => {
      const rt = new MessageFormattingRuntime();
      const langs = rt.getCodeBlockLanguages();
      expect(langs.length).assertEqual(3);
      expect(langs[0]).assertEqual('javascript');
    });
    it('配置读写不暴露内部数组', 0, () => {
      const rt = new MessageFormattingRuntime();
      const config: FormattingConfig = {
        enabledExtensions: ['exclusion'],
        codeBlockLanguages: ['arkts'],
      };
      rt.setConfig(config);
      config.enabledExtensions.push('underline');
      config.codeBlockLanguages.push('python');

      const saved = rt.getConfig();
      saved.enabledExtensions.push('code_block');
      saved.codeBlockLanguages.push('bash');

      expect(rt.isExtensionEnabled('underline')).assertFalse();
      expect(rt.getCodeBlockLanguages().length).assertEqual(1);
    });
  });
}
