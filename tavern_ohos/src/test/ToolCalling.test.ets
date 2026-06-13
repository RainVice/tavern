import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  ToolCallingRuntime,
  type RuntimeEvent,
  type ToolAction,
  type ToolCallLoopParams,
  type ToolCallRequest,
  type ToolCalledPayload,
  type ToolDefinitionRecord,
  type ToolExecutionResult,
  type ToolRegisteredPayload,
  type ToolRegistrationParams,
} from '../../Index';

export default function toolCallingUnitTest() {
  describe('tool calling runtime', () => {
    it('registers tools, exports OpenAI schema, invokes calls, and emits events', 0, async () => {
      const bus = new EventBus();
      const runtime = new ToolCallingRuntime(bus);
      const calledTools = new Array<string>();
      bus.subscribe<ToolCalledPayload>('tool.called', (event: RuntimeEvent<ToolCalledPayload>) => {
        calledTools.push(event.payload.invocation.name);
      });

      runtime.registerTool(makeEchoTool(false));
      const openAITools = runtime.listOpenAITools();
      const call: ToolCallRequest = {
        id: 'call-1',
        name: 'Echo',
        argumentsJson: '{"message":"hello"}',
        signature: 'sig-1',
        reasoning: 'need echo',
      };
      const result = await runtime.invokeToolCalls([call], 'need echo');

      expect(openAITools.length).assertEqual(1);
      expect(openAITools[0].function.name).assertEqual('Echo');
      expect(result.invocations.length).assertEqual(1);
      expect(result.invocations[0].result).assertEqual('echo:{"message":"hello"}');
      expect(result.invocations[0].signature).assertEqual('sig-1');
      expect(result.resultMessages[0]).assertContain('Echo');
      expect(calledTools.length).assertEqual(1);
      expect(calledTools[0]).assertEqual('Echo');
    });

    it('records stealth calls without user-visible invocations', 0, async () => {
      const bus = new EventBus();
      const runtime = new ToolCallingRuntime(bus);
      runtime.registerTool(makeEchoTool(true));
      const call: ToolCallRequest = {
        id: 'call-2',
        name: 'Echo',
        argumentsJson: '{}',
        signature: '',
        reasoning: '',
      };

      const result = await runtime.invokeToolCalls([call], '');

      expect(result.invocations.length).assertEqual(0);
      expect(result.stealthCalls.length).assertEqual(1);
      expect(result.stealthCalls[0]).assertEqual('Echo');
    });

    it('reports tool errors and enforces call loop recursion limit', 0, async () => {
      const bus = new EventBus();
      const runtime = new ToolCallingRuntime(bus);
      runtime.registerTool(makeFailTool());
      const first: ToolCallRequest = {
        id: 'call-3',
        name: 'Fail',
        argumentsJson: '{}',
        signature: '',
        reasoning: '',
      };
      const second: ToolCallRequest = {
        id: 'call-4',
        name: 'Fail',
        argumentsJson: '{}',
        signature: '',
        reasoning: '',
      };
      const loop: ToolCallLoopParams = {
        batches: [[first], [second]],
        maxDepth: 1,
        reasoningText: '',
      };

      const result = await runtime.executeCallLoop(loop);

      expect(result.errors.length).assertEqual(2);
      expect(result.errors[0].message).assertEqual('failed');
      expect(result.errors[1].message).assertContain('recursion limit');
    });

    it('does not expose internal tool definitions through returns, events, or lists', 0, () => {
      const bus = new EventBus();
      const runtime = new ToolCallingRuntime(bus);
      bus.subscribe<ToolRegisteredPayload>('tool.registered', (event: RuntimeEvent<ToolRegisteredPayload>) => {
        event.payload.tool.enabled = false;
      });

      const registered: ToolDefinitionRecord = runtime.registerTool(makeEchoTool(false));
      registered.enabled = false;
      const listed = runtime.listTools();
      listed[0].enabled = false;

      expect(runtime.listTools()[0].enabled).assertTrue();
      expect(runtime.listOpenAITools().length).assertEqual(1);
    });
  });
}

class EchoAction implements ToolAction {
  execute(argumentsJson: string): Promise<ToolExecutionResult> {
    const result: ToolExecutionResult = {
      ok: true,
      result: `echo:${argumentsJson}`,
      error: '',
    };
    return Promise.resolve(result);
  }
}

class FailAction implements ToolAction {
  execute(argumentsJson: string): Promise<ToolExecutionResult> {
    if (argumentsJson.length >= 0) {
      const result: ToolExecutionResult = {
        ok: false,
        result: '',
        error: 'failed',
      };
      return Promise.resolve(result);
    }
    const result: ToolExecutionResult = {
      ok: false,
      result: '',
      error: 'unreachable',
    };
    return Promise.resolve(result);
  }
}

function makeEchoTool(stealth: boolean): ToolRegistrationParams {
  return {
    name: 'Echo',
    displayName: 'Echo tool',
    description: 'Echoes input JSON.',
    parametersJson: '{"type":"object"}',
    permission: 'trusted',
    stealth: stealth,
    enabled: true,
    action: new EchoAction(),
  };
}

function makeFailTool(): ToolRegistrationParams {
  return {
    name: 'Fail',
    displayName: 'Fail tool',
    description: 'Fails.',
    parametersJson: '{"type":"object"}',
    permission: 'trusted',
    stealth: false,
    enabled: true,
    action: new FailAction(),
  };
}
