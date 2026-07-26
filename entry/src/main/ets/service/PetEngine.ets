// 宠物联动引擎（全局唯一入口：经验/心情/连续打卡只能在这里改，见 06_AI_CONTEXT 第 6 节）
// 注意：MVP 骨架版——mood 用 streak 近似（完整"近 3 天活跃度"算法随 W3 卡片模块完善）
import { PetRepository } from '../data/repository/PetRepository';
import { PetStateData } from '../data/model/PetState';
import { DateUtils, DAY_MS } from '../common/utils/DateUtils';

/** 每级所需经验（MVP 线性） */
const EXP_PER_LEVEL: number = 100;

export class PetEngine {
  /** 加经验并按 100/级 升级 */
  static async addExp(amount: number): Promise<void> {
    const st = await PetRepository.getOrCreate();
    st.exp += amount;
    st.level = 1 + Math.floor(st.exp / EXP_PER_LEVEL);
    await PetRepository.update(st);
  }

  /**
   * 当日活跃打卡：当天有记账或完成番茄即调用。
   * 规则：同日重复调用幂等；昨日活跃 → streak+1；中断 → streak=1。
   */
  static async touchActive(): Promise<void> {
    const st = await PetRepository.getOrCreate();
    const today = DateUtils.todayStart();
    if (st.lastActiveDate === today) {
      return;
    }
    if (st.lastActiveDate === today - DAY_MS) {
      st.streakDays += 1;
    } else {
      st.streakDays = 1;
    }
    st.lastActiveDate = today;
    st.mood = PetEngine.moodFromStreak(st.streakDays);
    await PetRepository.update(st);
  }

  /** 骨架版心情：streak>=2 开心(0)，streak==1 平常(1)，否则蔫了(2) */
  static moodFromStreak(streakDays: number): number {
    if (streakDays >= 2) {
      return 0;
    }
    if (streakDays === 1) {
      return 1;
    }
    return 2;
  }

  static async getState(): Promise<PetStateData> {
    return await PetRepository.getOrCreate();
  }
}
