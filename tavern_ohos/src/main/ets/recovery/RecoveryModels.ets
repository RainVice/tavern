export type RecoveryType = 'user_password' | 'data_corruption' | 'session_restore';
export interface RecoveryMetadata { source?: string; chatId?: string; messageId?: string; reason?: string; }
export interface RecoverySnapshot { type: RecoveryType; metadata: RecoveryMetadata; timestamp: number; }
export interface RecoveryResult { success: boolean; type: RecoveryType; message: string; }
export interface RecoveryAttemptedPayload { result: RecoveryResult; }
