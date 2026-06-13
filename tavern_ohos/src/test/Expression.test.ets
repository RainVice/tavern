import { describe, it, expect } from '@ohos/hypium';
import { EventBus, ExpressionRuntime, type ExpressionExportData } from '../../Index';
export default function expressionUnitTest() {
  describe('ExpressionRuntime', () => {
    it('设置和获取角色表情', 0, () => {
      const rt = new ExpressionRuntime(new EventBus());
      rt.setExpression('char-1', 'joy', '开心', 'sprite_happy', 0.9, 'msg-1');
      const current = rt.getCurrentExpression('char-1');
      expect(current === undefined).assertFalse();
      if (current) {
        expect(current.classification).assertEqual('joy');
        expect(current.spriteName).assertEqual('sprite_happy');
        expect(current.intensity).assertEqual(0.9);
      }
    });
    it('获取最新表情', 0, () => {
      const rt = new ExpressionRuntime(new EventBus());
      rt.setExpression('char-1', 'sadness', '悲伤', 'sad', 0.5, 'm1');
      rt.setExpression('char-1', 'anger', '愤怒', 'angry', 0.8, 'm2');
      expect(rt.getCurrentExpression('char-1')!.classification).assertEqual('anger');
      expect(rt.listExpressions('char-1').length).assertEqual(2);
    });
    it('读取和导出不会暴露内部表情状态', 0, () => {
      const rt = new ExpressionRuntime(new EventBus());
      const state = rt.setExpression('char-1', 'joy', '开心', 'happy', 0.9, 'm1');
      state.label = '外部修改';
      state.intensity = 0.1;

      const current = rt.getCurrentExpression('char-1');
      expect(current === undefined).assertFalse();
      if (current !== undefined) {
        expect(current.label).assertEqual('开心');
        expect(current.intensity).assertEqual(0.9);
      }

      const listed = rt.listExpressions('char-1');
      listed[0].label = '列表修改';
      expect(rt.getCurrentExpression('char-1')!.label).assertEqual('开心');

      const exported = rt.exportData();
      exported.states[0].label = '导出修改';
      expect(rt.getCurrentExpression('char-1')!.label).assertEqual('开心');
    });
    it('导入后新建表情不会复用已有 ID', 0, () => {
      const rt = new ExpressionRuntime(new EventBus());
      const data: ExpressionExportData = {
        states: [{
          expressionId: 'expr-3',
          characterId: 'char-1',
          classification: 'neutral',
          label: '中性',
          spriteName: 'neutral',
          intensity: 0.5,
          messageId: 'm1',
          createdAt: 1,
          updatedAt: 1,
        }],
      };
      rt.importData(data);
      const created = rt.setExpression('char-1', 'joy', '开心', 'happy', 1, 'm2');
      expect(created.expressionId).assertEqual('expr-4');
    });
  });
}
