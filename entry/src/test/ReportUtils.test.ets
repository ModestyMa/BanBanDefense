// ReportUtils 单元测试（SPEC_M5 §7：月区间跨年边界 / 分类聚合 / 占比舍入补足 / 方向合计）
import { describe, it, expect } from '@ohos/hypium';
import { ReportUtils, CategorySum } from '../main/ets/common/utils/ReportUtils';
import { TransactionData, newTransaction } from '../main/ets/data/model/Transaction';
import { DateUtils } from '../main/ets/common/utils/DateUtils';

function mkTx(direction: string, category: string, amountYuan: number): TransactionData {
  const tx = newTransaction();
  tx.direction = direction;
  tx.category = category;
  tx.amount = amountYuan;
  return tx;
}

export default function reportUtilsTest() {
  describe('ReportUtilsTest', () => {

    it('monthRange_普通月', 0, () => {
      const range = ReportUtils.monthRange(2026, 7);
      expect(range[0]).assertEqual(DateUtils.dayStartOf(2026, 7, 1));
      expect(range[1]).assertEqual(DateUtils.dayStartOf(2026, 8, 1));
    });

    it('monthRange_12月跨年', 0, () => {
      const range = ReportUtils.monthRange(2026, 12);
      expect(range[0]).assertEqual(DateUtils.dayStartOf(2026, 12, 1));
      expect(range[1]).assertEqual(DateUtils.dayStartOf(2027, 1, 1));
    });

    it('aggregateByCategory_空列表', 0, () => {
      const empty: TransactionData[] = [];
      expect(ReportUtils.aggregateByCategory(empty, 'out').length).assertEqual(0);
    });

    it('aggregateByCategory_求和降序与方向过滤', 0, () => {
      const txs: TransactionData[] = [
        mkTx('out', 'transport', 5.00),
        mkTx('out', 'food', 10.00),
        mkTx('out', 'food', 2.50),
        mkTx('in', 'salary', 100.00)
      ];
      const out = ReportUtils.aggregateByCategory(txs, 'out');
      expect(out.length).assertEqual(2);
      expect(out[0].key).assertEqual('food');
      expect(out[0].cents).assertEqual(1250);
      expect(out[1].key).assertEqual('transport');
      expect(out[1].cents).assertEqual(500);
      const ins = ReportUtils.aggregateByCategory(txs, 'in');
      expect(ins.length).assertEqual(1);
      expect(ins[0].cents).assertEqual(10000);
    });

    it('sharePercents_空与单分类', 0, () => {
      const empty: CategorySum[] = [];
      expect(ReportUtils.sharePercents(empty).length).assertEqual(0);
      const one: CategorySum[] = [{ key: 'food', cents: 123 }];
      const p = ReportUtils.sharePercents(one);
      expect(p.length).assertEqual(1);
      expect(p[0]).assertEqual(100);
    });

    it('sharePercents_合计恰为100', 0, () => {
      const items: CategorySum[] = [
        { key: 'a', cents: 500 }, { key: 'b', cents: 250 }, { key: 'c', cents: 250 }
      ];
      const p = ReportUtils.sharePercents(items);
      expect(p[0]).assertEqual(50);
      expect(p[1]).assertEqual(25);
      expect(p[2]).assertEqual(25);
      // 三等分舍入场景：末项补足
      const thirds: CategorySum[] = [
        { key: 'a', cents: 100 }, { key: 'b', cents: 100 }, { key: 'c', cents: 100 }
      ];
      const p2 = ReportUtils.sharePercents(thirds);
      let sum = 0;
      for (const v of p2) {
        sum += v;
      }
      expect(sum).assertEqual(100);
    });

    it('sumByDirection与countByDirection', 0, () => {
      const txs: TransactionData[] = [
        mkTx('out', 'food', 12.34),
        mkTx('out', 'other', 0.01),
        mkTx('in', 'salary', 8000.00)
      ];
      expect(ReportUtils.sumByDirection(txs, 'out')).assertEqual(1235);
      expect(ReportUtils.sumByDirection(txs, 'in')).assertEqual(800000);
      expect(ReportUtils.countByDirection(txs, 'out')).assertEqual(2);
      expect(ReportUtils.countByDirection(txs, 'in')).assertEqual(1);
    });
  });
}
