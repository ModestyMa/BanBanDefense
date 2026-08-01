// 番茄统计视图模型（统计页数据装载）
import { PomodoroRepository } from '../data/repository/PomodoroRepository';
import { PomodoroSessionData } from '../data/model/PomodoroSession';
import { DateUtils, DAY_MS } from '../common/utils/DateUtils';
import { DatabaseHelper } from '../data/database/DatabaseHelper';

@ObservedV2
export class PomodoroViewModel {
  @Trace todayMinutes: number = 0;
  @Trace weekMinutes: number = 0;
  @Trace totalCount: number = 0;
  /** 周一~周日 7 天分钟数 */
  @Trace weekDays: number[] = [0, 0, 0, 0, 0, 0, 0];
  /** 今天是 weekDays 的下标（周一=0） */
  @Trace todayIndex: number = 0;
  @Trace recent: PomodoroSessionData[] = [];

  async load(): Promise<void> {
    // BUG-007：页面 aboutToAppear 可能抢在 EntryAbility 异步 init 完成前调用，先等数据底座就绪
    await DatabaseHelper.ready();
    const today = DateUtils.todayStart();
    const dow = (new Date().getDay() + 6) % 7;
    const monday = today - dow * DAY_MS;
    this.todayIndex = dow;

    const weekSessions = await PomodoroRepository.listSince(monday);
    const days: number[] = [0, 0, 0, 0, 0, 0, 0];
    let todayMin = 0;
    let weekMin = 0;
    for (const s of weekSessions) {
      const idx = Math.floor((s.startTime - monday) / DAY_MS);
      if (idx >= 0 && idx < 7) {
        days[idx] += s.durationMin;
        weekMin += s.durationMin;
        if (idx === dow) {
          todayMin += s.durationMin;
        }
      }
    }
    this.weekDays = days;
    this.todayMinutes = todayMin;
    this.weekMinutes = weekMin;
    this.totalCount = await PomodoroRepository.countAll();
    this.recent = await PomodoroRepository.listRecent(20);
  }
}

export const pomodoroVM: PomodoroViewModel = new PomodoroViewModel();
