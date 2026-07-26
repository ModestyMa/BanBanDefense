// 报表聚合工具（纯函数，SPEC_M5 5.2；金额全程分整数，单测见 entry/src/test/ReportUtils.test.ets）
import { TransactionData } from '../../data/model/Transaction';
import { MoneyUtils } from './MoneyUtils';
import { DateUtils } from './DateUtils';

/** 分类聚合结果 */
export interface CategorySum {
  key: string;
  cents: number;
}

export class ReportUtils {
  /** 月份区间 [起, 止)：当月 1 日 00:00 ~ 次月 1 日 00:00（month 取 1~12，跨年自动进位） */
  static monthRange(year: number, month: number): number[] {
    const start: number = DateUtils.dayStartOf(year, month, 1);
    const end: number = month === 12
      ? DateUtils.dayStartOf(year + 1, 1, 1)
      : DateUtils.dayStartOf(year, month + 1, 1);
    return [start, end];
  }

  /** 按分类聚合（仅统计指定 direction），分整数求和，按金额降序 */
  static aggregateByCategory(txs: TransactionData[], direction: string): CategorySum[] {
    const map = new Map<string, number>();
    for (const tx of txs) {
      if (tx.direction !== direction) {
        continue;
      }
      const prev: number = map.get(tx.category) ?? 0;
      map.set(tx.category, prev + MoneyUtils.toCents(tx.amount));
    }
    const out: CategorySum[] = [];
    map.forEach((cents: number, key: string) => {
      out.push({ key: key, cents: cents });
    });
    out.sort((a: CategorySum, b: CategorySum): number => b.cents - a.cents);
    return out;
  }

  /** 占比百分数（整数）：前 N-1 项四舍五入，最后一项 = 100 - 前面之和，保证合计恰为 100 */
  static sharePercents(items: CategorySum[]): number[] {
    const out: number[] = [];
    if (items.length === 0) {
      return out;
    }
    let total = 0;
    for (const it of items) {
      total += it.cents;
    }
    if (total <= 0) {
      for (const it of items) {
        out.push(0);
      }
      return out;
    }
    let used = 0;
    for (let i = 0; i < items.length; i++) {
      if (i === items.length - 1) {
        out.push(100 - used);
      } else {
        const p: number = Math.round(items[i].cents * 100 / total);
        out.push(p);
        used += p;
      }
    }
    return out;
  }

  /** 指定方向的合计（分） */
  static sumByDirection(txs: TransactionData[], direction: string): number {
    let total = 0;
    for (const tx of txs) {
      if (tx.direction === direction) {
        total += MoneyUtils.toCents(tx.amount);
      }
    }
    return total;
  }

  /** 笔数（指定方向） */
  static countByDirection(txs: TransactionData[], direction: string): number {
    let n = 0;
    for (const tx of txs) {
      if (tx.direction === direction) {
        n++;
      }
    }
    return n;
  }
}
