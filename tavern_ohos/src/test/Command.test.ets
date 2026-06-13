import { describe, it, expect } from '@ohos/hypium';
import {
  CommandRuntime,
  EventBus,
  type CommandAction,
  type CommandExecutedPayload,
  type CommandExecuteOptions,
  type CommandExecutionResult,
  type CommandInvocation,
  type CommandPipelineResult,
  type CommandRecord,
  type CommandRegisteredPayload,
  type CommandRegistrationParams,
  type RuntimeEvent,
} from '../../Index';

export default function commandUnitTest() {
  describe('command runtime', () => {
    it('registers commands, parses slash text, executes aliases, and emits events', 0, async () => {
      const bus = new EventBus();
      const runtime = new CommandRuntime(bus);
      const executed = new Array<string>();
      bus.subscribe<CommandExecutedPayload>('command.executed', (event: RuntimeEvent<CommandExecutedPayload>) => {
        executed.push(event.payload.result.commandName);
      });
      runtime.registerCommand(makeCommand('echo', ['say'], 'public', new EchoCommandAction()));

      const result = await runtime.executeText('/say tone=soft hello world', makeOptions(['public'], false));

      expect(result.ok).assertTrue();
      expect(result.commandName).assertEqual('echo');
      expect(result.output).assertEqual('soft:hello world');
      expect(executed.length).assertEqual(1);
      expect(executed[0]).assertEqual('echo');
      expect(runtime.getHelp('echo')).assertContain('Echoes');
      expect(runtime.autocomplete('sa')[0]).assertEqual('say');
    });

    it('pipes command output into the next command', 0, async () => {
      const bus = new EventBus();
      const runtime = new CommandRuntime(bus);
      runtime.registerCommand(makeCommand('echo', new Array<string>(), 'public', new EchoCommandAction()));
      runtime.registerCommand(makeCommand('upper', new Array<string>(), 'public', new UpperCommandAction()));

      const result: CommandPipelineResult = await runtime.executePipeline('/echo hello | /upper', makeOptions(['public'], false));

      expect(result.ok).assertTrue();
      expect(result.steps.length).assertEqual(2);
      expect(result.finalOutput).assertEqual('HELLO');
    });

    it('rejects missing permission and honors cancellation', 0, async () => {
      const bus = new EventBus();
      const runtime = new CommandRuntime(bus);
      runtime.registerCommand(makeCommand('secret', new Array<string>(), 'admin', new EchoCommandAction()));

      const denied = await runtime.executeText('/secret value', makeOptions(['public'], false));
      const cancelled = await runtime.executeText('/secret value', makeOptions(['admin'], true));

      expect(denied.ok).assertFalse();
      expect(denied.error).assertContain('permission');
      expect(cancelled.ok).assertFalse();
      expect(cancelled.cancelled).assertTrue();
    });

    it('does not expose internal command records or execution payloads', 0, async () => {
      const bus = new EventBus();
      const runtime = new CommandRuntime(bus);
      bus.subscribe<CommandRegisteredPayload>('command.registered', (event: RuntimeEvent<CommandRegisteredPayload>) => {
        event.payload.command.enabled = false;
        event.payload.command.aliases.push('event-mutated');
      });
      bus.subscribe<CommandExecutedPayload>('command.executed', (event: RuntimeEvent<CommandExecutedPayload>) => {
        event.payload.result.output = 'event-mutated';
        event.payload.invocation.namedArguments.push({ name: 'event', value: 'mutated' });
      });

      const registered: CommandRecord = runtime.registerCommand(makeCommand('copy', ['cp'], 'public', new EchoCommandAction()));
      registered.enabled = false;
      registered.aliases.push('return-mutated');
      const listed = runtime.listCommands();
      listed[0].enabled = false;
      listed[0].aliases.push('list-mutated');
      const result = await runtime.executeText('/cp tone=soft hello', makeOptions(['public'], false));

      expect(runtime.listCommands()[0].enabled).assertTrue();
      expect(runtime.listCommands()[0].aliases.length).assertEqual(1);
      expect(result.output).assertEqual('soft:hello');
    });
  });
}

class EchoCommandAction implements CommandAction {
  execute(invocation: CommandInvocation): Promise<CommandExecutionResult> {
    const tone = invocation.getNamedArgument('tone');
    const prefix = tone.length > 0 ? `${tone}:` : '';
    const result: CommandExecutionResult = {
      ok: true,
      commandName: invocation.commandName,
      output: `${prefix}${invocation.unnamedArgument}`,
      error: '',
      cancelled: false,
    };
    return Promise.resolve(result);
  }
}

class UpperCommandAction implements CommandAction {
  execute(invocation: CommandInvocation): Promise<CommandExecutionResult> {
    const value = invocation.pipeInput.length > 0 ? invocation.pipeInput : invocation.unnamedArgument;
    const result: CommandExecutionResult = {
      ok: true,
      commandName: invocation.commandName,
      output: value.toUpperCase(),
      error: '',
      cancelled: false,
    };
    return Promise.resolve(result);
  }
}

function makeCommand(name: string, aliases: Array<string>, permission: string, action: CommandAction): CommandRegistrationParams {
  return {
    name: name,
    aliases: aliases,
    helpText: 'Echoes text.',
    permission: permission,
    returns: 'string',
    enabled: true,
    action: action,
  };
}

function makeOptions(permissions: Array<string>, cancelled: boolean): CommandExecuteOptions {
  return {
    allowedPermissions: permissions,
    cancelled: cancelled,
  };
}
