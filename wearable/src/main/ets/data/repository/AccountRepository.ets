// 【手表端副本】与 entry module 同步维护，V1.0 抽 HAR 后删除（SPEC_M6 决策 8）
// 账户仓储：account 表唯一访问入口；余额调整全程以「分」整数计算（SPEC_M4 5.2）
import { relationalStore } from '@kit.ArkData';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { AccountData, newAccount } from '../model/Account';
import { AccountType, accountTypeMetaOf } from '../../common/constants/AccountConstants';
import { MoneyUtils } from '../../common/utils/MoneyUtils';

const TABLE: string = 'account';

export class AccountRepository {
  static async insert(acc: AccountData): Promise<number> {
    const bucket: relationalStore.ValuesBucket = {
      'name': acc.name,
      'type': acc.type,
      'balance': MoneyUtils.toYuan(MoneyUtils.toCents(acc.balance)),
      'icon': acc.icon,
      'sort': acc.sort,
      'created_at': acc.createdAt
    };
    return await DatabaseHelper.get().insert(TABLE, bucket);
  }

  static async update(acc: AccountData): Promise<number> {
    const bucket: relationalStore.ValuesBucket = {
      'name': acc.name,
      'type': acc.type,
      'balance': MoneyUtils.toYuan(MoneyUtils.toCents(acc.balance)),
      'icon': acc.icon,
      'sort': acc.sort
    };
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', acc.id);
    return await DatabaseHelper.get().update(bucket, predicates);
  }

  static async deleteById(id: number): Promise<number> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);
    return await DatabaseHelper.get().delete(predicates);
  }

  static async findById(id: number): Promise<AccountData | null> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);
    const rs = await DatabaseHelper.get().query(predicates);
    try {
      if (rs.goToFirstRow()) {
        return AccountRepository.rowToAccount(rs);
      }
      return null;
    } finally {
      rs.close();
    }
  }

  /** 全部账户（sort 升序 → id 升序） */
  static async listAll(): Promise<AccountData[]> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.orderByAsc('sort');
    predicates.orderByAsc('id');
    const rs = await DatabaseHelper.get().query(predicates);
    const out: AccountData[] = [];
    try {
      while (rs.goToNextRow()) {
        out.push(AccountRepository.rowToAccount(rs));
      }
      return out;
    } finally {
      rs.close();
    }
  }

  static async count(): Promise<number> {
    const all = await AccountRepository.listAll();
    return all.length;
  }

  /** 余额调整（deltaCents 可为负）；全程分整数，新余额规整后写回 */
  static async adjustBalance(accountId: number, deltaCents: number): Promise<void> {
    const acc = await AccountRepository.findById(accountId);
    if (acc === null) {
      throw new Error('账户不存在 id=' + accountId.toString());
    }
    const newCents: number = MoneyUtils.toCents(acc.balance) + deltaCents;
    acc.balance = MoneyUtils.toYuan(newCents);
    const bucket: relationalStore.ValuesBucket = { 'balance': acc.balance };
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', accountId);
    await DatabaseHelper.get().update(bucket, predicates);
  }

  /** 账户下是否有流水（有则禁止删除，SPEC_M4 §1-8） */
  static async hasTransactions(accountId: number): Promise<boolean> {
    const predicates = new relationalStore.RdbPredicates('transaction_record');
    predicates.equalTo('account_id', accountId);
    const rs = await DatabaseHelper.get().query(predicates);
    try {
      return rs.rowCount > 0;
    } finally {
      rs.close();
    }
  }

  /** 首次进入记账 Tab 时调用：表为空则初始化 4 个默认账户（SPEC_M4 §1-5） */
  static async initDefaultsIfEmpty(): Promise<void> {
    const cnt = await AccountRepository.count();
    if (cnt > 0) {
      return;
    }
    const defs: string[] = [AccountType.CASH, AccountType.WECHAT, AccountType.ALIPAY, AccountType.BANK];
    const names: string[] = ['现金', '微信', '支付宝', '银行卡'];
    for (let i = 0; i < defs.length; i++) {
      const acc = newAccount();
      acc.name = names[i];
      acc.type = defs[i];
      acc.icon = accountTypeMetaOf(defs[i]).emoji;
      acc.sort = i;
      acc.balance = 0;
      acc.createdAt = Date.now();
      await AccountRepository.insert(acc);
    }
  }

  private static rowToAccount(rs: relationalStore.ResultSet): AccountData {
    const iconIdx = rs.getColumnIndex('icon');
    const acc: AccountData = {
      id: rs.getLong(rs.getColumnIndex('id')),
      name: rs.getString(rs.getColumnIndex('name')),
      type: rs.getString(rs.getColumnIndex('type')),
      balance: rs.getDouble(rs.getColumnIndex('balance')),
      icon: rs.isColumnNull(iconIdx) ? accountTypeMetaOf(rs.getString(rs.getColumnIndex('type'))).emoji : rs.getString(iconIdx),
      sort: rs.getLong(rs.getColumnIndex('sort')),
      createdAt: rs.getLong(rs.getColumnIndex('created_at'))
    };
    return acc;
  }
}
