// 手表概览屏（SPEC_M6 决策 7-①）：宠物心情/等级/连续天数 + 今日支出/收入合计
import { hilog } from '@kit.PerformanceAnalysisKit';
import { NestedScrollMode } from '@kit.ArkUI';
import { watchVM } from '../viewmodel/WatchViewModel';
import { MoneyUtils } from '../common/utils/MoneyUtils';

const DOMAIN: number = 0x2000;
const TAG: string = 'WatchOverviewPage';

@ComponentV2
export struct WatchOverviewPage {
  private vm = watchVM;

  aboutToAppear(): void {
    this.vm.load().catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '手表概览加载失败: %{public}s', err.message);
    });
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        // 宠物状态卡
        Column({ space: 6 }) {
          Text(this.vm.petEmoji)
            .fontSize($r('app.float.fontSize_46'))
          Row({ space: 8 }) {
            Text('Lv.' + this.vm.petLevel.toString())
              .fontSize($r('app.float.fontSize_14'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.home_streak_fmt', this.vm.streakDays))
              .fontSize($r('app.float.fontSize_12'))
              .fontColor($r('app.color.text_secondary'))
          }
          Text(this.vm.activeToday ? $r('app.string.home_pet_active') : $r('app.string.home_pet_idle'))
            .fontSize($r('app.float.fontSize_12'))
            .fontColor(this.vm.activeToday ? $r('app.color.income_green') : $r('app.color.text_hint'))
        }
        .width('100%')
        .padding($r('app.float.padding_14'))
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.borderRadius_16'))

        // 今日收支
        Row({ space: 10 }) {
          Column({ space: 4 }) {
            Text($r('app.string.watch_today_expense'))
              .fontSize($r('app.float.fontSize_11'))
              .fontColor($r('app.color.text_hint'))
            Text('-' + MoneyUtils.formatAmount(this.vm.todayOutCents))
              .fontSize($r('app.float.fontSize_16'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.danger'))
          }
          .layoutWeight(1)
          .padding($r('app.float.padding_12'))
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius($r('app.float.borderRadius_14'))

          Column({ space: 4 }) {
            Text($r('app.string.watch_today_income'))
              .fontSize($r('app.float.fontSize_11'))
              .fontColor($r('app.color.text_hint'))
            Text('+' + MoneyUtils.formatAmount(this.vm.todayInCents))
              .fontSize($r('app.float.fontSize_16'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.income_green'))
          }
          .layoutWeight(1)
          .padding($r('app.float.padding_12'))
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius($r('app.float.borderRadius_14'))
        }
        .width('100%')
      }
      .width('100%')
      .padding($r('app.float.padding_12'))
    }
    .width('100%')
    .nestedScroll({
      scrollForward: NestedScrollMode.SELF_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
    .backgroundColor($r('app.color.page_bg'))
    .scrollBar(BarState.Off)
  }
}
