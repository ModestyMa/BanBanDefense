// 倒数日仓储：countdown_event 表的唯一数据访问入口（页面禁止直接访问数据库）
import { relationalStore } from '@kit.ArkData';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { CountdownEventData } from '../model/CountdownEvent';

const TABLE: string = 'countdown_event';

export class CountdownRepository {
  static async insert(ev: CountdownEventData): Promise<number> {
    const bucket: relationalStore.ValuesBucket = {
      'title': ev.title,
      'target_date': ev.targetDate,
      'is_lunar': 0,
      'repeat_rule': null,
      'category': ev.category,
      'is_top': ev.isTop ? 1 : 0,
      'linked_account_id': null,
      'note': ev.note,
      'remind_enabled': ev.remindEnabled ? 1 : 0,
      'reminder_ids': ev.reminderIds,
      'created_at': ev.createdAt
    };
    return await DatabaseHelper.get().insert(TABLE, bucket);
  }

  static async update(ev: CountdownEventData): Promise<number> {
    const bucket: relationalStore.ValuesBucket = {
      'title': ev.title,
      'target_date': ev.targetDate,
      'category': ev.category,
      'is_top': ev.isTop ? 1 : 0,
      'note': ev.note,
      'remind_enabled': ev.remindEnabled ? 1 : 0,
      'reminder_ids': ev.reminderIds
    };
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', ev.id);
    return await DatabaseHelper.get().update(bucket, predicates);
  }

  static async updateReminderIds(id: number, reminderIds: string): Promise<number> {
    const bucket: relationalStore.ValuesBucket = { 'reminder_ids': reminderIds };
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);
    return await DatabaseHelper.get().update(bucket, predicates);
  }

  static async deleteById(id: number): Promise<number> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);
    return await DatabaseHelper.get().delete(predicates);
  }

  static async findById(id: number): Promise<CountdownEventData | null> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);
    const rs = await DatabaseHelper.get().query(predicates);
    try {
      if (rs.goToFirstRow()) {
        return CountdownRepository.rowToEvent(rs);
      }
      return null;
    } finally {
      rs.close();
    }
  }

  static async listAll(): Promise<CountdownEventData[]> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    const rs = await DatabaseHelper.get().query(predicates);
    const out: CountdownEventData[] = [];
    try {
      while (rs.goToNextRow()) {
        out.push(CountdownRepository.rowToEvent(rs));
      }
      return out;
    } finally {
      rs.close();
    }
  }

  static async count(): Promise<number> {
    const all = await CountdownRepository.listAll();
    return all.length;
  }

  private static rowToEvent(rs: relationalStore.ResultSet): CountdownEventData {
    const noteIdx = rs.getColumnIndex('note');
    const reminderIdx = rs.getColumnIndex('reminder_ids');
    const ev: CountdownEventData = {
      id: rs.getLong(rs.getColumnIndex('id')),
      title: rs.getString(rs.getColumnIndex('title')),
      targetDate: rs.getLong(rs.getColumnIndex('target_date')),
      category: rs.getString(rs.getColumnIndex('category')),
      isTop: rs.getLong(rs.getColumnIndex('is_top')) === 1,
      remindEnabled: rs.getLong(rs.getColumnIndex('remind_enabled')) === 1,
      note: rs.isColumnNull(noteIdx) ? '' : rs.getString(noteIdx),
      reminderIds: rs.isColumnNull(reminderIdx) ? '' : rs.getString(reminderIdx),
      createdAt: rs.getLong(rs.getColumnIndex('created_at'))
    };
    return ev;
  }
}
