import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, display } from '@kit.ArkUI';
import { DatabaseHelper } from '../data/database/DatabaseHelper';
import { ReminderService } from '../service/ReminderService';
import { AppContextHolder } from '../common/AppContextHolder';
import { BreakpointHelper } from '../common/utils/BreakpointHelper';

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
    // 断点系统：注册窗口尺寸监听 → AppStorage（SPEC_M6 §3，假设 API §10-1 待核验）
    this.trackWindowWidth(windowStage);

    windowStage.loadContent('pages/MainPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  /** 窗口宽度（px→vp）写入 AppStorage，尺寸变化时更新（断点系统数据源） */
  private trackWindowWidth(windowStage: window.WindowStage): void {
    windowStage.getMainWindow()
      .then((win: window.Window) => {
        const update = (): void => {
          try {
            const rect = win.getWindowProperties().windowRect;
            let density: number = 1;
            try {
              density = display.getDefaultDisplaySync().densityPixels;
            } catch (err) {
              hilog.error(DOMAIN, 'testTag', '读取屏幕密度失败: %{public}s', JSON.stringify(err));
            }
            const widthVp: number = density > 0 ? rect.width / density : rect.width;
            AppStorage.setOrCreate(BreakpointHelper.KEY_WIDTH, widthVp);
          } catch (err) {
            hilog.error(DOMAIN, 'testTag', '窗口宽度更新失败: %{public}s', JSON.stringify(err));
          }
        };
        update();
        win.on('windowSizeChange', () => {
          update();
        });
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', '获取主窗口失败: %{public}s', JSON.stringify(err));
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