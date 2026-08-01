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

  @Builder
  navBar() {
    Row() {
      Text('‹ ' + getContext(this).resourceManager.getStringSync($r('app.string.action_back')))
        .fontSize(15)
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          router.back();
        })
      Text($r('app.string.stats_title'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .margin({ right: 40 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 10 })
  }

  @Builder
  statCard(value: number, labelRes: Resource) {
    Column({ space: 4 }) {
      Text(value.toString())
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary'))
      Text(labelRes)
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
    }
    .layoutWeight(1)
    .padding({ top: 14, bottom: 14 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .shadow({ radius: 10, color: '#0D000000', offsetY: 2 })
  }

  @Builder
  chart() {
    // BUG-004 同根因防御：柱状图高度依赖 vm.weekDays（异步 load 后填充）。
    // 原由 private maxWeekValue()/barHeightPercent(idx) 经方法间接读 vm.@Trace，存在依赖未建立隐患；
    // 改为在 @Builder 内直接读取 vm.weekDays 计算，随 build 建立依赖，load 完成后自动重渲。
    const weekDays: number[] = this.vm.weekDays;
    let maxVal: number = 1;
    for (const v of weekDays) {
      if (v > maxVal) {
        maxVal = v;
      }
    }
    const names: string[] = this.weekDayNames();
    const todayIdx: number = this.vm.todayIndex;
    Column({ space: 14 }) {
      Text($r('app.string.stat_week_chart'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Row({ space: 10 }) {
        ForEach(weekDays, (v: number, idx: number) => {
          const pct: number = Math.max(3, Math.round(v / maxVal * 100));
          Column({ space: 6 }) {
            Text(v > 0 ? v.toString() : '')
              .fontSize(9)
              .fontColor($r('app.color.text_hint'))
            Column()
              .width('100%')
              .constraintSize({ maxWidth: 26 })
              .height(pct.toString() + '%')
              .borderRadius({ topLeft: 6, topRight: 6, bottomLeft: 2, bottomRight: 2 })
              .backgroundColor(idx === todayIdx ? $r('app.color.primary') : $r('app.color.today_border'))
            Text(names[idx])
              .fontSize(10)
              .fontColor($r('app.color.text_hint'))
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.End)
        }, (v: number, idx: number) => idx.toString())
      }
      .width('100%')
      .height(130)
      .alignItems(VerticalAlign.Bottom)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .margin({ left: 20, right: 20, bottom: 14 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .shadow({ radius: 10, color: '#0D000000', offsetY: 2 })
  }

  @Builder
  recordRow(s: PomodoroSessionData) {
    Row({ space: 10 }) {
      Text(s.tag)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary'))
        .backgroundColor($r('app.color.today_bg'))
        .borderRadius(10)
        .padding({ left: 10, right: 10, top: 3, bottom: 3 })
      Text(this.sessionTimeText(s))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .layoutWeight(1)
      Text(s.durationMin.toString() + ' ' +
        getContext(this).resourceManager.getStringSync($r('app.string.unit_minute')))
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
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
        .padding({ left: 20, right: 20, top: 8, bottom: 14 })

        this.chart()

        Text($r('app.string.stat_recent'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .padding({ left: 20, bottom: 10 })

        if (this.vm.recent.length === 0) {
          Column({ space: 12 }) {
            Text($r('app.string.stat_empty_emoji'))
              .fontSize(52)
            Text($r('app.string.stat_empty'))
              .fontSize(13)
              .fontColor($r('app.color.text_hint'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ bottom: 60 })
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
          .padding({ left: 20, right: 20, bottom: 20 })
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
