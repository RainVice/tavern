import cryptoFramework from '@ohos.security.cryptoFramework';
import util from '@ohos.util';
import type { OpenAIWebhookEvent, OpenAIWebhookHeaders } from '../../models/Webhooks';

/**
 * Webhook 签名校验选项。
 *
 * API：Webhook signature verification。
 * 说明：用于 `client.webhooks.verifySignature()` 和 `client.webhooks.unwrap()`。
 */
export interface OpenAIWebhookVerifyOptions {
  /**
   * 时间戳容忍窗口。
   *
   * API：Webhook signature verification。
   * 说明：单位秒；默认 300。设置为 0 时不校验时间窗口，只校验签名。
   */
  toleranceInSeconds?: number;
}

/**
 * Webhook 签名错误。
 *
 * API：Webhook signature verification。
 * 说明：`unwrap()` 校验失败时抛出，便于业务侧返回 400。
 */
export class OpenAIWebhookSignatureError extends Error {
  /**
   * 失败原因。
   *
   * API：Webhook signature verification。
   * 说明：用于日志定位缺失 header、过期时间戳或签名不匹配。
   */
  reason: string = '';

  constructor(reason: string) {
    super('OpenAI webhook signature verification failed: ' + reason);
    this.reason = reason;
  }
}

/**
 * Webhooks 资源入口。
 *
 * API：Webhook Events。
 * 说明：提供 payload 解析和 Standard Webhooks 签名校验能力，形态对齐官方 SDK 的 `client.webhooks.unwrap()`。
 */
export interface OpenAIWebhooksResource {
  /**
   * 解析 webhook payload。
   *
   * API：Webhook Events。
   * 说明：只做 JSON 解析，不做签名校验；可信内部消息或测试数据可用。
   */
  parse(payload: string): OpenAIWebhookEvent;

  /**
   * 校验签名并解析事件。
   *
   * API：Webhook signature verification。
   * 说明：先校验 `webhook-id`、`webhook-timestamp`、`webhook-signature`，通过后返回事件对象。
   */
  unwrap(payload: string, headers: OpenAIWebhookHeaders, secret?: string,
    options?: OpenAIWebhookVerifyOptions): OpenAIWebhookEvent;

  /**
   * 校验 webhook 签名。
   *
   * API：Webhook signature verification。
   * 说明：按 Standard Webhooks 使用 `webhook-id.webhook-timestamp.payload` 计算 HMAC-SHA256。
   */
  verifySignature(payload: string, headers: OpenAIWebhookHeaders, secret?: string,
    options?: OpenAIWebhookVerifyOptions): boolean;
}

export class WebhooksResource implements OpenAIWebhooksResource {
  private webhookSecret: string | null = null;

  constructor(webhookSecret?: string) {
    this.webhookSecret = webhookSecret === undefined || webhookSecret.length === 0 ? null : webhookSecret;
  }

  parse(payload: string): OpenAIWebhookEvent {
    return JSON.parse(payload) as OpenAIWebhookEvent;
  }

  unwrap(payload: string, headers: OpenAIWebhookHeaders, secret?: string,
    options?: OpenAIWebhookVerifyOptions): OpenAIWebhookEvent {
    const result = this.verifySignature(payload, headers, secret, options);
    if (!result) {
      throw new OpenAIWebhookSignatureError('invalid signature');
    }
    return this.parse(payload);
  }

  verifySignature(payload: string, headers: OpenAIWebhookHeaders, secret?: string,
    options?: OpenAIWebhookVerifyOptions): boolean {
    const resolvedSecret = this.resolveSecret(secret);
    if (resolvedSecret === null) {
      return false;
    }
    const webhookID = headers.webhookId === undefined ? null : headers.webhookId;
    const timestamp = headers.webhookTimestamp === undefined ? null : headers.webhookTimestamp;
    const signatureHeader = headers.webhookSignature === undefined ? null : headers.webhookSignature;
    if (webhookID === null || timestamp === null || signatureHeader === null) {
      return false;
    }
    if (!this.isTimestampAcceptable(timestamp, options)) {
      return false;
    }
    const signedPayload = webhookID + '.' + timestamp + '.' + payload;
    const expected = this.hmacSha256(resolvedSecret, signedPayload);
    if (expected === null) {
      return false;
    }
    return this.matchesAnySignature(expected, signatureHeader);
  }

  private resolveSecret(secret?: string): string | null {
    if (secret !== undefined && secret.length > 0) {
      return secret;
    }
    return this.webhookSecret;
  }

  private isTimestampAcceptable(timestamp: string, options?: OpenAIWebhookVerifyOptions): boolean {
    const tolerance = options === undefined || options.toleranceInSeconds === undefined ?
      300 : options.toleranceInSeconds;
    if (tolerance === 0) {
      return true;
    }
    const value = Number(timestamp);
    if (!Number.isFinite(value)) {
      return false;
    }
    const now = Math.floor(Date.now() / 1000);
    return Math.abs(now - value) <= tolerance;
  }

  private hmacSha256(secret: string, payload: string): Uint8Array | null {
    try {
      const keyBytes = this.secretToBytes(secret);
      const generator = cryptoFramework.createSymKeyGenerator('HMAC');
      const key = generator.convertKeySync({ data: keyBytes });
      const mac = cryptoFramework.createMac('HMAC|SHA256');
      mac.initSync(key);
      mac.updateSync({ data: this.utf8Bytes(payload) });
      const result = mac.doFinalSync();
      key.clearMem();
      return result.data;
    } catch (error) {
      return null;
    }
  }

  private secretToBytes(secret: string): Uint8Array {
    if (secret.startsWith('whsec_') && secret.length > 6) {
      const base64 = new util.Base64Helper();
      return base64.decodeSync(secret.substring(6));
    }
    return this.utf8Bytes(secret);
  }

  private utf8Bytes(value: string): Uint8Array {
    const encoder = new util.TextEncoder();
    return encoder.encodeInto(value);
  }

  private matchesAnySignature(expected: Uint8Array, signatureHeader: string): boolean {
    const values = signatureHeader.split(' ');
    for (let index = 0; index < values.length; index++) {
      const signature = this.extractV1Signature(values[index]);
      if (signature !== null && this.matchesSignature(expected, signature)) {
        return true;
      }
    }
    return false;
  }

  private extractV1Signature(value: string): string | null {
    const trimmed = value.trim();
    if (!trimmed.startsWith('v1,')) {
      return null;
    }
    const signature = trimmed.substring(3);
    if (signature.length === 0) {
      return null;
    }
    return signature;
  }

  private matchesSignature(expected: Uint8Array, signature: string): boolean {
    try {
      const base64 = new util.Base64Helper();
      const actual = base64.decodeSync(signature);
      return this.timingSafeEqual(expected, actual);
    } catch (error) {
      return false;
    }
  }

  private timingSafeEqual(left: Uint8Array, right: Uint8Array): boolean {
    if (left.length !== right.length) {
      return false;
    }
    let diff = 0;
    for (let index = 0; index < left.length; index++) {
      diff = diff | (left[index] ^ right[index]);
    }
    return diff === 0;
  }
}
