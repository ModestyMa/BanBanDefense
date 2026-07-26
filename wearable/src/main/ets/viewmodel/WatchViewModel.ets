// 手表端精简视图模型（SPEC_M6 决策 7）：宠物状态 + 今日收支 + 倒数日列表 + 默认账户
import { PetEngine } from '../service/PetEngine';
import { CountdownRepository } from '../data/repository/CountdownRepository';
import { TransactionRepository } from '../data/repository/TransactionRepository';
import { AccountRepository } from '../data/repository/AccountRepository';
import { CountdownEventData } from '../data/model/CountdownEvent';
import { AccountData } from '../data/model/Account';
import { TransactionData } from '../data/model/Transaction';
import { DateUtils, DAY_MS } from '../common/utils/DateUtils';
import { MoneyUtils } from '../common/utils/MoneyUtils';
import { TxDirection } from '../common/constants/AccountConstants';

@ObservedV2
export class WatchViewModel {
  // 宠物状态
  @Trace petEmoji: string = '😼';
  @Trace petLevel: number = 1;
  @Trace streakDays: number = 0;
  @Trace activeToday: boolean = false;
  // 今日收支（分）
  @Trace todayOutCents: number = 0;
  @Trace todayInCents: number = 0;
  // 倒数日列表（置顶优先 → 目标日升序）
  @Trace countdowns: CountdownEventData[] = [];
  // 默认账户（快记落账用，首启自动初始化的第一个账户）
  @Trace defaultAccountId: number = 0;

  async load(): Promise<void> {
    const today: number = DateUtils.todayStart();

    // 宠物状态
    const st = await PetEngine.getState();
    this.petLevel = st.level;
    this.streakDays = st.streakDays;
    this.petEmoji = st.mood === 0 ? '😺' : (st.mood === 2 ? '🙀' : '😼');
    this.activeToday = st.lastActiveDate === today;

    // 今日收支合计
    const txs: TransactionData[] = await TransactionRepository.listByRange(today, today + DAY_MS);
    let outSum: number = 0;
    let inSum: number = 0;
    for (const tx of txs) {
      const cents: number = MoneyUtils.toCents(tx.amount);
      if (tx.direction === TxDirection.OUT) {
        outSum += cents;
      } else {
        inSum += cents;
      }
    }
    this.todayOutCents = outSum;
    this.todayInCents = inSum;

    // 倒数日列表
    const events: CountdownEventData[] = await CountdownRepository.listAll();
    events.sort((a: CountdownEventData, b: CountdownEventData) => {
      if (a.isTop !== b.isTop) {
        return a.isTop ? -1 : 1;
      }
      return a.targetDate - b.targetDate;
    });
    this.countdowns = events;

    // 默认账户
    const accounts: AccountData[] = await AccountRepository.listAll();
    this.defaultAccountId = accounts.length > 0 ? accounts[0].id : 0;
  }
}

/** 跨页面共享单例 */
export const watchVM: WatchViewModel = new WatchViewModel();
