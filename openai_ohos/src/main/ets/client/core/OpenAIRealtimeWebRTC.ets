import webrtc from '@ohos/webrtc';
import type {
  AudioDeviceModule,
  RTCConfiguration,
  RTCDataChannel,
  RTCIceServer,
  RTCPeerConnection,
  RTCSessionDescriptionInit,
  AudioSource,
  MediaStreamTrack,
  PeerConnectionFactory,
} from 'libohos_webrtc.so';
import type { RealtimeClientEvent, RealtimeIceServer, RealtimeServerEvent, RealtimeWebRTCOptions } from '../../models/Realtime';
import { OpenAIRequestClient } from './OpenAIRequestClient';
import type { OpenAIStream } from './Types';

interface RealtimeDataChannelMessageEvent {
  data: string | ArrayBuffer;
}

/**
 * Realtime WebRTC 连接。
 *
 * API：Realtime WebRTC、`POST /v1/realtime/calls`。
 * 说明：使用 `@ohos/webrtc` 创建 peer connection 和 data channel，并通过 SDP exchange 接入 Realtime。
 */
export class OpenAIRealtimeWebRTC implements OpenAIStream {
  private client: OpenAIRequestClient;
  private options: RealtimeWebRTCOptions;
  private peerConnection: RTCPeerConnection | null = null;
  private dataChannel: RTCDataChannel | null = null;
  private audioDeviceModule: AudioDeviceModule | null = null;
  private audioTrack: MediaStreamTrack | null = null;
  private peerConnectionFactory: PeerConnectionFactory | null = null;
  private closed: boolean = false;

  constructor(client: OpenAIRequestClient, options: RealtimeWebRTCOptions) {
    this.client = client;
    this.options = options;
  }

  /** 建立 WebRTC 连接。API：Realtime WebRTC。说明：创建 offer、交换 SDP、设置 remote answer。 */
  async connect(): Promise<OpenAIRealtimeWebRTC> {
    const factory = this.createPeerConnectionFactory();
    this.peerConnectionFactory = factory;
    const peerConnection = this.createPeerConnection(factory);
    this.peerConnection = peerConnection;
    this.dataChannel = peerConnection.createDataChannel('oai-events');
    this.bindDataChannel(this.dataChannel);
    if (this.options.includeAudio === true) {
      this.attachAudio(factory, peerConnection);
    }
    if (this.options.cancelToken !== undefined) {
      this.options.cancelToken.onCancel(() => {
        this.close();
      });
    }
    const localSdp = await this.createLocalSdp(peerConnection);
    const answerSdp = await this.exchangeSdp(localSdp);
    const answer: RTCSessionDescriptionInit = {
      type: 'answer',
      sdp: answerSdp,
    };
    await peerConnection.setRemoteDescription(answer);
    return this;
  }

  /** 发送客户端事件。API：Realtime WebRTC。说明：通过 data channel 发送 JSON 事件。 */
  sendEvent(event: RealtimeClientEvent): void {
    if (this.dataChannel === null) {
      return;
    }
    this.dataChannel.send(JSON.stringify(event));
  }

  /** 关闭连接。API：Realtime WebRTC。说明：关闭 data channel、peer connection 并释放音频模块。 */
  close(): void {
    if (this.closed) {
      return;
    }
    this.closed = true;
    if (this.dataChannel !== null) {
      this.dataChannel.close();
      this.dataChannel = null;
    }
    if (this.audioTrack !== null) {
      this.audioTrack.stop();
      this.audioTrack = null;
    }
    if (this.peerConnection !== null) {
      this.peerConnection.close();
      this.peerConnection = null;
    }
    if (this.audioDeviceModule !== null) {
      this.audioDeviceModule.release();
      this.audioDeviceModule = null;
    }
    if (this.options.handlers !== undefined && this.options.handlers.onClose !== undefined) {
      this.options.handlers.onClose();
    }
  }

  private createPeerConnectionFactory(): PeerConnectionFactory {
    if (this.options.includeAudio === true) {
      this.audioDeviceModule = new webrtc.AudioDeviceModule({
        useHardwareAcousticEchoCanceler: true,
        useHardwareNoiseSuppressor: true,
      });
      return new webrtc.PeerConnectionFactory({
        adm: this.audioDeviceModule,
      });
    }
    return webrtc.PeerConnectionFactory.getDefault();
  }

  private createPeerConnection(factory: PeerConnectionFactory): RTCPeerConnection {
    const configuration: RTCConfiguration = {
      iceServers: this.toIceServers(this.options.iceServers),
    };
    return factory.createPeerConnection(configuration);
  }

  private attachAudio(factory: PeerConnectionFactory, peerConnection: RTCPeerConnection): void {
    const audioSource: AudioSource = factory.createAudioSource();
    const audioTrack: MediaStreamTrack = factory.createAudioTrack('openai-realtime-audio', audioSource);
    this.audioTrack = audioTrack;
    peerConnection.addTrack(audioTrack);
  }

  private bindDataChannel(dataChannel: RTCDataChannel): void {
    dataChannel.onmessage = (event: RealtimeDataChannelMessageEvent) => {
      if (this.options.handlers === undefined || this.options.handlers.onEvent === undefined) {
        return;
      }
      if (typeof event.data === 'string') {
        this.options.handlers.onEvent(JSON.parse(event.data) as RealtimeServerEvent);
      }
    };
    dataChannel.onclose = () => {
      if (this.options.handlers !== undefined && this.options.handlers.onClose !== undefined) {
        this.options.handlers.onClose();
      }
    };
  }

  private async createLocalSdp(peerConnection: RTCPeerConnection): Promise<string> {
    if (this.options.localSdp !== undefined && this.options.localSdp.length > 0) {
      return this.options.localSdp;
    }
    const offer: RTCSessionDescriptionInit = await peerConnection.createOffer();
    await peerConnection.setLocalDescription(offer);
    return offer.sdp === undefined ? '' : offer.sdp;
  }

  private async exchangeSdp(localSdp: string): Promise<string> {
    const headers: Record<string, string> = {
      'Authorization': 'Bearer ' + this.getAPIKey(),
      'OpenAI-Beta': 'realtime=v1',
    };
    if (this.options.headers !== undefined) {
      const keys = Object.keys(this.options.headers);
      for (let index = 0; index < keys.length; index++) {
        headers[keys[index]] = this.options.headers[keys[index]];
      }
    }
    return await this.client.postText('/realtime/calls?model=' + encodeURIComponent(this.options.model), localSdp, 'application/sdp', headers);
  }

  private getAPIKey(): string {
    if (this.options.apiKey !== undefined && this.options.apiKey.length > 0) {
      return this.options.apiKey;
    }
    return this.client.getAPIKey();
  }

  private toIceServers(servers?: Array<RealtimeIceServer>): Array<RTCIceServer> {
    if (servers === undefined) {
      return [];
    }
    const iceServers: Array<RTCIceServer> = [];
    for (let index = 0; index < servers.length; index++) {
      const server = servers[index];
      const iceServer: RTCIceServer = {
        urls: server.urls,
      };
      if (server.username !== undefined) {
        iceServer.username = server.username;
      }
      if (server.credential !== undefined) {
        iceServer.credential = server.credential;
      }
      iceServers.push(iceServer);
    }
    return iceServers;
  }
}
