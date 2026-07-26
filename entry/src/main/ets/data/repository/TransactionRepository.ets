// 流水仓储：transaction_record 表唯一访问入口
import { relationalStore } from '@kit.ArkData';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { TransactionData } from '../model/Transaction';
import { DateUtils } from '../../common/utils/DateUtils';
import { MoneyUtils } from '../../common/utils/MoneyUtils';

const TABLE: string = 'transaction_record';

export class TransactionRepository {
  static async insert(tx: TransactionData): Promise<number> {
    const bucket: relationalStore.ValuesBucket = {
      'account_id': tx.accountId,
      'amount': MoneyUtils.toYuan(MoneyUtils.toCents(tx.amount)),
      'direction': tx.direction,
      'category': tx.category,
      'counterparty': tx.note,
      'trade_time': tx.tradeTime,
      'source': tx.source,
      'external_no': null,
      'created_at': tx.createdAt
    };
    return await DatabaseHelper.get().insert(TABLE, bucket);
  }

  static async update(tx: TransactionData): Promise<number> {
    const bucket: relationalStore.ValuesBucket = {
      'account_id': tx.accountId,
      'amount': MoneyUtils.toYuan(MoneyUtils.toCents(tx.amount)),
      'direction': tx.direction,
      'category': tx.category,
      'counterparty': tx.note,
      'trade_time': tx.tradeTime
    };
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', tx.id);
    return await DatabaseHelper.get().update(bucket, predicates);
  }

  static async deleteById(id: number): Promise<number> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);
    return await DatabaseHelper.get().delete(predicates);
  }

  static async findById(id: number): Promise<TransactionData | null> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);
    const rs = await DatabaseHelper.get().query(predicates);
    try {
      if (rs.goToFirstRow()) {
        return TransactionRepository.rowToTx(rs);
      }
      return null;
    } finally {
      rs.close();
    }
  }

  /** 全部流水（trade_time 倒序） */
  static async listAll(): Promise<TransactionData[]> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.orderByDesc('trade_time');
    const rs = await DatabaseHelper.get().query(predicates);
    const out: TransactionData[] = [];
    try {
      while (rs.goToNextRow()) {
        out.push(TransactionRepository.rowToTx(rs));
      }
      return out;
    } finally {
      rs.close();
    }
  }

  /** 当日流水笔数（卡片「今天已记账」文案用，SPEC_M4 5.4） */
  static async countToday(): Promise<number> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.greaterThanOrEqualTo('trade_time', DateUtils.todayStart());
    const rs = await DatabaseHelper.get().query(predicates);
    try {
      return rs.rowCount;
    } finally {
      rs.close();
    }
  }

  /** 区间流水 [startTs, endTs)（月度报表用，SPEC_M5 5.2；trade_time 倒序） */
  static async listByRange(startTs: number, endTs: number): Promise<TransactionData[]> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.greaterThanOrEqualTo('trade_time', startTs);
    predicates.lessThan('trade_time', endTs);
    predicates.orderByDesc('trade_time');
    const rs = await DatabaseHelper.get().query(predicates);
    const out: TransactionData[] = [];
    try {
      while (rs.goToNextRow()) {
        out.push(TransactionRepository.rowToTx(rs));
      }
      return out;
    } finally {
      rs.close();
    }
  }

  private static rowToTx(rs: relationalStore.ResultSet): TransactionData {
    const noteIdx = rs.getColumnIndex('counterparty');
    const tx: TransactionData = {
      id: rs.getLong(rs.getColumnIndex('id')),
      accountId: rs.getLong(rs.getColumnIndex('account_id')),
      amount: rs.getDouble(rs.getColumnIndex('amount')),
      direction: rs.getString(rs.getColumnIndex('direction')),
      category: rs.getString(rs.getColumnIndex('category')),
      note: rs.isColumnNull(noteIdx) ? '' : rs.getString(noteIdx),
      tradeTime: rs.getLong(rs.getColumnIndex('trade_time')),
      source: rs.getString(rs.getColumnIndex('source')),
      createdAt: rs.getLong(rs.getColumnIndex('created_at'))
    };
    return tx;
  }
}
