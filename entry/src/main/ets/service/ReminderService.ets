// 提醒调度服务（SPEC_M1 第 5 节）
// 假设API清单（请人工对照官方文档核验，核验后删除本注释）:
// 1. reminderAgentManager.ReminderRequestCalendar 字段：reminderType / dateTime{year,month(1-12),day,hour,minute,second} / repeatMonths / repeatDays / wantAgent{pkgName,abilityName} / title / content / notificationId
// 2. reminderAgentManager.publishReminder(req): Promise<number> 返回 reminderId
// 3. reminderAgentManager.cancelReminder(reminderId: number): Promise<void>
// 4. ohos.permission.REMINDER_AGENT 为 normal 级 system_grant（已在 module.json5 声明）
import reminderAgentManager from '@ohos.reminderAgentManager';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DateUtils, DAY_MS } from '../common/utils/DateUtils';
import { CountdownRepository } from '../data/repository/CountdownRepository';
import { CountdownEventData } from '../data/model/CountdownEvent';

const DOMAIN: number = 0x1100;
const TAG: string = 'ReminderService';
const BUNDLE_NAME: string = 'com.example.banbandefense';
const REMIND_HOUR: number = 9;

export class ReminderService {
  /**
   * 为一个事件调度提醒（提前 1 天 09:00 + 当天 09:00，已过时刻自动跳过）。
   * 返回 reminderId 的 JSON 数组字符串（用于后续取消）。
   */
  static async scheduleForEvent(ev: CountdownEventData): Promise<string> {
    const ids: number[] = [];
    const now: number = Date.now();
    const dayBefore: number = ev.targetDate - DAY_MS;
    if (dayBefore + REMIND_HOUR * 3600000 > now) {
      const id = await ReminderService.publishOne(ev, dayBefore, false, ids.length);
      ids.push(id);
    }
    if (ev.targetDate + REMIND_HOUR * 3600000 > now) {
      const id = await ReminderService.publishOne(ev, ev.targetDate, true, ids.length);
      ids.push(id);
    }
    return JSON.stringify(ids);
  }

  private static async publishOne(ev: CountdownEventData, dayStart: number, isToday: boolean, slot: number): Promise<number> {
    const d = new Date(dayStart);
    const req: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: {
        year: d.getFullYear(),
        month: d.getMonth() + 1,
        day: d.getDate(),
        hour: REMIND_HOUR,
        minute: 0,
        second: 0
      },
      repeatMonths: [],
      repeatDays: [],
      wantAgent: { pkgName: BUNDLE_NAME, abilityName: 'EntryAbility' },
      title: ev.title,
      content: isToday ? '今天就是「' + ev.title + '」！' : '明天就是「' + ev.title + '」啦',
      notificationId: ev.id * 10 + slot
    };
    return await reminderAgentManager.publishReminder(req);
  }

  /** 取消一个 JSON id 串中的全部提醒（空串安全） */
  static async cancelByIds(idsJson: string): Promise<void> {
    if (idsJson.length === 0) {
      return;
    }
    try {
      const ids = JSON.parse(idsJson) as number[];
      for (const id of ids) {
        try {
          await reminderAgentManager.cancelReminder(id);
        } catch (err) {
          hilog.warn(DOMAIN, TAG, 'cancelReminder %{public}d 失败（可能已触发）: %{public}s', id, JSON.stringify(err));
        }
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'reminderIds 解析失败: %{public}s', JSON.stringify(err));
    }
  }

  /** 删除或关闭提醒时的统一入口 */
  static async cancelForEvent(ev: CountdownEventData): Promise<void> {
    await ReminderService.cancelByIds(ev.reminderIds);
  }

  /** 取消单个 reminder */
  static async cancelOne(id: number): Promise<void> {
    await ReminderService.cancelByIds(JSON.stringify([id]));
  }

  /** 通用单次提醒（番茄钟兜底等场景复用），返回 reminderId */
  static async scheduleAt(ts: number, title: string, content: string, notificationId: number): Promise<number> {
    const d = new Date(ts);
    const req: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: {
        year: d.getFullYear(),
        month: d.getMonth() + 1,
        day: d.getDate(),
        hour: d.getHours(),
        minute: d.getMinutes(),
        second: d.getSeconds()
      },
      repeatMonths: [],
      repeatDays: [],
      wantAgent: { pkgName: BUNDLE_NAME, abilityName: 'EntryAbility' },
      title: title,
      content: content,
      notificationId: notificationId
    };
    return await reminderAgentManager.publishReminder(req);
  }

  /** 应用启动时全量校正：让提醒与库内数据保持一致（SPEC_M1 5 节兜底） */
  static async reconcile(): Promise<void> {
    try {
      const events = await CountdownRepository.listAll();
      const today = DateUtils.todayStart();
      for (const ev of events) {
        const shouldRemind: boolean = ev.remindEnabled && ev.targetDate >= today;
        await ReminderService.cancelByIds(ev.reminderIds);
        if (shouldRemind) {
          const ids = await ReminderService.scheduleForEvent(ev);
          await CountdownRepository.updateReminderIds(ev.id, ids);
        } else if (ev.reminderIds.length > 0) {
          await CountdownRepository.updateReminderIds(ev.id, '');
        }
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'reconcile 失败: %{public}s', JSON.stringify(err));
    }
  }
}
