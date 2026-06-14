import { EventBus } from '../runtime/EventBus';
import type { ExpressionChangedPayload, ExpressionClassification, ExpressionExportData, ExpressionState } from './ExpressionModels';

/**
 * 提供表情状态相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 */
export class ExpressionRuntime {
  /**
   * 事件总线实例。
   */
  private events: EventBus;
  /**
   * 所有表情状态的映射表，以 expressionId 为键。
   */
  private states: Map<string, ExpressionState> = new Map();
  /**
   * 自增计数器，用于生成全局唯一的 expressionId。
   */
  private counter = 0;
  /**
   * 初始化当前运行时实例。
   * @param events 事件总线。
   */
  constructor(events: EventBus) { this.events=events; }
  /**
   * 设置指定角色的表情状态：创建新状态并持久化，同时通过事件总线发布变更通知。
   * @param characterId 目标角色标识。
   * @param classification 表情分类。
   * @param label 展示标签。
   * @param spriteName 立绘名称。
   * @param intensity 表情强度。
   * @param messageId 关联消息标识。
   * @returns 新创建的表情状态副本。
   */
  setExpression(characterId: string, classification: ExpressionClassification, label: string, spriteName: string, intensity: number, messageId: string): ExpressionState {
    this.counter+=1; const expressionId=`expr-${this.counter}`; const now=Date.now();
    const state: ExpressionState = { expressionId, characterId, classification, label, spriteName, intensity, messageId, createdAt: now, updatedAt: now };
    this.states.set(expressionId, this.copyState(state));
    this.events.publish<ExpressionChangedPayload>('expression.changed', { state: this.copyState(state) });
    return this.copyState(state);
  }
  /**
   * 获取指定角色当前（最近一次设置）的表情状态。
   * @param characterId 目标角色标识。
   * @returns 表情状态副本；若该角色从未设置过表情，返回 undefined。
   */
  getCurrentExpression(characterId: string): ExpressionState|undefined {
    const values=Array.from(this.states.values());
    for (let i=values.length-1;i>=0;i--) { if (values[i].characterId===characterId) return this.copyState(values[i]); }
    return undefined;
  }
  /**
   * 读取指定角色全部表情状态列表。
   * @param characterId 目标角色标识。
   * @returns 符合条件的表情状态副本列表。
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
   * 导入外部表情状态数据，覆盖当前运行时内存中的状态。
   * @param data 从 exportData() 导出的序列化数据。
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
   * @returns 表情状态列表副本。
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
   * 解析 expressionId 中的自增序号。
   * @param expressionId 表情状态标识，格式为 "expr-{数字}"。
   * @returns 解析后的序号；若格式非法，返回 0。
   */
  private parseCounter(expressionId: string): number {
    if (!expressionId.startsWith('expr-')) {
      return 0;
    }
    const parsed = Number(expressionId.substring(5));
    return parsed > 0 ? parsed : 0;
  }
}
