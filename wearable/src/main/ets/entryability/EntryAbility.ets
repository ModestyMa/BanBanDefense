// 手表端入口 Ability（SPEC_M6 §4）：仅初始化 DB + AppContextHolder + 默认账户；无提醒/卡片服务
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DatabaseHelper } from '../data/database/DatabaseHelper';
import { AccountRepository } from '../data/repository/AccountRepository';
import { AppContextHolder } from '../common/AppContextHolder';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppContextHolder.set(this.context);
    // 数据底座初始化 → 默认账户初始化（SPEC_M6 §4：复用 initDefaultsIfEmpty）
    DatabaseHelper.init(this.context)
      .then(() => {
        return AccountRepository.initDefaultsIfEmpty();
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', '手表端数据库/默认账户初始化失败: %{public}s', err.message);
      });
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Watch Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Watch Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Watch Ability onWindowStageCreate');
    windowStage.loadContent('pages/WatchMainPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Watch Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Watch Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Watch Ability onBackground');
  }
}
