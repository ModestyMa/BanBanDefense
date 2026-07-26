// 清除全部数据编排（SPEC_M5 5.1）：取消全部倒数日提醒 → 6 表物理 DELETE → 重推卡片（默认宠物状态）
// 保留 pet_card_prefs 的 formIds（桌面卡片仍在，推送时自动落默认状态）；保留首启隐私同意标记
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CountdownRepository } from '../data/repository/CountdownRepository';
import { CountdownEventData } from '../data/model/CountdownEvent';
import { ReminderService } from './ReminderService';
import { DatabaseHelper } from '../data/database/DatabaseHelper';
import { PetCardService } from './PetCardService';

const DOMAIN: number = 0x1502;
const TAG: string = 'DataResetService';

export class DataResetService {
  static async resetAll(): Promise<void> {
    // 1. 逐个取消倒数日提醒（失败不阻断，继续清库）
    const events: CountdownEventData[] = await CountdownRepository.listAll();
    for (const ev of events) {
      try {
        await ReminderService.cancelForEvent(ev);
      } catch (err) {
        hilog.error(DOMAIN, TAG, '取消提醒失败 id=%{public}d: %{public}s', ev.id, JSON.stringify(err));
      }
    }
    // 2. 6 表物理删除
    await DatabaseHelper.clearAll();
    // 3. 重推卡片（pet_state 已空，getState 落默认值）
    try {
      await PetCardService.pushToCards();
    } catch (err) {
      hilog.error(DOMAIN, TAG, '清数据后推卡片失败: %{public}s', JSON.stringify(err));
    }
  }
}
