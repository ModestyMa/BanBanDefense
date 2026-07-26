// 手表主页面（SPEC_M6 §4）：单栏垂直 Swiper 三屏滑动（概览 / 快记 / 倒数日），无 Tabs
import { WatchOverviewPage } from './WatchOverviewPage';
import { WatchQuickAddPage } from './WatchQuickAddPage';
import { WatchCountdownPage } from './WatchCountdownPage';

@Entry
@ComponentV2
struct WatchMainPage {
  build() {
    Swiper() {
      WatchOverviewPage()
      WatchQuickAddPage()
      WatchCountdownPage()
    }
    // 垂直滑动导航（SPEC_M6 §10-3 假设 API，编译验证）
    .vertical(true)
    .loop(false)
    .indicator(false)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
