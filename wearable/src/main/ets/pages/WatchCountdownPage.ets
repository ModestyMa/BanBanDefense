// 手表倒数日屏（SPEC_M6 决策 7-③）：标题 + 天数列表（只读；新建/编辑在手机端）
import { hilog } from '@kit.PerformanceAnalysisKit';
import { watchVM } from '../viewmodel/WatchViewModel';
import { CountdownEventData } from '../data/model/CountdownEvent';
import { DateUtils, DayInfo } from '../common/utils/DateUtils';

const DOMAIN: number = 0x2002;
const TAG: string = 'WatchCountdownPage';

@ComponentV2
export struct WatchCountdownPage {
  private vm = watchVM;

  aboutToAppear(): void {
    this.vm.load().catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '手表倒数日加载失败: %{public}s', err.message);
    });
  }

  private dayLabel(targetDate: number): string {
    const info: DayInfo = DateUtils.dayInfo(targetDate);
    const rm = getContext(this).resourceManager;
    if (info.kind === 'today') {
      return rm.getStringSync($r('app.string.day_today'));
    }
    if (info.kind === 'future') {
      return rm.getStringSync($r('app.string.day_future_fmt'), info.days);
    }
    return rm.getStringSync($r('app.string.day_past_fmt'), Math.abs(info.days));
  }

  @Builder
  eventRow(ev: CountdownEventData) {
    Row({ space: 8 }) {
      Text(ev.isTop ? '📌 ' + ev.title : ev.title)
        .fontSize($r('app.float.fontSize_14'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.dayLabel(ev.targetDate))
        .fontSize($r('app.float.fontSize_12'))
        .fontColor($r('app.color.primary'))
    }
    .width('100%')
    .padding($r('app.float.padding_12'))
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.borderRadius_14'))
  }

  build() {
    Column({ space: 10 }) {
      Text($r('app.string.watch_countdown_title'))
        .fontSize($r('app.float.fontSize_16'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      if (this.vm.countdowns.length === 0) {
        Column({ space: 10 }) {
          Text('🐣')
            .fontSize($r('app.float.fontSize_40'))
          Text($r('app.string.watch_countdown_empty'))
            .fontSize($r('app.float.fontSize_12'))
            .fontColor($r('app.color.text_hint'))
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.vm.countdowns, (ev: CountdownEventData) => {
            ListItem() {
              this.eventRow(ev)
            }
          }, (ev: CountdownEventData) => ev.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.PARENT_FIRST
        })
      }
    }
    .width('100%')
    .padding($r('app.float.padding_12'))
    .backgroundColor($r('app.color.page_bg'))
  }
}
