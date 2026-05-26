/**
 * 角色卡
 */
export interface CharacterCard {
  id: string;
  name: string;
  updateTime: number;
  avatarUrl?: string;
  description?: string;
  personality?: string;
  scenario?: string;
  firstMessage?: string;
  exampleMessages?: string;
}