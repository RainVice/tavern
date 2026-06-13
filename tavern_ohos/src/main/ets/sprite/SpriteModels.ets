export interface SpriteUploadParams {
  characterName: string;
  subfolderName: string;
  label: string;
  spriteName: string;
  fileName: string;
  mimeType: string;
  content: string;
}

export interface RisuSpriteImport {
  label: string;
  content: string;
}

export interface SpriteRecord {
  schemaVersion: number;
  characterName: string;
  subfolderName: string;
  label: string;
  spriteName: string;
  fileName: string;
  mimeType: string;
  path: string;
  content: string;
  createdAt: number;
  updatedAt: number;
}

export interface SpriteSelectionRecord {
  characterName: string;
  subfolderName: string;
  expression: string;
  spriteName: string;
  path: string;
  updatedAt: number;
}

export interface SpriteUploadedPayload {
  sprite: SpriteRecord;
}

export interface SpriteDeletedPayload {
  characterName: string;
  subfolderName: string;
  spriteName: string;
  path: string;
}

export interface SpriteExpressionChangedPayload {
  characterName: string;
  subfolderName: string;
  expression: string;
  spriteName: string;
  path: string;
}
