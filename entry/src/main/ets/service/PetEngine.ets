// 宠物联动引擎（全局唯一入口：经验/心情/连续打卡/碎碎念/作息钟只能在这里改，见 06_AI_CONTEXT 第 6 节）
// 注意：MVP 骨架版——mood 用 streak 近似（完整"近 3 天活跃度"算法随 W3 卡片模块完善）
// C1 碎碎念 + C3 作息钟：mini-SPEC_C1C2C3.md §一/§三（2026-07-30 签字版）
import { common } from '@kit.AbilityKit';
import { PetRepository } from '../data/repository/PetRepository';
import { PetStateData } from '../data/model/PetState';
import { PomodoroRepository } from '../data/repository/PomodoroRepository';
import { TransactionRepository } from '../data/repository/TransactionRepository';
import { CountdownRepository } from '../data/repository/CountdownRepository';
import { DateUtils, DAY_MS } from '../common/utils/DateUtils';
import { AppContextHolder } from '../common/AppContextHolder';

/** 每级所需经验（MVP 线性） */
const EXP_PER_LEVEL: number = 100;

/** C1 碎碎念结果：最终渲染文案 + 配套表情（mini-SPEC §1.2） */
export interface PetSpeech {
  text: string;
  emoji: string;
}

/** C3 时段枚举（mini-SPEC §3.2） */
export enum PetTimeOfDay {
  SLEEP = 0,    // 睡觉 00:00–05:59
  MORNING = 1,  // 早安 06:00–08:59
  DAY = 2,      // 白天 09:00–22:59
  NIGHT = 3     // 准备睡 23:00–23:59
}

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

  /** mood → 表情（原逻辑散落在 HomeViewModel/PetCardService，C1 起收拢到引擎） */
  static moodEmoji(mood: number): string {
    if (mood === 0) {
      return '😺';
    }
    if (mood === 2) {
      return '🙀';
    }
    return '😼';
  }

  /**
   * C1 宠物碎碎念（mini-SPEC §1.3/§1.4）：按优先级聚合本地行为数据返回一句话。
   * 优先级：深夜 > 刚专注 > 临近倒数日 > 已记账 > 久未记账 > 长连续 > 心情兜底。
   * ctx 为空时回落 AppContextHolder；两者都拿不到（无法读资源）返回空文案，UI 隐藏气泡。
   * 任何异常返回兜底文案，不抛错中断 UI。
   */
  static async getPetSpeech(ctx: common.Context | null = null): Promise<PetSpeech> {
    const context: common.Context | null = ctx !== null ? ctx : AppContextHolder.get();
    if (context === null) {
      const empty: PetSpeech = { text: '', emoji: '' };
      return empty;
    }
    const rm = context.resourceManager;
    try {
      const hour: number = new Date().getHours();
      // 1. 深夜
      if (hour >= 23 || hour < 6) {
        const r1: PetSpeech = { text: rm.getStringSync($r('app.string.pet_speech_night')), emoji: '🌙' };
        return r1;
      }
      const today: number = DateUtils.todayStart();
      // 2. 今日已专注
      const sessions = await PomodoroRepository.listSince(today);
      if (sessions.length > 0) {
        let minutes: number = 0;
        for (const s of sessions) {
          minutes += s.durationMin;
        }
        const r2: PetSpeech = { text: rm.getStringSync($r('app.string.pet_speech_focus'), minutes), emoji: '💪' };
        return r2;
      }
      // 3. 临近倒数日（0–3 天）
      const events = await CountdownRepository.listAll();
      let bestTitle: string = '';
      let bestDays: number = -1;
      for (const ev of events) {
        const days: number = DateUtils.dayInfo(ev.targetDate).days;
        if (days < 0) {
          continue;
        }
        if (bestDays < 0 || days < bestDays) {
          bestDays = days;
          bestTitle = ev.title;
        }
      }
      if (bestDays >= 0 && bestDays <= 3) {
        const r3: PetSpeech = {
          text: rm.getStringSync($r('app.string.pet_speech_countdown'), bestTitle, bestDays),
          emoji: '📅'
        };
        return r3;
      }
      // 4. 今日已记账
      const todayTxs = await TransactionRepository.listByRange(today, today + DAY_MS);
      if (todayTxs.length > 0) {
        const r4: PetSpeech = { text: rm.getStringSync($r('app.string.pet_speech_billed')), emoji: '💰' };
        return r4;
      }
      // 5. 久未记账（有历史流水且距最近一笔 ≥3 天）
      const lastTradeTime: number = await TransactionRepository.latestTradeTime();
      if (lastTradeTime > 0 && today - lastTradeTime >= 3 * DAY_MS) {
        const r5: PetSpeech = { text: rm.getStringSync($r('app.string.pet_speech_no_bill')), emoji: '🐱' };
        return r5;
      }
      // 6. 长连续打卡
      const st = await PetRepository.getOrCreate();
      if (st.streakDays >= 7) {
        const r6: PetSpeech = { text: rm.getStringSync($r('app.string.pet_speech_streak'), st.streakDays), emoji: '🎉' };
        return r6;
      }
      // 7. 心情兜底
      if (st.mood === 0) {
        const r7a: PetSpeech = { text: rm.getStringSync($r('app.string.pet_speech_mood_happy')), emoji: '😺' };
        return r7a;
      }
      if (st.mood === 1) {
        const r7b: PetSpeech = { text: rm.getStringSync($r('app.string.pet_speech_mood_normal')), emoji: '😼' };
        return r7b;
      }
      const r7c: PetSpeech = { text: rm.getStringSync($r('app.string.pet_speech_mood_sad')), emoji: '🙀' };
      return r7c;
    } catch (err) {
      const fallback: PetSpeech = { text: rm.getStringSync($r('app.string.pet_speech_default')), emoji: '😺' };
      return fallback;
    }
  }

  /** C3 作息钟：小时 → 时段（mini-SPEC §3.2 纯函数） */
  static timeOfDayFromHour(hour: number): PetTimeOfDay {
    if (hour < 6) {
      return PetTimeOfDay.SLEEP;
    }
    if (hour < 9) {
      return PetTimeOfDay.MORNING;
    }
    if (hour < 23) {
      return PetTimeOfDay.DAY;
    }
    return PetTimeOfDay.NIGHT;
  }

  /**
   * C3 表情叠加（mini-SPEC §3.3）：SLEEP/NIGHT 强制覆盖 mood（睡觉时段心情不降级），
   * MORNING 显示早安表情，DAY 沿用 mood 三档。emoji 降级版（§3.5 降级方案）。
   */
  static overlayTimeEmoji(moodEmoji: string, tod: PetTimeOfDay): string {
    if (tod === PetTimeOfDay.SLEEP) {
      return '😴';
    }
    if (tod === PetTimeOfDay.NIGHT) {
      return '🛏';
    }
    if (tod === PetTimeOfDay.MORNING) {
      return '🌞';
    }
    return moodEmoji;
  }
}
