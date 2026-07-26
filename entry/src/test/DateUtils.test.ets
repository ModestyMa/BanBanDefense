// DateUtils 单元测试（SPEC_M1 3.2 边界用例：当天/明天/昨天/跨月/跨年/闰年/2100 年末）
import { describe, it, expect } from '@ohos/hypium';
import { DateUtils, DAY_MS } from '../main/ets/common/utils/DateUtils';

export default function dateUtilsTest() {
  describe('DateUtilsTest', () => {

    it('daysBetween_当天为0', 0, () => {
      const today = DateUtils.todayStart();
      expect(DateUtils.daysBetween(today, today)).assertEqual(0);
    });

    it('daysBetween_明天为1_昨天为负1', 0, () => {
      const today = DateUtils.todayStart();
      expect(DateUtils.daysBetween(today + DAY_MS, today)).assertEqual(1);
      expect(DateUtils.daysBetween(today - DAY_MS, today)).assertEqual(-1);
    });

    it('daysBetween_跨月', 0, () => {
      const jan31 = DateUtils.dayStartOf(2026, 1, 31);
      const feb1 = DateUtils.dayStartOf(2026, 2, 1);
      expect(DateUtils.daysBetween(feb1, jan31)).assertEqual(1);
      expect(DateUtils.daysBetween(jan31, feb1)).assertEqual(-1);
    });

    it('daysBetween_跨年', 0, () => {
      const dec31 = DateUtils.dayStartOf(2026, 12, 31);
      const jan1 = DateUtils.dayStartOf(2027, 1, 1);
      expect(DateUtils.daysBetween(jan1, dec31)).assertEqual(1);
    });

    it('daysBetween_闰年2月29', 0, () => {
      const feb28 = DateUtils.dayStartOf(2028, 2, 28);
      const feb29 = DateUtils.dayStartOf(2028, 2, 29);
      const mar1 = DateUtils.dayStartOf(2028, 3, 1);
      expect(DateUtils.daysBetween(feb29, feb28)).assertEqual(1);
      expect(DateUtils.daysBetween(mar1, feb28)).assertEqual(2);
    });

    it('daysBetween_2100年末', 0, () => {
      const dec30 = DateUtils.dayStartOf(2100, 12, 30);
      const dec31 = DateUtils.dayStartOf(2100, 12, 31);
      expect(DateUtils.daysBetween(dec31, dec30)).assertEqual(1);
    });

    it('dayInfo_三种kind', 0, () => {
      const today = DateUtils.todayStart();
      expect(DateUtils.dayInfo(today).kind).assertEqual('today');
      expect(DateUtils.dayInfo(today + DAY_MS).kind).assertEqual('future');
      expect(DateUtils.dayInfo(today - DAY_MS).kind).assertEqual('past');
      expect(DateUtils.dayInfo(today + 42 * DAY_MS).days).assertEqual(42);
      expect(DateUtils.dayInfo(today - 100 * DAY_MS).days).assertEqual(-100);
    });

    it('formatDate_格式正确', 0, () => {
      const ts = DateUtils.dayStartOf(2026, 7, 5);
      expect(DateUtils.formatDate(ts)).assertEqual('2026/7/5');
    });
  });
}
