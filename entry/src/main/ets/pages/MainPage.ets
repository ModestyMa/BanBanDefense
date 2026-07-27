// 主页面：底部 Tabs 容器（🏠首页 / 📅倒数日 / 🍅番茄 / 💰记账），首启隐私政策弹窗（SPEC_M5 4.5）
// 卡片 postCardAction 路由（SPEC_M5 决策 4）：home→0 / pomodoro→2 / quickAdd→3 / countdownAdd→编辑页
import { router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HomePage } from './home/HomePage';
import { CountdownListPage } from './countdown/CountdownListPage';
import { PomodoroTimerPage } from './pomodoro/PomodoroTimerPage';
import { AccountPage } from './account/AccountPage';
import { countdownVM } from '../viewmodel/CountdownViewModel';
import { accountVM } from '../viewmodel/AccountViewModel';
import { pomodoroVM } from '../viewmodel/PomodoroViewModel';
import { homeVM } from '../viewmodel/HomeViewModel';
import { pomodoroEngine } from '../service/PomodoroEngine';
import { CountdownRoutes } from '../common/constants/CountdownConstants';
import { AppContextHolder } from '../common/AppContextHolder';
import { ResponsiveContainer } from '../components/ResponsiveContainer';
import { BreakpointHelper } from '../common/utils/BreakpointHelper';

const DOMAIN: number = 0x1000;
const TAG: string = 'MainPage';
const PREFS_NAME: string = 'app_prefs';
const KEY_PRIVACY_AGREED: string = 'privacyAgreed';
const ROUTE_PRIVACY: string = 'pages/settings/PrivacyPolicyPage';

@Entry
@ComponentV2
struct MainPage {
  // 断点系统（SPEC_M6 §2）：AppStorage 窗口宽度，lg(>840) 左侧导航
  @Computed get winWidthVp(): number { return AppStorage.get<number>('winWidthVp') ?? 360; }
  @Local currentIndex: number = 0;
  private tabsController: TabsController = new TabsController();

  private isLg(): boolean {
    return this.winWidthVp > BreakpointHelper.LG_THRESHOLD;
  }
  private privacyDialog: CustomDialogController = new CustomDialogController({
    builder: PrivacyDialog({
      agree: () => {
        this.onPrivacyAgree();
      },
      view: () => {
        router.pushUrl({ url: ROUTE_PRIVACY });
      },
      exit: () => {
        this.exitApp();
      }
    }),
    autoCancel: false,
    customStyle: true,
    alignment: DialogAlignment.Center
  });

  aboutToAppear(): void {
    // 处理卡片 postCardAction 路由目标（SPEC_M3 第 3 节 / SPEC_M5 决策 4）
    const target = AppStorage.get<string>('launchTarget');
    if (target !== undefined && target.length > 0) {
      if (target === 'pomodoro') {
        this.currentIndex = 2;
      } else if (target === 'quickAdd') {
        // 卡片「记一笔」直达记账 Tab（SPEC_M4 §1-10）
        this.currentIndex = 3;
      } else if (target === 'countdownAdd') {
        router.pushUrl({ url: CountdownRoutes.EDIT });
      }
      // 'home'：默认首页（index 0）
      AppStorage.set('launchTarget', '');
    }
    this.checkPrivacy();
  }

  onPageShow(): void {
    // 从详情/编辑/统计/设置页返回时刷新数据与计时
    countdownVM.load().catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '倒数日刷新失败: %{public}s', err.message);
    });
    accountVM.load().catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '记账刷新失败: %{public}s', err.message);
    });
    pomodoroVM.load().catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '番茄刷新失败: %{public}s', err.message);
    });
    homeVM.load().catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '首页刷新失败: %{public}s', err.message);
    });
    pomodoroEngine.tick();
    // 从隐私政策页返回时若仍未同意，重新弹窗
    this.checkPrivacy();
  }

  /** 首启隐私弹窗：preferences 未同意则弹出（SPEC_M5 决策 11） */
  private checkPrivacy(): void {
    try {
      const context = AppContextHolder.get() ?? getContext(this);
      const prefs = preferences.getPreferencesSync(context, { name: PREFS_NAME });
      const agreed = prefs.getSync(KEY_PRIVACY_AGREED, false) as boolean;
      if (!agreed) {
        this.privacyDialog.open();
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, '隐私弹窗检查失败: %{public}s', JSON.stringify(err));
    }
  }

  private onPrivacyAgree(): void {
    try {
      const context = AppContextHolder.get() ?? getContext(this);
      const prefs = preferences.getPreferencesSync(context, { name: PREFS_NAME });
      prefs.putSync(KEY_PRIVACY_AGREED, true);
      prefs.flush();
    } catch (err) {
      hilog.error(DOMAIN, TAG, '隐私同意写入失败: %{public}s', JSON.stringify(err));
    }
    this.privacyDialog.close();
  }

  private exitApp(): void {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      context.terminateSelf();
    } catch (err) {
      hilog.error(DOMAIN, TAG, '退出应用失败: %{public}s', JSON.stringify(err));
    }
  }

  @Builder
  tabItem(icon: string, labelRes: Resource, selected: boolean) {
    if (this.isLg()) {
      // lg 断点：左侧纵向导航项（图标 + 文字横排，SPEC_M6 §4）
      Row({ space: 8 }) {
        Text(icon)
          .fontSize(18)
        Text(labelRes)
          .fontSize(13)
          .fontColor(selected ? $r('app.color.primary') : $r('app.color.text_hint'))
          .fontWeight(selected ? FontWeight.Medium : FontWeight.Normal)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 12, right: 12 })
    } else {
      Column({ space: 2 }) {
        Text(icon)
          .fontSize(20)
        Text(labelRes)
          .fontSize(11)
          .fontColor(selected ? $r('app.color.primary') : $r('app.color.text_hint'))
          .fontWeight(selected ? FontWeight.Medium : FontWeight.Normal)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
  }

  build() {
    Tabs({ barPosition: this.isLg() ? BarPosition.Start : BarPosition.End, index: this.currentIndex, controller: this.tabsController }) {
      TabContent() {
        ResponsiveContainer() {
          HomePage({ controller: this.tabsController })
        }
      }
      .tabBar(this.tabItem('🏠', $r('app.string.tab_home'), this.currentIndex === 0))

      TabContent() {
        ResponsiveContainer() {
          CountdownListPage()
        }
      }
      .tabBar(this.tabItem('📅', $r('app.string.tab_countdown'), this.currentIndex === 1))

      TabContent() {
        ResponsiveContainer() {
          PomodoroTimerPage()
        }
      }
      .tabBar(this.tabItem('🍅', $r('app.string.tab_pomodoro'), this.currentIndex === 2))

      TabContent() {
        ResponsiveContainer() {
          AccountPage()
        }
      }
      .tabBar(this.tabItem('💰', $r('app.string.tab_account'), this.currentIndex === 3))
    }
    .vertical(this.isLg())
    .barWidth(this.isLg() ? 140 : '100%')
    .barHeight(this.isLg() ? '100%' : 64)
    .barBackgroundColor($r('app.color.card_bg'))
    .animationDuration(200)
    .onChange((index: number) => {
      this.currentIndex = index;
    })
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}

/** 首启隐私政策弹窗（三按钮：暂不同意→退出 / 查看全文 / 同意并继续） */
@CustomDialog
struct PrivacyDialog {
  controller: CustomDialogController;
  agree: () => void = () => {};
  view: () => void = () => {};
  exit: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.settings_privacy'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text($r('app.string.privacy_dialog_msg'))
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .lineHeight(24)
        .width('100%')
      Row({ space: 10 }) {
        Button($r('app.string.privacy_disagree'))
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.ring_track'))
          .borderRadius(12)
          .height(38)
          .layoutWeight(1)
          .onClick(() => {
            this.exit();
          })
        Button($r('app.string.privacy_view'))
          .fontSize(13)
          .fontColor($r('app.color.primary'))
          .backgroundColor($r('app.color.today_bg'))
          .borderRadius(12)
          .height(38)
          .layoutWeight(1)
          .onClick(() => {
            this.controller.close();
            this.view();
          })
        Button($r('app.string.privacy_agree'))
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.primary'))
          .borderRadius(12)
          .height(38)
          .layoutWeight(1)
          .onClick(() => {
            this.agree();
          })
      }
      .width('100%')
    }
    .width('86%')
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(20)
  }
}
