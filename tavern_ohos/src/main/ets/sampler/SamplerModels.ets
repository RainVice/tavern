export interface SamplerParams { temperature: number; top_p: number; top_k: number;
  repetition_penalty: number; frequency_penalty: number; presence_penalty: number;
  min_p: number; typical_p: number; cfg_scale: number; seed: number; }
export interface LogitBiasEntry { token: string; bias: number; }
export interface SamplerPreset { presetId: string; name: string; params: SamplerParams;
  logitBias: Array<LogitBiasEntry>; createdAt: number; updatedAt: number; }
export interface SamplerPresetSavedPayload { preset: SamplerPreset; }
export interface SamplerExportData { presets: Array<SamplerPreset>; }
