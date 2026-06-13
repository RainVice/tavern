import { EventBus } from '../runtime/EventBus';
import type { ExpressionChangedPayload, ExpressionClassification, ExpressionExportData, ExpressionState } from './ExpressionModels';

export class ExpressionRuntime {
  private events: EventBus; private states: Map<string,ExpressionState>=new Map(); private counter=0;
  constructor(events: EventBus) { this.events=events; }
  setExpression(characterId: string, classification: ExpressionClassification, label: string, spriteName: string, intensity: number, messageId: string): ExpressionState {
    this.counter+=1; const expressionId=`expr-${this.counter}`; const now=Date.now();
    const state: ExpressionState = { expressionId, characterId, classification, label, spriteName, intensity, messageId, createdAt: now, updatedAt: now };
    this.states.set(expressionId, this.copyState(state));
    this.events.publish<ExpressionChangedPayload>('expression.changed', { state: this.copyState(state) });
    return this.copyState(state);
  }
  getCurrentExpression(characterId: string): ExpressionState|undefined {
    const values=Array.from(this.states.values());
    for (let i=values.length-1;i>=0;i--) { if (values[i].characterId===characterId) return this.copyState(values[i]); }
    return undefined;
  }
  listExpressions(characterId: string): Array<ExpressionState> {
    const result=new Array<ExpressionState>(); const values=Array.from(this.states.values());
    for (let i=0;i<values.length;i++) { if (values[i].characterId===characterId) result.push(this.copyState(values[i])); }
    return result;
  }
  exportData(): ExpressionExportData { return { states: this.listAllStates() }; }
  importData(data: ExpressionExportData): void {
    for (let i=0;i<data.states.length;i++) {
      const state = this.copyState(data.states[i]);
      this.states.set(state.expressionId, state);
      this.counter = Math.max(this.counter, this.parseCounter(state.expressionId));
    }
  }

  private listAllStates(): Array<ExpressionState> {
    const result = new Array<ExpressionState>();
    const values = Array.from(this.states.values());
    for (let i = 0; i < values.length; i += 1) {
      result.push(this.copyState(values[i]));
    }
    return result;
  }

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

  private parseCounter(expressionId: string): number {
    if (!expressionId.startsWith('expr-')) {
      return 0;
    }
    const parsed = Number(expressionId.substring(5));
    return parsed > 0 ? parsed : 0;
  }
}
