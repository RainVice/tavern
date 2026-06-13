import { describe, it, expect } from '@ohos/hypium';
import { EventBus, SecurityRuntime, type SecurityExportData } from '../../Index';
export default function securityUnitTest() {
  describe('SecurityRuntime', () => {
    it('添加规则并检查输入', 0, () => {
      const rt = new SecurityRuntime(new EventBus());
      rt.addRule('badword', 'block', 'message');
      const pass = rt.checkInput('message', 'hello');
      const fail = rt.checkInput('message', 'contains badword here');
      expect(pass.passed).assertTrue();
      expect(fail.passed).assertFalse();
      expect(fail.ruleId).assertContain('sec-rule');
    });
    it('审计记录', 0, () => {
      const rt = new SecurityRuntime(new EventBus());
      rt.addRule('spam', 'warn', 'message');
      rt.checkInput('message', 'spam detected');
      expect(rt.listAudits().length).assertEqual(1);
    });
    it('读取和导出不会暴露内部规则与审计结果', 0, () => {
      const rt = new SecurityRuntime(new EventBus());
      const rule = rt.addRule('secret', 'block', 'message');
      rule.enabled = false;
      expect(rt.checkInput('message', 'secret').passed).assertFalse();
      const rules = rt.listRules();
      rules[0].enabled = false;
      expect(rt.checkInput('message', 'secret').passed).assertFalse();
      const audits = rt.listAudits();
      audits[0].result.passed = true;
      expect(rt.listAudits()[0].result.passed).assertFalse();
      const exported = rt.exportData();
      exported.rules[0].enabled = false;
      expect(rt.checkInput('message', 'secret').passed).assertFalse();
    });
    it('删除缺失规则会报错且导入后新建规则不会复用 ID', 0, () => {
      const rt = new SecurityRuntime(new EventBus());
      { let thrown=false; try { rt.removeRule('missing'); } catch(e) { thrown=true; } expect(thrown).assertTrue(); };
      const data: SecurityExportData = {
        rules: [{
          ruleId: 'sec-rule-3',
          pattern: 'bad',
          action: 'block',
          scope: 'message',
          enabled: true,
        }],
      };
      rt.importData(data);
      const created = rt.addRule('worse', 'warn', 'message');
      expect(created.ruleId).assertEqual('sec-rule-4');
    });
  });
}
