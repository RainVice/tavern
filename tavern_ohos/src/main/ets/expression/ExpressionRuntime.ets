import { EventBus } from '../runtime/EventBus';
import type { ExpressionChangedPayload, ExpressionClassification, ExpressionExportData, ExpressionState } from './ExpressionModels';

/**
 * 提供表情状态相关的无 UI 运行时能力，负责状态管理、数据读写和事件发布。
 * 表情状态用于在聊天过程中跟踪角色的当前表情（如高兴、悲伤、愤怒等），
 * UI 层可根据这些状态更新角色立绘和聊天气泡表现。
 */
export class ExpressionRuntime {
  /**
   * 事件总线，用于在角色表情变更时向 UI 层或其他模块广播 ExpressionChangedPayload 事件。
   */
  private events: EventBus; private states: Map<string,ExpressionState>=new Map(); private counter=0;

  /**
   * 初始化运行时实例，注入事件总线依赖。
   * @param events 事件总线实例，用于在 setExpression 时发布 'expression.changed' 事件。
   */
  constructor(events: EventBus) { this.events=events; }

  /**
   * 设置某一角色的表情状态，生成唯一标识并发布变更事件。
   * 通常在收到 AI 消息或用户手动切换角色表情时由宿主调用。
   * @param characterId 目标角色标识，决定为哪个角色设置表情，用于在 states 中筛选该角色的表情记录。
   * @param classification 表情分类（joy、sadness 等），用于语义化标记角色当前情绪，供 UI 层选择对应立绘 Sprite。
   * @param label 表情展示标签，用于在 UI 上显示的表情描述文字（如"开心"、"生气"）。
   * @param spriteName 立绘资源名称，用于渲染角色立绘时加载对应的精灵图（Sprite）资源。
   * @param intensity 表情强度（数值越大表情越强烈），用于控制立绘的动画幅度或特效表现。
   * @param messageId 关联的消息标识，标记该表情对应的消息上下文，用于追溯该表情是由哪条消息触发的。
   */
  setExpression(characterId: string, classification: ExpressionClassification, label: string, spriteName: string, intensity: number, messageId: string): ExpressionState {
    this.counter+=1; const expressionId=`expr-${this.counter}`; const now=Date.now();
    const state: ExpressionState = { expressionId, characterId, classification, label, spriteName, intensity, messageId, createdAt: now, updatedAt: now };
    this.states.set(expressionId, this.copyState(state));
    this.events.publish<ExpressionChangedPayload>('expression.changed', { state: this.copyState(state) });
    return this.copyState(state);
  }

  /**
   * 查询指定角色当前最新的表情状态（按创建时间倒序），未找到时返回 undefined。
   * 在 UI 层需要刷新角色立绘为当前表情时调用，获取该角色最后设置的表情。
   * @param characterId 目标角色标识，用于在 states 中筛选该角色的所有表情记录。
   * @returns 该角色最新的表情状态副本；如果尚未设置任何表情则返回 undefined。
   */
  getCurrentExpression(characterId: string): ExpressionState|undefined {
    const values=Array.from(this.states.values());
    for (let i=values.length-1;i>=0;i--) { if (values[i].characterId===characterId) return this.copyState(values[i]); }
    return undefined;
  }

  /**
   * 列出指定角色的所有表情状态记录，按存入顺序返回副本。
   * 在展示角色表情历史或调试时调用。
   * @param characterId 目标角色标识，用于在 states 中筛选该角色的表情记录。
   * @returns 该角色的表情状态列表，每个条目均为副本，修改返回值不影响内部状态。
   */
  listExpressions(characterId: string): Array<ExpressionState> {
    const result=new Array<ExpressionState>(); const values=Array.from(this.states.values());
    for (let i=0;i<values.length;i++) { if (values[i].characterId===characterId) result.push(this.copyState(values[i])); }
    return result;
  }

  /**
   * 导出所有表情状态数据，用于备份、迁移或与 SillyTavern 数据互通。
   * 通常在设置页面执行导出操作时由宿主调用。
   * @returns 包含全部表情状态列表的可序列化导出对象。
   */
  exportData(): ExpressionExportData { return { states: this.listAllStates() }; }

  /**
   * 从外部数据导入表情状态，恢复到运行时状态列表中。
   * 通常在设置页面对导入数据进行恢复时由宿主调用。
   * @param data 待导入的表情状态导出数据，通常来自备份或迁移文件，其 states 数组会被逐一合并到运行时。
   */
  importData(data: ExpressionExportData): void {
    for (let i=0;i<data.states.length;i++) {
      const state = this.copyState(data.states[i]);
      this.states.set(state.expressionId, state);
      this.counter = Math.max(this.counter, this.parseCounter(state.expressionId));
    }
  }

  /**
   * 返回内部所有表情状态的副本列表，不进行角色筛选。
   * @returns 全部表情状态副本列表。
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
   * 深拷贝表情状态对象，防止外部代码修改内部状态。
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
   * 从表情状态标识中解析出自增计数器值，用于导入时保持计数器不冲突。
   * @param expressionId 表情状态标识，格式为 'expr-{数字}'。
   */
  private parseCounter(expressionId: string): number {
    if (!expressionId.startsWith('expr-')) {
      return 0;
    }
    const parsed = Number(expressionId.substring(5));
    return parsed > 0 ? parsed : 0;
  }
}
