// 倒数日列表页（MVP 默认首页，SPEC_M1 4.1）
import { router, promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { countdownVM } from '../../viewmodel/CountdownViewModel';
import { CountdownEventData } from '../../data/model/CountdownEvent';
import { DateUtils, DayInfo } from '../../common/utils/DateUtils';
import { CountdownRoutes, categoryMetaList, categoryMetaOf, CategoryMeta } from '../../common/constants/CountdownConstants';

const DOMAIN: number = 0x1101;
const TAG: string = 'CountdownListPage';

@ComponentV2
export struct CountdownListPage {
  private vm = countdownVM;

  aboutToAppear(): void {
    this.vm.load().catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '加载列表失败: %{public}s', err.message);
    });
  }

  private dayTexts(ev: CountdownEventData): string[] {
    const info: DayInfo = DateUtils.dayInfo(ev.targetDate);
    const rm = getContext(this).resourceManager;
    if (info.kind === 'today') {
      return [rm.getStringSync($r('app.string.day_today_short')), rm.getStringSync($r('app.string.day_today'))];
    }
    if (info.kind === 'future') {
      return [info.days.toString(), rm.getStringSync($r('app.string.day_unit_after'))];
    }
    return [Math.abs(info.days).toString(), rm.getStringSync($r('app.string.day_unit_before'))];
  }

  private dayColorRes(ev: CountdownEventData): Resource {
    const info: DayInfo = DateUtils.dayInfo(ev.targetDate);
    if (info.kind === 'today') {
      return $r('app.color.today_accent');
    }
    if (info.kind === 'future') {
      return $r('app.color.primary');
    }
    return $r('app.color.text_hint');
  }

  private confirmDelete(ev: CountdownEventData): void {
    const rm = getContext(this).resourceManager;
    AlertDialog.show({
      title: rm.getStringSync($r('app.string.delete_confirm_title'), ev.title),
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
          this.vm.deleteEvent(ev.id)
            .then(() => {
              promptAction.showToast({ message: $r('app.string.toast_deleted') });
            })
            .catch((err: Error) => {
              hilog.error(DOMAIN, TAG, '删除失败: %{public}s', err.message);
            });
        }
      }
    });
  }

  @Builder
  headerBar() {
    Row() {
      Text($r('app.string.countdown_home_title'))
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 4 })
  }

  @Builder
  chipsRow() {
    Scroll() {
      Row({ space: 8 }) {
        Text($r('app.string.cat_all'))
          .chipStyle(this.vm.filterKey === 'all')
          .onClick(() => {
            this.vm.setFilter('all');
            this.vm.load();
          })
        ForEach(categoryMetaList(), (meta: CategoryMeta) => {
          Text(meta.nameRes)
            .chipStyle(this.vm.filterKey === meta.key)
            .onClick(() => {
              this.vm.setFilter(meta.key);
              this.vm.load();
            })
        }, (meta: CategoryMeta) => meta.key)
      }
      .padding({ left: 20, right: 20 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }

  @Builder
  emptyView() {
    Column({ space: 14 }) {
      Text($r('app.string.empty_pet_emoji'))
        .fontSize(64)
      Text(this.vm.events.length === 0 && this.vm.filterKey === 'all'
        ? $r('app.string.empty_all')
        : $r('app.string.empty_filtered'))
        .fontSize(14)
        .fontColor($r('app.color.text_hint'))
        .textAlign(TextAlign.Center)
        .lineHeight(24)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ bottom: 60 })
  }

  @Builder
  deleteButton(eventId: number) {
    Row() {
      Text($r('app.string.action_delete'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
    }
    .width(80)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.danger'))
    .onClick(() => {
      const found = this.vm.events.find((ev: CountdownEventData) => ev.id === eventId);
      if (found !== undefined) {
        this.confirmDelete(found);
      }
    })
  }

  @Builder
  eventRow(ev: CountdownEventData) {
    Row({ space: 12 }) {
      Circle()
        .width(10)
        .height(10)
        .fill(categoryMetaOf(ev.category).colorRes)
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(ev.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (ev.isTop) {
            Text($r('app.string.badge_top'))
              .fontSize(11)
              .fontColor($r('app.color.primary'))
              .border({ width: 1, color: $r('app.color.primary'), radius: 6 })
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
          }
        }
        Text(DateUtils.formatDate(ev.targetDate) + ' · ' +
          getContext(this).resourceManager.getStringSync(categoryMetaOf(ev.category).nameRes))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Column({ space: 2 }) {
        Text(this.dayTexts(ev)[0])
          .fontSize(this.dayTexts(ev)[0].length > 3 ? 18 : 24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.dayColorRes(ev))
        Text(this.dayTexts(ev)[1])
          .fontSize(11)
          .fontColor(this.dayColorRes(ev))
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .shadow({ radius: 10, color: '#0D000000', offsetY: 2 })
    .border(DateUtils.dayInfo(ev.targetDate).kind === 'today'
      ? { width: 1.5, color: $r('app.color.today_border') }
      : { width: 0, color: Color.Transparent })
    .onClick(() => {
      router.pushUrl({
        url: CountdownRoutes.DETAIL,
        params: { 'id': ev.id }
      });
    })
  }

  @Builder
  eventList() {
    List({ space: 12 }) {
      ForEach(this.vm.events, (ev: CountdownEventData) => {
        ListItem() {
          this.eventRow(ev)
        }
        .swipeAction({
          end: {
            builder: () => {
              this.deleteButton(ev.id);
            }
          }
        })
      }, (ev: CountdownEventData) => ev.id.toString())
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16, bottom: 90 })
    .scrollBar(BarState.Off)
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        this.headerBar()
        this.chipsRow()
        if (this.vm.events.length === 0) {
          this.emptyView()
        } else {
          this.eventList()
        }
      }
      .width('100%')
      .height('100%')

      Button('+')
        .width(58)
        .height(58)
        .fontSize(30)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.primary'))
        .borderRadius(29)
        .shadow({ radius: 18, color: '#73FF8A65', offsetY: 6 })
        .margin({ right: 20, bottom: 28 })
        .onClick(() => {
          router.pushUrl({ url: CountdownRoutes.EDIT });
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}

@Extend(Text)
function chipStyle(selected: boolean) {
  .fontSize(13)
  .fontWeight(selected ? FontWeight.Medium : FontWeight.Normal)
  .fontColor(selected ? Color.White : $r('app.color.text_secondary'))
  .backgroundColor(selected ? $r('app.color.primary') : $r('app.color.card_bg'))
  .borderRadius(20)
  .border({ width: 1.5, color: selected ? $r('app.color.primary') : $r('app.color.divider') })
  .padding({ left: 16, right: 16, top: 7, bottom: 7 })
}
