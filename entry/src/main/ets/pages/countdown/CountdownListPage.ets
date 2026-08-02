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
        .fontSize($r('app.float.fontSize_28'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .padding({ left:$r('app.float.padding_left_20'), right:$r('app.float.padding_right_20'), top:$r('app.float.padding_top_8'), bottom:$r('app.float.padding_bottom_4') })
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
      .padding({ left:$r('app.float.padding_left_20'), right:$r('app.float.padding_right_20') })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .padding({ top:$r('app.float.padding_top_12'), bottom:$r('app.float.padding_bottom_12') })
  }

  @Builder
  emptyView() {
    Column({ space: 14 }) {
      Text($r('app.string.empty_pet_emoji'))
        .fontSize($r('app.float.fontSize_64'))
      Text(this.vm.events.length === 0 && this.vm.filterKey === 'all'
        ? $r('app.string.empty_all')
        : $r('app.string.empty_filtered'))
        .fontSize($r('app.float.fontSize_14'))
        .fontColor($r('app.color.text_hint'))
        .textAlign(TextAlign.Center)
        .lineHeight($r('app.float.lineHeight_24'))
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ bottom:$r('app.float.padding_bottom_60') })
  }

  @Builder
  deleteButton(eventId: number) {
    Row() {
      Text($r('app.string.action_delete'))
        .fontSize($r('app.float.fontSize_14'))
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
    }
    .width($r('app.float.width_80'))
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
        .width($r('app.float.width_10'))
        .height($r('app.float.height_10'))
        .fill(categoryMetaOf(ev.category).colorRes)
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(ev.title)
            .fontSize($r('app.float.fontSize_16'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (ev.isTop) {
            Text($r('app.string.badge_top'))
              .fontSize($r('app.float.fontSize_11'))
              .fontColor($r('app.color.primary'))
              .border({ width: 1, color: $r('app.color.primary'), radius:$r('app.float.border_radius_6') })
              .padding({ left:$r('app.float.padding_left_5'), right:$r('app.float.padding_right_5'), top: 1, bottom: 1 })
          }
        }
        Text(DateUtils.formatDate(ev.targetDate) + ' · ' +
          getContext(this).resourceManager.getStringSync(categoryMetaOf(ev.category).nameRes))
          .fontSize($r('app.float.fontSize_12'))
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
          .fontSize($r('app.float.fontSize_11'))
          .fontColor(this.dayColorRes(ev))
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding($r('app.float.padding_16'))
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.borderRadius_16'))
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

  /**
   * BUG-008：ForEach key 只用 id 时，编辑倒数日（改标题/日期/置顶/提醒）后 key 不变，
   * ArkUI 复用旧节点 → 列表不更新，需冷启动才见。把可变字段并入 key。
   */
  private static evKey(ev: CountdownEventData): string {
    return ev.id.toString() + ':' + ev.title + ':' + ev.targetDate.toString() + ':' + ev.category
      + ':' + (ev.isTop ? '1' : '0') + ':' + (ev.remindEnabled ? '1' : '0') + ':' + ev.note;
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
      }, (ev: CountdownEventData) => CountdownListPage.evKey(ev))
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left:$r('app.float.padding_left_16'), right:$r('app.float.padding_right_16'), bottom:$r('app.float.padding_bottom_90') })
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
        .width($r('app.float.width_58'))
        .height($r('app.float.height_58'))
        .fontSize($r('app.float.fontSize_30'))
        .fontColor(Color.White)
        .backgroundColor($r('app.color.primary'))
        .borderRadius($r('app.float.borderRadius_29'))
        .shadow({ radius: 18, color: '#73FF8A65', offsetY: 6 })
        .margin({ right:$r('app.float.margin_right_20'), bottom:$r('app.float.margin_bottom_28') })
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
  .fontSize($r('app.float.fontSize_13'))
  .fontWeight(selected ? FontWeight.Medium : FontWeight.Normal)
  .fontColor(selected ? Color.White : $r('app.color.text_secondary'))
  .backgroundColor(selected ? $r('app.color.primary') : $r('app.color.card_bg'))
  .borderRadius($r('app.float.borderRadius_20'))
  .border({ width:$r('app.float.border_width_1_5'), color: selected ? $r('app.color.primary') : $r('app.color.divider') })
  .padding({ left:$r('app.float.padding_left_16'), right:$r('app.float.padding_right_16'), top:$r('app.float.padding_top_7'), bottom:$r('app.float.padding_bottom_7') })
}
