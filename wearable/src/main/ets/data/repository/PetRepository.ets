// 【手表端副本】与 entry module 同步维护，V1.0 抽 HAR 后删除（SPEC_M6 决策 8）
// 宠物状态仓储：pet_state 单行表（id=1 恒为一行）
import { relationalStore } from '@kit.ArkData';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { PetStateData, defaultPetState } from '../model/PetState';

const TABLE: string = 'pet_state';

export class PetRepository {
  /** 读取唯一行；不存在则插入默认行 */
  static async getOrCreate(): Promise<PetStateData> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.limitAs(1);
    const rs = await DatabaseHelper.get().query(predicates);
    try {
      if (rs.goToFirstRow()) {
        const st: PetStateData = {
          id: rs.getLong(rs.getColumnIndex('id')),
          level: rs.getLong(rs.getColumnIndex('level')),
          exp: rs.getLong(rs.getColumnIndex('exp')),
          skin: rs.isColumnNull(rs.getColumnIndex('skin')) ? 'default' : rs.getString(rs.getColumnIndex('skin')),
          mood: rs.getLong(rs.getColumnIndex('mood')),
          streakDays: rs.getLong(rs.getColumnIndex('streak_days')),
          lastActiveDate: rs.getLong(rs.getColumnIndex('last_active_date'))
        };
        return st;
      }
    } finally {
      rs.close();
    }
    const def = defaultPetState();
    const bucket: relationalStore.ValuesBucket = {
      'level': def.level,
      'exp': def.exp,
      'skin': def.skin,
      'mood': def.mood,
      'streak_days': def.streakDays,
      'last_active_date': def.lastActiveDate
    };
    def.id = await DatabaseHelper.get().insert(TABLE, bucket);
    return def;
  }

  static async update(st: PetStateData): Promise<number> {
    const bucket: relationalStore.ValuesBucket = {
      'level': st.level,
      'exp': st.exp,
      'skin': st.skin,
      'mood': st.mood,
      'streak_days': st.streakDays,
      'last_active_date': st.lastActiveDate
    };
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', st.id);
    return await DatabaseHelper.get().update(bucket, predicates);
  }
}
