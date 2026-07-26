// MoneyUtils 单元测试（SPEC_M4 §7：分↔元转换 / 校验 / 格式化 / 带符号文案边界用例）
import { describe, it, expect } from '@ohos/hypium';
import { MoneyUtils } from '../main/ets/common/utils/MoneyUtils';

export default function moneyUtilsTest() {
  describe('MoneyUtilsTest', () => {

    it('toCents_常规与四舍五入', 0, () => {
      expect(MoneyUtils.toCents(0.01)).assertEqual(1);
      expect(MoneyUtils.toCents(12.5)).assertEqual(1250);
      expect(MoneyUtils.toCents(0.005)).assertEqual(1);
      expect(MoneyUtils.toCents(999999.99)).assertEqual(99999999);
    });

    it('toYuan_常规', 0, () => {
      expect(MoneyUtils.toYuan(1250)).assertEqual(12.5);
      expect(MoneyUtils.toYuan(1)).assertEqual(0.01);
      expect(MoneyUtils.toYuan(0)).assertEqual(0);
    });

    it('toCents_toYuan_往返一致', 0, () => {
      const cents: number = 123456789;
      expect(MoneyUtils.toCents(MoneyUtils.toYuan(cents))).assertEqual(cents);
    });

    it('isValidAmount_合法输入', 0, () => {
      expect(MoneyUtils.isValidAmount('1')).assertTrue();
      expect(MoneyUtils.isValidAmount('0.01')).assertTrue();
      expect(MoneyUtils.isValidAmount('12.5')).assertTrue();
      expect(MoneyUtils.isValidAmount('12.55')).assertTrue();
      expect(MoneyUtils.isValidAmount('999999.99')).assertTrue();
      expect(MoneyUtils.isValidAmount(' 12.5 ')).assertTrue();
    });

    it('isValidAmount_非法输入', 0, () => {
      expect(MoneyUtils.isValidAmount('')).assertFalse();
      expect(MoneyUtils.isValidAmount('0')).assertFalse();
      expect(MoneyUtils.isValidAmount('0.00')).assertFalse();
      expect(MoneyUtils.isValidAmount('-5')).assertFalse();
      expect(MoneyUtils.isValidAmount('12.555')).assertFalse();
      expect(MoneyUtils.isValidAmount('abc')).assertFalse();
      expect(MoneyUtils.isValidAmount('1.')).assertFalse();
      expect(MoneyUtils.isValidAmount('.5')).assertFalse();
      expect(MoneyUtils.isValidAmount('1000000')).assertFalse();
    });

    it('formatAmount_固定两位小数', 0, () => {
      expect(MoneyUtils.formatAmount(123450)).assertEqual('1234.50');
      expect(MoneyUtils.formatAmount(5)).assertEqual('0.05');
      expect(MoneyUtils.formatAmount(0)).assertEqual('0.00');
      expect(MoneyUtils.formatAmount(-1250)).assertEqual('-12.50');
    });

    it('signedText_方向符号', 0, () => {
      expect(MoneyUtils.signedText('out', 1250)).assertEqual('-12.50');
      expect(MoneyUtils.signedText('in', 800000)).assertEqual('+8000.00');
    });
  });
}
