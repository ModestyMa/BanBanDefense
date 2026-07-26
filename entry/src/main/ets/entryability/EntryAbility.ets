import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DatabaseHelper } from '../data/database/DatabaseHelper';
import { ReminderService } from '../service/ReminderService';
import { AppContextHolder } from '../common/AppContextHolder';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppContextHolder.set(this.context);
    this.handleLaunchTarget(want);
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    // 数据底座初始化 → 启动时全量校正提醒（SPEC_M1 第 5 节兜底）
    DatabaseHelper.init(this.context)
      .then(() => {
        return ReminderService.reconcile();
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', '数据库初始化/提醒校正失败: %{public}s', err.message);
      });
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppContextHolder.set(this.context);
    this.handleLaunchTarget(want);
  }

  /** 解析卡片 postCardAction 带来的 target 参数，写入 AppStorage 供 MainPage 路由 */
  private handleLaunchTarget(want: Want): void {
    const params = want.parameters;
    if (params === undefined || params === null) {
      return;
    }
    const target = params['target'];
    if (target !== undefined && target !== null) {
      AppStorage.setOrCreate('launchTarget', target.toString());
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/MainPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
