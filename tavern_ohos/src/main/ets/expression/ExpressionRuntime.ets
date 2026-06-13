import { EventBus } from '../runtime/EventBus';
import type { ExpressionChangedPayload, ExpressionClassification, ExpressionExportData, ExpressionState } from './ExpressionModels';

/**
 * 提供表情状态相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class ExpressionRuntime {
  /**
   * 事件总线。
   */
  private events: EventBus; private states: Map<string,ExpressionState>=new Map(); private counter=0;
  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) { this.events=events; }
  /**
   * 设置表情状态，用于切换运行时状态或保存配置。
   * @param characterId 目标角色标识。

   * @param label 展示标签。
   * @param spriteName 立绘名称。

   * @param messageId 目标消息标识。
   */
  setExpression(characterId: string, classification: ExpressionClassification, label: string, spriteName: string, intensity: number, messageId: string): ExpressionState {
    this.counter+=1; const expressionId=`expr-${this.counter}`; const now=Date.now();
    const state: ExpressionState = { expressionId, characterId, classification, label, spriteName, intensity, messageId, createdAt: now, updatedAt: now };
    this.states.set(expressionId, this.copyState(state));
    this.events.publish<ExpressionChangedPayload>('expression.changed', { state: this.copyState(state) });
    return this.copyState(state);
  }
  /**
   * 读取指定CurrentExpression，不存在时抛出错误。
   * @param characterId 目标角色标识。
   * @returns 更新或读取后的记录副本。
   */
  getCurrentExpression(characterId: string): ExpressionState|undefined {
    const values=Array.from(this.states.values());
    for (let i=values.length-1;i>=0;i--) { if (values[i].characterId===characterId) return this.copyState(values[i]); }
    return undefined;
  }
  /**
   * 读取Expressions列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @param characterId 目标角色标识。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  listExpressions(characterId: string): Array<ExpressionState> {
    const result=new Array<ExpressionState>(); const values=Array.from(this.states.values());
    for (let i=0;i<values.length;i++) { if (values[i].characterId===characterId) result.push(this.copyState(values[i])); }
    return result;
  }
  /**
   * 导出数据，用于备份、迁移或与 SillyTavern 数据互通。
   * @returns 可持久化或可传输的导出内容。
   */
  exportData(): ExpressionExportData { return { states: this.listAllStates() }; }
  /**
   * 从外部数据导入Data 值，转换为当前运行时的数据结构。
   * @param data 导入或恢复使用的序列化数据。
   */
  importData(data: ExpressionExportData): void {
    for (let i=0;i<data.states.length;i++) {
      const state = this.copyState(data.states[i]);
      this.states.set(state.expressionId, state);
      this.counter = Math.max(this.counter, this.parseCounter(state.expressionId));
    }
  }

  /**
   * 读取AllStates列表，返回副本，调用方修改返回值不会直接改变内部状态。
   * @returns 符合条件的记录列表；返回值是副本，调用方可安全读取。
   */
  private listAllStates(): Array<ExpressionState> {
    const result = new Array<ExpressionState>();
    const values = Array.from(this.states.values());
    for (let i = 0; i < values.length; i += 1) {
      result.push(this.copyState(values[i]));
    }
    return result;
  }

  /**
   * 复制State 值，避免外部修改内部状态。
   */
  private copyState(state: ExpressionState): ExpressionState {
    return {
      expressionId: state.expressionId,
      characterId: state.characterId,
      classification: state.classification,
      label: state.label,
      spriteName: state.spriteName,
      intensity: state.intensity,
      messageId: state.messageId,
      createdAt: state.createdAt,
      updatedAt: state.updatedAt,
    };
  }

  /**
   * 解析Counter，非法输入会返回失败标记或空结果。
   * @param expressionId 目标表情状态标识。
   */
  private parseCounter(expressionId: string): number {
    if (!expressionId.startsWith('expr-')) {
      return 0;
    }
    const parsed = Number(expressionId.substring(5));
    return parsed > 0 ? parsed : 0;
  }
}
