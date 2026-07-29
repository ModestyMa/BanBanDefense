// 伴伴宠物卡片 FormExtensionAbility（SPEC_M3 2.1，人工核验区）
// 假设API清单（人工核验后删除）:
// 1. onAddForm 的 want.parameters['ohos.extra.param.key.form_identity'] 为 formId（Long）
// 2. FormExtensionAbility 生命周期签名（onAddForm 返回 FormBindingData）
// 3. pet_card_config.json 字段合法性（scheduledUpdateTime/updateDuration/supportDimensions）
import { FormExtensionAbility, formBindingData } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PetCardService } from '../service/PetCardService';

const DOMAIN: number = 0x1301;
const TAG: string = 'PetFormAbility';

export default class PetFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    let formId = '';
    const params = want.parameters;
    if (params !== undefined) {
      const identity = params['ohos.extra.param.key.form_identity'];
      if (identity !== undefined) {
        formId = identity.toString();
      }
    }
    if (formId.length > 0) {
      PetCardService.registerFormId(this.context, formId)
        .then(() => {
          return PetCardService.pushToFormId(this.context, formId);
        })
        .catch((err: Error) => {
          hilog.error(DOMAIN, TAG, '卡片登记/首刷失败: %{public}s', err.message);
        });
    }
    const rm = this.context.resourceManager;
    const levelText: string = rm.getStringSync($r('app.string.card_level_prefix')) + '1';
    const streakText: string = rm.getStringSync($r('app.string.card_streak_prefix')) + '0' +
      rm.getStringSync($r('app.string.card_streak_suffix'));
    return formBindingData.createFormBindingData({
      'moodEmoji': '😺',
      'moodText': rm.getStringSync($r('app.string.pet_speech_default')),
      'levelText': levelText,
      'streakText': streakText
    });
  }

  onCastToNormalForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onCastToNormalForm: %{public}s', formId);
  }

  onUpdateForm(formId: string): void {
    PetCardService.pushToFormId(this.context, formId).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'onUpdateForm 推送失败: %{public}s', err.message);
    });
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(DOMAIN, TAG, 'onFormEvent: %{public}s %{public}s', formId, message);
  }

  onRemoveForm(formId: string): void {
    PetCardService.unregisterFormId(this.context, formId).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '卡片注销失败: %{public}s', err.message);
    });
  }

  onAcquireFormState(want: Want): number {
    return 0;
  }
}
