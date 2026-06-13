export interface AvatarCrop {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface AvatarRecord {
  schemaVersion: number;
  targetType: string;
  targetId: string;
  fileName: string;
  mimeType: string;
  path: string;
  content: string;
  crop: AvatarCrop;
  createdAt: number;
  updatedAt: number;
}

export interface AvatarUploadedPayload {
  avatar: AvatarRecord;
}

export interface AvatarDeletedPayload {
  targetType: string;
  targetId: string;
  path: string;
}

export interface AvatarIndexData {
  avatars: Array<AvatarRecord>;
}
