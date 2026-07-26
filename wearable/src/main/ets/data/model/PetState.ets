// 【手表端副本】与 entry module 同步维护，V1.0 抽 HAR 后删除（SPEC_M6 决策 8）
// 宠物状态实体（pet_state 单行表）
export interface PetStateData {
  id: number;
  level: number;
  exp: number;
  skin: string;
  /** 0 开心 | 1 平常 | 2 蔫了 */
  mood: number;
  streakDays: number;
  /** 最近一次活跃日（当地 00:00 时间戳），0 表示从未活跃 */
  lastActiveDate: number;
}

export function defaultPetState(): PetStateData {
  const st: PetStateData = {
    id: 0,
    level: 1,
    exp: 0,
    skin: 'default',
    mood: 1,
    streakDays: 0,
    lastActiveDate: 0
  };
  return st;
}
