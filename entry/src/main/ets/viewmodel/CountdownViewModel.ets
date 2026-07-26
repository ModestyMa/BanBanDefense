// 倒数日模块视图模型（跨页面单例，承载列表状态与业务动作）
import { CountdownEventData } from '../data/model/CountdownEvent';
import { CountdownRepository } from '../data/repository/CountdownRepository';
import { ReminderService } from '../service/ReminderService';
import { PetCardService } from '../service/PetCardService';
import { DateUtils } from '../common/utils/DateUtils';
import { FREE_EVENT_LIMIT } from '../common/constants/CountdownConstants';

@ObservedV2
export class CountdownViewModel {
  @Trace events: CountdownEventData[] = [];
  @Trace filterKey: string = 'all';

  /** 加载并按 SPEC 3.3 排序：置顶优先 → 距今天数绝对值升序 */
  async load(): Promise<void> {
    const all = await CountdownRepository.listAll();
    const filtered: CountdownEventData[] = [];
    for (const ev of all) {
      if (this.filterKey === 'all' || ev.category === this.filterKey) {
        filtered.push(ev);
      }
    }
    filtered.sort((a: CountdownEventData, b: CountdownEventData): number => {
      if (a.isTop !== b.isTop) {
        return a.isTop ? -1 : 1;
      }
      const da = Math.abs(DateUtils.dayInfo(a.targetDate).days);
      const db = Math.abs(DateUtils.dayInfo(b.targetDate).days);
      return da - db;
    });
    this.events = filtered;
  }

  setFilter(key: string): void {
    this.filterKey = key;
  }

  /** 保存（新建或编辑）。返回 'limit' 表示触发免费上限，'ok' 表示成功。 */
  async saveEvent(ev: CountdownEventData, isNew: boolean): Promise<string> {
    if (isNew) {
      const cnt = await CountdownRepository.count();
      if (cnt >= FREE_EVENT_LIMIT) {
        return 'limit';
      }
      ev.createdAt = Date.now();
      ev.reminderIds = '';
      const newId = await CountdownRepository.insert(ev);
      ev.id = newId;
      await this.refreshReminders(ev);
    } else {
      await ReminderService.cancelForEvent(ev);
      ev.reminderIds = '';
      await CountdownRepository.update(ev);
      await this.refreshReminders(ev);
    }
    // 卡片状态刷新（新建/编辑倒数日都算宠物相关行为，SPEC_M3 第 3 节）
    PetCardService.pushToCards().catch(() => {});
    await this.load();
    return 'ok';
  }

  private async refreshReminders(ev: CountdownEventData): Promise<void> {
    if (ev.remindEnabled && ev.targetDate >= DateUtils.todayStart()) {
      const ids = await ReminderService.scheduleForEvent(ev);
      await CountdownRepository.updateReminderIds(ev.id, ids);
    }
  }

  /** 删除：先取消提醒再删库 */
  async deleteEvent(id: number): Promise<void> {
    const ev = await CountdownRepository.findById(id);
    if (ev !== null) {
      await ReminderService.cancelForEvent(ev);
      await CountdownRepository.deleteById(id);
    }
    await this.load();
  }
}

/** 跨页面共享的单例 */
export const countdownVM: CountdownViewModel = new CountdownViewModel();
