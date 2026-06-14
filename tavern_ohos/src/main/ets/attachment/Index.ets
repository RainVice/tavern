/**
 * 附件模块。
 * 导出 AttachmentRuntime 类及所有相关类型，提供附件的创建、查询、绑定到目标对象（角色/消息/个人资料）、
 * 图片描述标注、翻译结果存储、Prompt 构建附件筛选、RAG 文档筛选以及数据的导入导出和事件发布能力，
 * 适用于多模态消息附件管理和角色资料图片等场景中驱动附件数据的全生命周期管理。
 */
export { AttachmentRuntime } from './AttachmentRuntime';
export type {
  AttachmentAddedPayload,
  AttachmentBindingRecord,
  AttachmentCreateParams,
  AttachmentDeletedPayload,
  AttachmentExportData,
  AttachmentPromptRecord,
  AttachmentRecord,
  AttachmentUpdatedPayload,
} from './AttachmentModels';
