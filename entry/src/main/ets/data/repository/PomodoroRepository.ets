// 番茄记录仓储：pomodoro_session 表的唯一访问入口
import { relationalStore } from '@kit.ArkData';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { PomodoroSessionData } from '../model/PomodoroSession';

const TABLE: string = 'pomodoro_session';

export class PomodoroRepository {
  static async insert(s: PomodoroSessionData): Promise<number> {
    const bucket: relationalStore.ValuesBucket = {
      'start_time': s.startTime,
      'end_time': s.endTime,
      'duration_min': s.durationMin,
      'tag': s.tag,
      'event_id': null
    };
    return await DatabaseHelper.get().insert(TABLE, bucket);
  }

  /** 最近 N 条（按开始时间倒序） */
  static async listRecent(limit: number): Promise<PomodoroSessionData[]> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.orderByDesc('start_time');
    predicates.limitAs(limit);
    const rs = await DatabaseHelper.get().query(predicates);
    const out: PomodoroSessionData[] = [];
    try {
      while (rs.goToNextRow()) {
        out.push(PomodoroRepository.rowToSession(rs));
      }
      return out;
    } finally {
      rs.close();
    }
  }

  /** 某时刻之后的全部记录（统计用） */
  static async listSince(fromTs: number): Promise<PomodoroSessionData[]> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.greaterThanOrEqualTo('start_time', fromTs);
    const rs = await DatabaseHelper.get().query(predicates);
    const out: PomodoroSessionData[] = [];
    try {
      while (rs.goToNextRow()) {
        out.push(PomodoroRepository.rowToSession(rs));
      }
      return out;
    } finally {
      rs.close();
    }
  }

  static async countAll(): Promise<number> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    const rs = await DatabaseHelper.get().query(predicates);
    try {
      return rs.rowCount;
    } finally {
      rs.close();
    }
  }

  private static rowToSession(rs: relationalStore.ResultSet): PomodoroSessionData {
    const s: PomodoroSessionData = {
      id: rs.getLong(rs.getColumnIndex('id')),
      startTime: rs.getLong(rs.getColumnIndex('start_time')),
      endTime: rs.getLong(rs.getColumnIndex('end_time')),
      durationMin: rs.getLong(rs.getColumnIndex('duration_min')),
      tag: rs.getString(rs.getColumnIndex('tag'))
    };
    return s;
  }
}
