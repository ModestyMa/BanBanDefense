// 主页面：底部 Tabs 容器（Tab1 倒数日 / Tab2 番茄），MVP 默认首页（SPEC_M2 第 2 节）
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CountdownListPage } from './countdown/CountdownListPage';
import { PomodoroTimerPage } from './pomodoro/PomodoroTimerPage';
import { AccountPage } from './account/AccountPage';
import { countdownVM } from '../viewmodel/CountdownViewModel';
import { accountVM } from '../viewmodel/AccountViewModel';
import { pomodoroEngine } from '../service/PomodoroEngine';
import { CountdownRoutes } from '../common/constants/CountdownConstants';

const DOMAIN: number = 0x1000;
const TAG: string = 'MainPage';

@Entry
@ComponentV2
struct MainPage {
  @Local currentIndex: number = 0;

  aboutToAppear(): void {
    // 处理卡片 postCardAction 路由目标（SPEC_M3 第 3 节）
    const target = AppStorage.get<string>('launchTarget');
    if (target !== undefined && target.length > 0) {
      if (target === 'pomodoro') {
        this.currentIndex = 1;
      } else if (target === 'quickAdd') {
        // W4 落地：卡片「记一笔」直达记账 Tab（SPEC_M4 §1-10）
        this.currentIndex = 2;
      } else if (target === 'countdownAdd') {
        router.pushUrl({ url: CountdownRoutes.EDIT });
      }
      // 'home'：默认首页
      AppStorage.set('launchTarget', '');
    }
  }

  onPageShow(): void {
    // 从详情/编辑/统计页返回时刷新数据与计时
    countdownVM.load().catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '倒数日刷新失败: %{public}s', err.message);
    });
    accountVM.load().catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '记账刷新失败: %{public}s', err.message);
    });
    pomodoroEngine.tick();
  }

  @Builder
  tabItem(icon: string, labelRes: Resource, selected: boolean) {
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

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        CountdownListPage()
      }
      .tabBar(this.tabItem('📅', $r('app.string.tab_countdown'), this.currentIndex === 0))

      TabContent() {
        PomodoroTimerPage()
      }
      .tabBar(this.tabItem('🍅', $r('app.string.tab_pomodoro'), this.currentIndex === 1))

      TabContent() {
        AccountPage()
      }
      .tabBar(this.tabItem('💰', $r('app.string.tab_account'), this.currentIndex === 2))
    }
    .barHeight(64)
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
