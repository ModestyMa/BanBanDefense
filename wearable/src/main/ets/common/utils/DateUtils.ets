// 【手表端副本】与 entry module 同步维护，V1.0 抽 HAR 后删除（SPEC_M6 决策 8）
// 日期工具（纯函数，必须有单元测试覆盖边界，见 entry/src/test/DateUtils.test.ets）
export const DAY_MS: number = 86400000;

export class DayInfo {
  /** 距今天数：>0 未来，0 今天，<0 过去 */
  days: number = 0;
  /** future | today | past */
  kind: string = 'future';
}

export class DateUtils {
  /** 本地时区今天 00:00 的毫秒时间戳 */
  static todayStart(): number {
    const d = new Date();
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }

  /** 本地时区指定日期 00:00 的毫秒时间戳（month 为 1-12） */
  static dayStartOf(year: number, month: number, day: number): number {
    const d = new Date(year, month - 1, day);
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }

  /** 两个"当天 00:00"时间戳之间相差的天数 */
  static daysBetween(targetStart: number, baseStart: number): number {
    return Math.round((targetStart - baseStart) / DAY_MS);
  }

  /** 目标日距今天的天数信息 */
  static dayInfo(targetStart: number): DayInfo {
    const info = new DayInfo();
    info.days = DateUtils.daysBetween(targetStart, DateUtils.todayStart());
    if (info.days > 0) {
      info.kind = 'future';
    } else if (info.days === 0) {
      info.kind = 'today';
    } else {
      info.kind = 'past';
    }
    return info;
  }

  /** 格式化为 2026/7/26 */
  static formatDate(ts: number): string {
    const d = new Date(ts);
    const m = d.getMonth() + 1;
    const day = d.getDate();
    return d.getFullYear().toString() + '/' + m.toString() + '/' + day.toString();
  }
}
