// 倒数日详情页（SPEC_M1 4.3）
import { router, promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { countdownVM } from '../../viewmodel/CountdownViewModel';
import { CountdownEventData } from '../../data/model/CountdownEvent';
import { CountdownRepository } from '../../data/repository/CountdownRepository';
import { DateUtils, DayInfo } from '../../common/utils/DateUtils';
import { CountdownRoutes, categoryMetaOf } from '../../common/constants/CountdownConstants';
import { ResponsiveContainer } from '../../components/ResponsiveContainer';

const DOMAIN: number = 0x1103;
const TAG: string = 'CountdownDetailPage';

@Entry
@ComponentV2
struct CountdownDetailPage {
  @Local eventId: number = 0;
  @Local ev: CountdownEventData | null = null;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, number>;
    if (params !== undefined && params !== null && params['id'] !== undefined) {
      this.eventId = params['id'];
    }
  }

  onPageShow(): void {
    if (this.eventId > 0) {
      this.reload();
    }
  }

  private reload(): void {
    CountdownRepository.findById(this.eventId)
      .then((ev: CountdownEventData | null) => {
        if (ev === null) {
          router.back();
          return;
        }
        this.ev = ev;
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, '加载详情失败: %{public}s', err.message);
      });
  }

  private bigLabel(): string {
    if (this.ev === null) {
      return '';
    }
    const info: DayInfo = DateUtils.dayInfo(this.ev.targetDate);
    const rm = getContext(this).resourceManager;
    if (info.kind === 'today') {
      return rm.getStringSync($r('app.string.day_today'));
    }
    if (info.kind === 'future') {
      return rm.getStringSync($r('app.string.day_future_fmt'), info.days);
    }
    return rm.getStringSync($r('app.string.day_past_fmt'), Math.abs(info.days));
  }

  private confirmDelete(): void {
    if (this.ev === null) {
      return;
    }
    const target = this.ev;
    const rm = getContext(this).resourceManager;
    AlertDialog.show({
      title: rm.getStringSync($r('app.string.delete_confirm_title'), target.title),
      message: $r('app.string.delete_confirm_msg'),
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: $r('app.string.action_cancel'),
        fontColor: $r('app.color.text_secondary'),
        action: () => {}
      },
      secondaryButton: {
        value: $r('app.string.action_delete'),
        fontColor: $r('app.color.danger'),
        action: () => {
          countdownVM.deleteEvent(target.id)
            .then(() => {
              promptAction.showToast({ message: $r('app.string.toast_deleted') });
              router.back();
            })
            .catch((err: Error) => {
              hilog.error(DOMAIN, TAG, '删除失败: %{public}s', err.message);
            });
        }
      }
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
      Text($r('app.string.action_detail'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text($r('app.string.action_edit'))
        .fontSize(15)
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          if (this.ev !== null) {
            router.pushUrl({
              url: CountdownRoutes.EDIT,
              params: { 'id': this.eventId }
            });
          }
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 12 })
  }

  @Builder
  hero() {
    Column({ space: 0 }) {
      Text(categoryMetaOf(this.ev === null ? 'life' : this.ev.category).nameRes)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor(categoryMetaOf(this.ev === null ? 'life' : this.ev.category).colorRes)
        .borderRadius(14)
        .padding({ left: 14, right: 14, top: 5, bottom: 5 })
        .margin({ bottom: 18 })

      Text(this.bigLabel())
        .fontSize(40)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary'))
        .textAlign(TextAlign.Center)

      Text(this.ev === null ? '' : this.ev.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 14 })

      Text(this.ev === null ? '' :
        getContext(this).resourceManager.getStringSync($r('app.string.target_date_prefix'),
          DateUtils.formatDate(this.ev.targetDate)))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 8 })

      Row({ space: 10 }) {
        Text(this.ev !== null && this.ev.isTop ? $r('app.string.flag_top_on') : $r('app.string.flag_top_off'))
          .fontSize(12)
          .fontColor($r('app.color.text_hint'))
        Text(this.ev !== null && this.ev.remindEnabled ? $r('app.string.flag_remind_on') : $r('app.string.flag_remind_off'))
          .fontSize(12)
          .fontColor($r('app.color.text_hint'))
      }
      .margin({ top: 16 })

      if (this.ev !== null && this.ev.note.length > 0) {
        Text(this.ev.note)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(14)
          .padding(14)
          .margin({ top: 22 })
          .shadow({ radius: 10, color: '#0D000000', offsetY: 2 })
      }
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding(20)
  }

  build() {
    ResponsiveContainer() {
      Column() {
        this.navBar()
        this.hero()
        Button($r('app.string.delete_this_event'))
          .width('90%')
          .height(46)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.danger'))
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(16)
          .margin({ bottom: 30 })
          .onClick(() => {
            this.confirmDelete();
          })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
