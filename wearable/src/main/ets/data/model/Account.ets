// 【手表端副本】与 entry module 同步维护，V1.0 抽 HAR 后删除（SPEC_M6 决策 8）
// 账户实体（account 表）
export interface AccountData {
  id: number;
  name: string;
  /** cash | wechat | alipay | bank | other */
  type: string;
  /** 当前余额（元，读写经 MoneyUtils 规整） */
  balance: number;
  /** emoji 图标字符 */
  icon: string;
  sort: number;
  createdAt: number;
}

export function newAccount(): AccountData {
  const acc: AccountData = {
    id: 0,
    name: '',
    type: 'cash',
    balance: 0,
    icon: '💵',
    sort: 0,
    createdAt: 0
  };
  return acc;
}
