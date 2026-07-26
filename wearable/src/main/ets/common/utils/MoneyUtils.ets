// 【手表端副本】与 entry module 同步维护，V1.0 抽 HAR 后删除（SPEC_M6 决策 8）
// 金额工具（纯函数，SPEC_M4 5.1；全部金额计算以「分」整数进行，杜绝浮点误差）
// 单元测试见 entry/src/test/MoneyUtils.test.ets
export class MoneyUtils {
  /** 元 → 分（四舍五入到分） */
  static toCents(yuan: number): number {
    return Math.round(yuan * 100);
  }

  /** 分 → 元 */
  static toYuan(cents: number): number {
    return cents / 100;
  }

  /** 校验金额输入串：正数、最多 2 位小数、≤ 999999.99 */
  static isValidAmount(text: string): boolean {
    const trimmed = text.trim();
    if (!/^\d+(\.\d{1,2})?$/.test(trimmed)) {
      return false;
    }
    const v = Number(trimmed);
    return v > 0 && v <= 999999.99;
  }

  /** 分 → 固定 2 位小数字符串（1234.5 元=123450 分 → "1234.50"；5 分 → "0.05"） */
  static formatAmount(cents: number): string {
    const sign: string = cents < 0 ? '-' : '';
    const abs: number = Math.abs(cents);
    const intPart: number = Math.floor(abs / 100);
    const dec: number = abs % 100;
    const decText: string = dec < 10 ? '0' + dec.toString() : dec.toString();
    return sign + intPart.toString() + '.' + decText;
  }

  /** 带方向符号的金额串：支出 "-12.50" / 收入 "+8000.00" */
  static signedText(direction: string, cents: number): string {
    const prefix: string = direction === 'in' ? '+' : '-';
    return prefix + MoneyUtils.formatAmount(cents);
  }
}
