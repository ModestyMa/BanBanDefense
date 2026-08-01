// 番茄统计页（SPEC_M2 4.2：三张数字卡 + 本周柱状图 + 最近 20 条记录）
// 实现说明：柱状图用 ArkUI 组件实现（视觉效果等同 Canvas 自绘，偏差已记入 SPEC_M2）
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { pomodoroVM } from '../../viewmodel/PomodoroViewModel';
import { PomodoroSessionData } from '../../data/model/PomodoroSession';
import { ResponsiveContainer } from '../../components/ResponsiveContainer';

const DOMAIN: number = 0x1201;
const TAG: string = 'PomodoroStatsPage';

@Entry
@ComponentV2
struct PomodoroStatsPage {
  private vm = pomodoroVM;

  onPageShow(): void {
    this.vm.load().catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '统计加载失败: %{public}s', err.message);
    });
  }

  private weekDayNames(): string[] {
    const rm = getContext(this).resourceManager;
    const names: string[] = [
      rm.getStringSync($r('app.string.wd_1')),
      rm.getStringSync($r('app.string.wd_2')),
      rm.getStringSync($r('app.string.wd_3')),
      rm.getStringSync($r('app.string.wd_4')),
      rm.getStringSync($r('app.string.wd_5')),
      rm.getStringSync($r('app.string.wd_6')),
      rm.getStringSync($r('app.string.wd_7'))
    ];
    return names;
  }

  private pad(n: number): string {
    return n < 10 ? '0' + n : n.toString();
  }

  private sessionTimeText(s: PomodoroSessionData): string {
    const d1 = new Date(s.startTime);
    const d2 = new Date(s.endTime);
    return (d1.getMonth() + 1).toString() + '/' + d1.getDate().toString() + ' ' +
      this.pad(d1.getHours()) + ':' + this.pad(d1.getMinutes()) + ' - ' +
      this.pad(d2.getHours()) + ':' + this.pad(d2.getMinutes());
  }

  private maxWeekValue(): number {
    let maxVal: number = 1;
    for (const v of this.vm.weekDays) {
      if (v > maxVal) {
        maxVal = v;
      }
    }
    return maxVal;
  }

  @Builder
  navBar() {
    Row() {
      Text('‹ ' + getContext(this).resourceManager.getStringSync($r('app.string.action_back')))
        .fontSize($r('app.float.fontSize_15'))
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          router.back();
        })
      Text($r('app.string.stats_title'))
        .fontSize($r('app.float.fontSize_17'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .margin({ right:$r('app.float.margin_right_40') })
    }
    .width('100%')
    .padding({ left:$r('app.float.padding_left_16'), right:$r('app.float.padding_right_16'), top:$r('app.float.padding_top_6'), bottom:$r('app.float.padding_bottom_10') })
  }

  @Builder
  statCard(value: number, labelRes: Resource) {
    Column({ space: 4 }) {
      Text(value.toString())
        .fontSize($r('app.float.fontSize_22'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary'))
      Text(labelRes)
        .fontSize($r('app.float.fontSize_11'))
        .fontColor($r('app.color.text_secondary'))
    }
    .layoutWeight(1)
    .padding({ top:$r('app.float.padding_top_14'), bottom:$r('app.float.padding_bottom_14') })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.borderRadius_16'))
    .shadow({ radius: 10, color: '#0D000000', offsetY: 2 })
  }

  @Builder
  chart() {
    Column({ space: 14 }) {
      Text($r('app.string.stat_week_chart'))
        .fontSize($r('app.float.fontSize_14'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Row({ space: 10 }) {
        ForEach(this.vm.weekDays, (v: number, idx: number) => {
          Column({ space: 6 }) {
            Text(v > 0 ? v.toString() : '')
              .fontSize($r('app.float.fontSize_9'))
              .fontColor($r('app.color.text_hint'))
            Column()
              .width('100%')
              .constraintSize({ maxWidth:$r('app.float.constraintSize_maxWidth_26') })
              .height(Math.max(3, Math.round(v / this.maxWeekValue() * 100)).toString() + '%')
              .borderRadius({ topLeft: 6, topRight: 6, bottomLeft: 2, bottomRight: 2 })
              .backgroundColor(idx === this.vm.todayIndex ? $r('app.color.primary') : $r('app.color.today_border'))
            Text(this.weekDayNames()[idx])
              .fontSize($r('app.float.fontSize_10'))
              .fontColor($r('app.color.text_hint'))
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.End)
        }, (v: number, idx: number) => idx.toString())
      }
      .width('100%')
      .height($r('app.float.height_130'))
      .alignItems(VerticalAlign.Bottom)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding($r('app.float.padding_16'))
    .margin({ left:$r('app.float.margin_left_20'), right:$r('app.float.margin_right_20'), bottom:$r('app.float.margin_bottom_14') })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.borderRadius_16'))
    .shadow({ radius: 10, color: '#0D000000', offsetY: 2 })
  }

  @Builder
  recordRow(s: PomodoroSessionData) {
    Row({ space: 10 }) {
      Text(s.tag)
        .fontSize($r('app.float.fontSize_11'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary'))
        .backgroundColor($r('app.color.today_bg'))
        .borderRadius($r('app.float.borderRadius_10'))
        .padding({ left:$r('app.float.padding_left_10'), right:$r('app.float.padding_right_10'), top:$r('app.float.padding_top_3'), bottom:$r('app.float.padding_bottom_3') })
      Text(this.sessionTimeText(s))
        .fontSize($r('app.float.fontSize_13'))
        .fontColor($r('app.color.text_secondary'))
        .layoutWeight(1)
      Text(s.durationMin.toString() + ' ' +
        getContext(this).resourceManager.getStringSync($r('app.string.unit_minute')))
        .fontSize($r('app.float.fontSize_14'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .padding({ left:$r('app.float.padding_left_14'), right:$r('app.float.padding_right_14'), top:$r('app.float.padding_top_12'), bottom:$r('app.float.padding_bottom_12') })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.borderRadius_14'))
    .shadow({ radius: 8, color: '#0A000000', offsetY: 2 })
  }

  build() {
    Column() {
      ResponsiveContainer({ bgColor: $r('app.color.page_bg') }) {
      Column() {
        this.navBar()
        Row({ space: 10 }) {
          this.statCard(this.vm.todayMinutes, $r('app.string.stat_today'))
          this.statCard(this.vm.weekMinutes, $r('app.string.stat_week'))
          this.statCard(this.vm.totalCount, $r('app.string.stat_total'))
        }
        .width('100%')
        .padding({ left:$r('app.float.padding_left_20'), right:$r('app.float.padding_right_20'), top:$r('app.float.padding_top_8'), bottom:$r('app.float.padding_bottom_14') })

        this.chart()

        Text($r('app.string.stat_recent'))
          .fontSize($r('app.float.fontSize_14'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .padding({ left:$r('app.float.padding_left_20'), bottom:$r('app.float.padding_bottom_10') })

        if (this.vm.recent.length === 0) {
          Column({ space: 12 }) {
            Text($r('app.string.stat_empty_emoji'))
              .fontSize($r('app.float.fontSize_52'))
            Text($r('app.string.stat_empty'))
              .fontSize($r('app.float.fontSize_13'))
              .fontColor($r('app.color.text_hint'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ bottom:$r('app.float.padding_bottom_60') })
        } else {
          List({ space: 8 }) {
            ForEach(this.vm.recent, (s: PomodoroSessionData) => {
              ListItem() {
                this.recordRow(s)
              }
            }, (s: PomodoroSessionData) => s.id.toString())
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left:$r('app.float.padding_left_20'), right:$r('app.float.padding_right_20'), bottom:$r('app.float.padding_bottom_20') })
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
    }
    }
    .width('100%')
    .height('100%')
  }
}
