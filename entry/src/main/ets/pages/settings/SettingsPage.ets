// 设置页（SPEC_M5 4.3）：隐私政策常驻入口 / 清除全部数据（双重确认）/ 关于伴伴
import { router, promptAction } from '@kit.ArkUI';
import { bundleManager } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DataResetService } from '../../service/DataResetService';
import { countdownVM } from '../../viewmodel/CountdownViewModel';
import { accountVM } from '../../viewmodel/AccountViewModel';
import { pomodoroVM } from '../../viewmodel/PomodoroViewModel';
import { homeVM } from '../../viewmodel/HomeViewModel';
import { ResponsiveContainer } from '../../components/ResponsiveContainer';

const DOMAIN: number = 0x1503;
const TAG: string = 'SettingsPage';
const ROUTE_PRIVACY: string = 'pages/settings/PrivacyPolicyPage';

@Entry
@ComponentV2
struct SettingsPage {
  @Local clearing: boolean = false;

  private aboutText(): string {
    let version: string = '1.0.0';
    try {
      const info = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      if (info.versionName.length > 0) {
        version = info.versionName;
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, '读取版本号失败: %{public}s', JSON.stringify(err));
    }
    return getContext(this).resourceManager.getStringSync($r('app.string.about_fmt'),
      version, info_safePackageName());
  }

  private showAbout(): void {
    AlertDialog.show({
      title: $r('app.string.settings_about'),
      message: this.aboutText(),
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: $r('app.string.action_ok'),
        fontColor: $r('app.color.primary'),
        action: () => {}
      }
    });
  }

  /** 清除全部数据：双重确认（SPEC_M5 决策 9） */
  private confirmClear1(): void {
    AlertDialog.show({
      title: $r('app.string.clear_confirm_title'),
      message: $r('app.string.clear_confirm_msg'),
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: $r('app.string.action_cancel'),
        fontColor: $r('app.color.text_secondary'),
        action: () => {}
      },
      secondaryButton: {
        value: $r('app.string.settings_clear'),
        fontColor: $r('app.color.danger'),
        action: () => {
          this.confirmClear2();
        }
      }
    });
  }

  private confirmClear2(): void {
    AlertDialog.show({
      title: $r('app.string.clear_confirm_title'),
      message: $r('app.string.clear_confirm2_msg'),
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: $r('app.string.action_cancel'),
        fontColor: $r('app.color.text_secondary'),
        action: () => {}
      },
      secondaryButton: {
        value: $r('app.string.settings_clear'),
        fontColor: $r('app.color.danger'),
        action: () => {
          this.doClear();
        }
      }
    });
  }

  private doClear(): void {
    if (this.clearing) {
      return;
    }
    this.clearing = true;
    DataResetService.resetAll()
      .then(() => {
        return countdownVM.load();
      })
      .then(() => {
        return accountVM.load();
      })
      .then(() => {
        return pomodoroVM.load();
      })
      .then(() => {
        return homeVM.load();
      })
      .then(() => {
        promptAction.showToast({ message: $r('app.string.toast_cleared') });
        router.back();
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, '清除全部数据失败: %{public}s', err.message);
        promptAction.showToast({ message: $r('app.string.toast_save_failed') });
      })
      .finally(() => {
        this.clearing = false;
      });
  }

  @Builder
  navBar() {
    Row() {
      Text('‹ ' + getContext(this).resourceManager.getStringSync($r('app.string.action_back')))
        .fontSize(15)
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          router.back();
        })
      Text($r('app.string.settings_title'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .margin({ right: 40 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 12 })
  }

  @Builder
  settingRow(icon: string, label: Resource, danger: boolean, onTap: () => void) {
    Row({ space: 12 }) {
      Text(icon)
        .fontSize(20)
      Text(label)
        .fontSize(15)
        .fontColor(danger ? $r('app.color.danger') : $r('app.color.text_primary'))
        .layoutWeight(1)
      Text('›')
        .fontSize(18)
        .fontColor($r('app.color.text_hint'))
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .onClick(onTap)
  }

  build() {
    Column() {
      ResponsiveContainer({ bgColor: $r('app.color.page_bg') }) {
      Column({ space: 12 }) {
        this.navBar()
        Column({ space: 12 }) {
          this.settingRow('🔒', $r('app.string.settings_privacy'), false, () => {
            router.pushUrl({ url: ROUTE_PRIVACY });
          })
          this.settingRow('🗑', $r('app.string.settings_clear'), true, () => {
            this.confirmClear1();
          })
          this.settingRow('ℹ️', $r('app.string.settings_about'), false, () => {
            this.showAbout();
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .height('100%')
    }
    }
    .width('100%')
    .height('100%')
  }
}

/** 关于弹窗里的包名（正式包名，D-011 定稿，随 bundleName 改动同步更新） */
function info_safePackageName(): string {
  return 'com.modestyma.banban';
}
