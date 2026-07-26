// 流水实体（transaction_record 表）
export interface TransactionData {
  id: number;
  accountId: number;
  /** 金额（元，恒正数，方向由 direction 决定；读写经 MoneyUtils 规整） */
  amount: number;
  /** 'in' 收入 | 'out' 支出 */
  direction: string;
  /** food / transport / shopping / housing / entertainment / salary / other */
  category: string;
  /** 备注（DB 列名 counterparty），可空 */
  note: string;
  tradeTime: number;
  /** 'manual'（V1.0 导入写其他值） */
  source: string;
  createdAt: number;
}

export function newTransaction(): TransactionData {
  const tx: TransactionData = {
    id: 0,
    accountId: 0,
    amount: 0,
    direction: 'out',
    category: 'food',
    note: '',
    tradeTime: 0,
    source: 'manual',
    createdAt: 0
  };
  return tx;
}
