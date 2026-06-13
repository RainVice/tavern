import { describe, it, expect } from '@ohos/hypium';
import {
  EventBus,
  UIBridgeRuntime,
  type RuntimeEvent,
  type UIRequestEventPayload,
  type UIRequestRecord,
  type UIRequestResponse,
} from '../../Index';

export default function uiBridgeUnitTest() {
  describe('ui bridge runtime', () => {
    it('emits popup, input, confirm, select, file, toast, loader, media, clipboard, and navigation requests', 0, () => {
      const bus = new EventBus();
      const runtime = new UIBridgeRuntime(bus);
      const emitted = new Array<string>();
      bus.subscribe<UIRequestEventPayload>('ui.requested', (event: RuntimeEvent<UIRequestEventPayload>) => {
        emitted.push(`${event.payload.request.requestType}:${event.payload.request.title}`);
      });

      runtime.requestPopup('Notice', 'Hello');
      runtime.requestInput('Name', 'Your name', 'Pilot');
      runtime.requestConfirm('Confirm', 'Proceed?');
      runtime.requestSelect('Pick', ['A', 'B'], false);
      runtime.requestFilePicker('Pick File', ['.png'], false);
      runtime.requestToast('Saved', 'info');
      runtime.requestLoader('Loading', true);
      runtime.requestMediaPreview('Preview', 'image', 'asset://image.png');
      runtime.requestClipboard('Copy', 'text');
      runtime.requestNavigation('Go', '/settings');

      const requests: Array<UIRequestRecord> = runtime.listRequests();
      expect(requests.length).assertEqual(10);
      expect(requests[0].requestType).assertEqual('popup');
      expect(requests[4].optionsJson).assertContain('.png');
      expect(requests[7].mediaType).assertEqual('image');
      expect(emitted.length).assertEqual(10);
      expect(emitted[0]).assertEqual('popup:Notice');
    });

    it('records host responses and resolves pending requests', 0, () => {
      const runtime = new UIBridgeRuntime(new EventBus());
      const input = runtime.requestInput('Name', 'Your name', '');
      const selected = runtime.respond(input.id, makeResponse('Pilot', true));
      const missing = runtime.getPendingRequests();

      expect(selected.resolved).assertTrue();
      expect(selected.response.value).assertEqual('Pilot');
      expect(selected.response.confirmed).assertTrue();
      expect(missing.length).assertEqual(0);
      expect(runtime.getRequest(input.id).response.value).assertEqual('Pilot');
    });

    it('supports progress, audio playback, and permission request helpers', 0, () => {
      const runtime = new UIBridgeRuntime(new EventBus());
      const progress = runtime.requestProgress('Importing', 25, 100);
      const audio = runtime.requestAudioPlayback('Voice', 'asset://voice.wav', true);
      const permission = runtime.requestPermission('Network', 'Allow provider request');

      expect(progress.requestType).assertEqual('progress');
      expect(progress.progressCurrent).assertEqual(25);
      expect(audio.requestType).assertEqual('audio_playback');
      expect(audio.autoPlay).assertTrue();
      expect(permission.requestType).assertEqual('permission');
      expect(permission.message).assertEqual('Allow provider request');
    });

    it('does not expose internal request or response objects', 0, () => {
      const bus = new EventBus();
      const runtime = new UIBridgeRuntime(bus);
      bus.subscribe<UIRequestEventPayload>('ui.requested', (event: RuntimeEvent<UIRequestEventPayload>) => {
        event.payload.request.title = '事件修改';
      });

      const request = runtime.requestInput('Name', 'Your name', 'Pilot');
      request.title = '外部修改';
      request.response.value = '外部响应';
      expect(runtime.getRequest(request.id).title).assertEqual('Name');
      expect(runtime.getRequest(request.id).response.value).assertEqual('');

      const selected = runtime.respond(request.id, makeResponse('Pilot', true));
      selected.response.selectedValues.push('外部选项');
      const listed = runtime.listRequests();
      listed[0].response.value = '列表修改';

      const saved = runtime.getRequest(request.id);
      expect(saved.response.value).assertEqual('Pilot');
      expect(saved.response.selectedValues.length).assertEqual(0);
    });
  });
}

function makeResponse(value: string, confirmed: boolean): UIRequestResponse {
  return {
    value: value,
    selectedValues: new Array<string>(),
    confirmed: confirmed,
    cancelled: false,
    filePaths: new Array<string>(),
    metadataJson: '{}',
  };
}
