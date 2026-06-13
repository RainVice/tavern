import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  LockManager,
  TaskRuntime,
  type RuntimeEvent,
  type TaskRecord,
  type TaskUpdatePayload,
} from '../../Index';

interface DemoEventPayload {
  value: string;
}

export default function runtimeUnitTest() {
  describe('runtime foundation', () => {
    it('publishes events in order and stops after unsubscribe', 0, () => {
      const bus = new EventBus();
      const received = new Array<string>();
      const subscription = bus.subscribe<DemoEventPayload>('demo.changed', (event: RuntimeEvent<DemoEventPayload>) => {
        received.push(event.payload.value);
      });

      bus.publish<DemoEventPayload>('demo.changed', { value: 'first' });
      bus.publish<DemoEventPayload>('demo.changed', { value: 'second' });
      subscription.unsubscribe();
      bus.publish<DemoEventPayload>('demo.changed', { value: 'ignored' });

      expect(received.length).assertEqual(2);
      expect(received[0]).assertEqual('first');
      expect(received[1]).assertEqual('second');
    });

    it('prevents duplicate lock acquisition until release', 0, async () => {
      const locks = new LockManager();

      const firstLease = await locks.acquire('chat:1');
      const secondWhileHeld = await locks.tryAcquire('chat:1');
      firstLease.release();
      const secondAfterRelease = await locks.tryAcquire('chat:1');

      expect(secondWhileHeld.acquired).assertFalse();
      expect(secondAfterRelease.acquired).assertTrue();
      secondAfterRelease.lease.release();
    });

    it('tracks task status and emits task update events', 0, () => {
      const bus = new EventBus();
      const tasks = new TaskRuntime(bus);
      const statuses = new Array<string>();
      bus.subscribe<TaskUpdatePayload>('task.updated', (event: RuntimeEvent<TaskUpdatePayload>) => {
        statuses.push(event.payload.task.status);
      });

      const created = tasks.createTask('storage.compact', 'Compact chat log');
      tasks.updateTask(created.id, 'running', 40, 'rewriting jsonl');
      tasks.completeTask(created.id, 'done');
      const saved: TaskRecord = tasks.getTask(created.id);

      expect(statuses.length).assertEqual(3);
      expect(statuses[0]).assertEqual('pending');
      expect(statuses[1]).assertEqual('running');
      expect(statuses[2]).assertEqual('completed');
      expect(saved.status).assertEqual('completed');
      expect(saved.progress).assertEqual(100);
      expect(saved.result).assertEqual('done');
    });

    it('does not expose internal task records', 0, () => {
      const bus = new EventBus();
      const tasks = new TaskRuntime(bus);
      bus.subscribe<TaskUpdatePayload>('task.updated', (event: RuntimeEvent<TaskUpdatePayload>) => {
        event.payload.task.status = 'event-mutated';
      });

      const created = tasks.createTask('storage.compact', 'Compact chat log');
      created.status = 'external-mutated';
      expect(tasks.getTask(created.id).status).assertEqual('pending');

      const listed = tasks.listTasks();
      listed[0].status = 'list-mutated';
      expect(tasks.getTask(created.id).status).assertEqual('pending');
    });
  });
}
