// 卡片推送服务（SPEC_M3 2.3）：行为发生后组装数据 → formProvider.updateForm 推给全部伴伴卡片
// formId 列表用 preferences 持久化（卡片添加/移除时登记）
// 假设API清单（人工核验后删除）:
// 1. formProvider.updateForm(formId: string, data: formBindingData.FormBindingData): Promise<void>
// 2. formBindingData.createFormBindingData(obj) 接受 string/number 值的对象字面量
// 3. preferences.getPreferencesSync / getSync / putSync / flush 用法
import { formProvider, formBindingData } from '@kit.FormKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DatabaseHelper } from '../data/database/DatabaseHelper';
import { PetEngine, PetTimeOfDay } from './PetEngine';
import { PetStateData } from '../data/model/PetState';
import { AppContextHolder } from '../common/AppContextHolder';

const DOMAIN: number = 0x1300;
const TAG: string = 'PetCardService';
const PREFS_NAME: string = 'pet_card_prefs';
const KEY_FORM_IDS: string = 'formIds';

export class PetCardService {
  private static async ensureDb(context: common.Context): Promise<void> {
    if (!DatabaseHelper.isReady()) {
      await DatabaseHelper.init(context);
    }
  }

  private static loadFormIds(context: common.Context): string[] {
    const prefs = preferences.getPreferencesSync(context, { name: PREFS_NAME });
    const raw = prefs.getSync(KEY_FORM_IDS, '[]') as string;
    try {
      return JSON.parse(raw) as string[];
    } catch (err) {
      return [];
    }
  }

  private static saveFormIds(context: common.Context, ids: string[]): void {
    const prefs = preferences.getPreferencesSync(context, { name: PREFS_NAME });
    prefs.putSync(KEY_FORM_IDS, JSON.stringify(ids));
    prefs.flush();
  }

  static async registerFormId(context: common.Context, formId: string): Promise<void> {
    const ids = PetCardService.loadFormIds(context);
    if (ids.indexOf(formId) < 0) {
      ids.push(formId);
      PetCardService.saveFormIds(context, ids);
    }
  }

  static async unregisterFormId(context: common.Context, formId: string): Promise<void> {
    const ids = PetCardService.loadFormIds(context);
    const next = ids.filter((id: string) => id !== formId);
    PetCardService.saveFormIds(context, next);
  }

  /**
   * 组装卡片数据（心情 emoji / 文案 / 等级 / 连续天数）。
   * C1（mini-SPEC §1.6-3）：文案改用 PetEngine.getPetSpeech()，复用现有 moodText 通道
   * （实际卡片仅 2×2，无 2×4——SPEC 偏差已记录交接单，碎碎念承载在既有文案行，无布局改动）。
   * C3（mini-SPEC §3.4）：表情按时段叠加，SLEEP/NIGHT 强制覆盖 mood，不新增定时任务。
   */
  private static async buildCardData(context: common.Context, st: PetStateData): Promise<Record<string, string | number>> {
    const hour: number = new Date().getHours();
    const tod = PetEngine.timeOfDayFromHour(hour);
    const emoji: string = PetEngine.overlayTimeEmoji(PetEngine.moodEmoji(st.mood), tod);
    const rm = context.resourceManager;
    let text: string = rm.getStringSync($r('app.string.pet_speech_default'));
    try {
      if (tod === PetTimeOfDay.SLEEP) {
        text = rm.getStringSync($r('app.string.pet_clock_sleep'));
      } else if (tod === PetTimeOfDay.MORNING) {
        text = rm.getStringSync($r('app.string.pet_clock_morning'));
      } else {
        const speech = await PetEngine.getPetSpeech(context);
        if (speech.text.length > 0) {
          text = speech.text;
        }
      }
    } catch (err) {
      // 碎碎念失败保持兜底文案，不影响卡片刷新
    }
    const levelText: string = rm.getStringSync($r('app.string.card_level_prefix')) + st.level.toString();
    const streakText: string = rm.getStringSync($r('app.string.card_streak_prefix')) + st.streakDays.toString() +
      rm.getStringSync($r('app.string.card_streak_suffix'));
    const data: Record<string, string | number> = {
      'moodEmoji': emoji,
      'moodText': text,
      'levelText': levelText,
      'streakText': streakText
    };
    return data;
  }

  /** 推送给单个卡片 */
  static async pushToFormId(context: common.Context, formId: string): Promise<void> {
    try {
      await PetCardService.ensureDb(context);
      const st = await PetEngine.getState();
      const data = await PetCardService.buildCardData(context, st);
      await formProvider.updateForm(formId, formBindingData.createFormBindingData(data));
    } catch (err) {
      hilog.error(DOMAIN, TAG, '推送卡片 %{public}s 失败: %{public}s', formId, JSON.stringify(err));
    }
  }

  /** 推送给全部已添加的伴伴卡片（App 侧行为后调用，无上下文时静默跳过） */
  static async pushToCards(): Promise<void> {
    const context = AppContextHolder.get();
    if (context === null) {
      return;
    }
    const ids = PetCardService.loadFormIds(context);
    for (const formId of ids) {
      await PetCardService.pushToFormId(context, formId);
    }
  }
}
