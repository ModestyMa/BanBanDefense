// 首页聚合视图模型（SPEC_M5 4.1）：宠物状态 + 今日倒数日/专注/账单 三卡数据装配
// C1 碎碎念（mini-SPEC §1.6-2）：petSpeechText/petSpeechEmoji，加载失败不显示气泡
import { PetEngine, PetSpeech } from '../service/PetEngine';
import { CountdownRepository } from '../data/repository/CountdownRepository';
import { PomodoroRepository } from '../data/repository/PomodoroRepository';
import { TransactionRepository } from '../data/repository/TransactionRepository';
import { CountdownEventData } from '../data/model/CountdownEvent';
import { PomodoroSessionData } from '../data/model/PomodoroSession';
import { ReportUtils } from '../common/utils/ReportUtils';
import { DateUtils, DAY_MS } from '../common/utils/DateUtils';
import { TxDirection } from '../common/constants/AccountConstants';
import { DatabaseHelper } from '../data/database/DatabaseHelper';

@ObservedV2
export class HomeViewModel {
  // 宠物状态条
  @Trace petEmoji: string = '😼';
  @Trace petLevel: number = 1;
  @Trace streakDays: number = 0;
  @Trace activeToday: boolean = false;
  // C1 碎碎念气泡（空串 = 不显示）
  @Trace petSpeechText: string = '';
  @Trace petSpeechEmoji: string = '';
  // 今日倒数日
  @Trace hasCountdown: boolean = false;
  @Trace cdTitle: string = '';
  @Trace cdDays: number = 0;
  // 今日专注
  @Trace focusMinutes: number = 0;
  @Trace focusCount: number = 0;
  // 今日账单（分）
  @Trace billOutCents: number = 0;
  @Trace billOutCount: number = 0;
  @Trace billInCents: number = 0;
  @Trace billInCount: number = 0;

  async load(): Promise<void> {
    // BUG-007：页面 aboutToAppear 可能抢在 EntryAbility 异步 init 完成前调用，先等数据底座就绪
    await DatabaseHelper.ready();
    const today: number = DateUtils.todayStart();

    // 宠物状态
    const st = await PetEngine.getState();
    this.petLevel = st.level;
    this.streakDays = st.streakDays;
    this.petEmoji = PetEngine.moodEmoji(st.mood);
    this.activeToday = st.lastActiveDate === today;

    // C1 碎碎念（失败不阻塞首页装配，气泡留空）
    try {
      const speech: PetSpeech = await PetEngine.getPetSpeech();
      this.petSpeechText = speech.text;
      this.petSpeechEmoji = speech.emoji;
    } catch (err) {
      this.petSpeechText = '';
      this.petSpeechEmoji = '';
    }

    // 今日倒数日：未来/今天事件中 days 最小者
    const events = await CountdownRepository.listAll();
    let best: CountdownEventData | null = null;
    let bestDays: number = 0;
    for (const ev of events) {
      const days: number = DateUtils.dayInfo(ev.targetDate).days;
      if (days < 0) {
        continue;
      }
      if (best === null || days < bestDays) {
        best = ev;
        bestDays = days;
      }
    }
    this.hasCountdown = best !== null;
    this.cdTitle = best === null ? '' : best.title;
    this.cdDays = bestDays;

    // 今日专注
    const sessions = await PomodoroRepository.listSince(today);
    let minutes: number = 0;
    for (const s of sessions) {
      minutes += s.durationMin;
    }
    this.focusMinutes = minutes;
    this.focusCount = sessions.length;

    // 今日账单
    const txs = await TransactionRepository.listByRange(today, today + DAY_MS);
    this.billOutCents = ReportUtils.sumByDirection(txs, TxDirection.OUT);
    this.billOutCount = ReportUtils.countByDirection(txs, TxDirection.OUT);
    this.billInCents = ReportUtils.sumByDirection(txs, TxDirection.IN);
    this.billInCount = ReportUtils.countByDirection(txs, TxDirection.IN);
  }
}

/** 跨页面共享单例 */
export const homeVM: HomeViewModel = new HomeViewModel();
