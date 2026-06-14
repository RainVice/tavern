/**
 * 头像模块。
 * 导出 AvatarRuntime 类及所有相关类型，提供头像的上传、读取、删除和数据导入导出能力。
 * 在角色编辑和个人资料设置流程中使用，用于管理用户自定义头像。
 */
export { AvatarRuntime } from './AvatarRuntime';
export type {
  AvatarCrop,
  AvatarDeletedPayload,
  AvatarIndexData,
  AvatarRecord,
  AvatarUploadedPayload,
} from './AvatarModels';
