// 倒数日新建/编辑页（同一页面双模式，SPEC_M1 4.2）
import { router, promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { countdownVM } from '../../viewmodel/CountdownViewModel';
import { CountdownEventData, newCountdownEvent } from '../../data/model/CountdownEvent';
import { CountdownRepository } from '../../data/repository/CountdownRepository';
import { DateUtils } from '../../common/utils/DateUtils';
import { categoryMetaList, CategoryMeta } from '../../common/constants/CountdownConstants';
import { ResponsiveContainer } from '../../components/ResponsiveContainer';

const DOMAIN: number = 0x1102;
const TAG: string = 'CountdownEditPage';
const TITLE_MAX: number = 20;
const NOTE_MAX: number = 100;

@Entry
@ComponentV2
struct CountdownEditPage {
  @Local editId: number = 0;
  @Local title: string = '';
  @Local selectedDate: Date = new Date();
  @Local category: string = 'life';
  @Local isTop: boolean = false;
  @Local remindEnabled: boolean = true;
  @Local note: string = '';
  @Local loaded: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, number>;
    if (params !== undefined && params !== null && params['id'] !== undefined) {
      this.editId = params['id'];
      this.loadEvent(this.editId);
    } else {
      this.loaded = true;
    }
  }

  private loadEvent(id: number): void {
    CountdownRepository.findById(id)
      .then((ev: CountdownEventData | null) => {
        if (ev !== null) {
          this.title = ev.title;
          this.selectedDate = new Date(ev.targetDate);
          this.category = ev.category;
          this.isTop = ev.isTop;
          this.remindEnabled = ev.remindEnabled;
          this.note = ev.note;
        }
        this.loaded = true;
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, '加载事件失败: %{public}s', err.message);
        this.loaded = true;
      });
  }

  private openDatePicker(): void {
    DatePickerDialog.show({
      start: new Date(1970, 0, 1),
      end: new Date(2100, 11, 31),
      selected: this.selectedDate,
      onDateAccept: (value: Date) => {
        this.selectedDate = value;
      }
    });
  }

  private onSave(): void {
    const d = this.selectedDate;
    const ev: CountdownEventData = newCountdownEvent();
    ev.id = this.editId;
    ev.title = this.title.trim();
    ev.targetDate = DateUtils.dayStartOf(d.getFullYear(), d.getMonth() + 1, d.getDate());
    ev.category = this.category;
    ev.isTop = this.isTop;
    ev.remindEnabled = this.remindEnabled;
    ev.note = this.note;
    countdownVM.saveEvent(ev, this.editId === 0)
      .then(() => {
        promptAction.showToast({
          message: this.editId === 0 ? $r('app.string.toast_added') : $r('app.string.toast_saved')
        });
        router.back();
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, '保存失败: %{public}s', err.message);
        promptAction.showToast({ message: $r('app.string.toast_save_failed') });
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
      Text(this.editId === 0 ? $r('app.string.action_add_event') : $r('app.string.action_edit_event'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .margin({ right: 40 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 12 })
  }

  @Builder
  fieldCard() {
    Column() {
        // 标题
      Column({ space: 10 }) {
        Row() {
          Text($r('app.string.field_title'))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
          Blank()
          Text(this.title.length.toString() + '/' + TITLE_MAX.toString())
            .fontSize(12)
            .fontColor($r('app.color.text_hint'))
        }
        .width('100%')
        TextInput({ placeholder: $r('app.string.hint_title'), text: this.title })
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_hint'))
          .backgroundColor(Color.Transparent)
          .maxLength(TITLE_MAX)
          .padding(0)
          .onChange((value: string) => {
            this.title = value;
          })
      }
      .cardStyle()

      // 目标日期
      Column({ space: 10 }) {
        Text($r('app.string.field_target_date'))
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
        Text(DateUtils.formatDate(DateUtils.dayStartOf(
          this.selectedDate.getFullYear(), this.selectedDate.getMonth() + 1, this.selectedDate.getDate())))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .onClick(() => {
            this.openDatePicker();
          })
      }
      .alignItems(HorizontalAlign.Start)
      .cardStyle()

      // 分类
      Column({ space: 10 }) {
        Text($r('app.string.field_category'))
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(categoryMetaList(), (meta: CategoryMeta) => {
            Row({ space: 6 }) {
              Circle()
                .width(8)
                .height(8)
                .fill(meta.colorRes)
              Text(meta.nameRes)
                .fontSize(13)
                .fontColor(this.category === meta.key ? $r('app.color.primary') : $r('app.color.text_secondary'))
            }
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .borderRadius(12)
            .border({
              width: 1.5,
              color: this.category === meta.key ? $r('app.color.primary') : $r('app.color.divider')
            })
            .backgroundColor(this.category === meta.key ? $r('app.color.today_bg') : $r('app.color.card_bg'))
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.category = meta.key;
            })
          }, (meta: CategoryMeta) => meta.key)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .cardStyle()

      // 置顶
      Row() {
        Column({ space: 2 }) {
          Text($r('app.string.field_top'))
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.field_top_sub'))
            .fontSize(12)
            .fontColor($r('app.color.text_hint'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.isTop })
          .selectedColor($r('app.color.primary'))
          .onChange((isOn: boolean) => {
            this.isTop = isOn;
          })
      }
      .cardStyle()

      // 提醒
      Row() {
        Column({ space: 2 }) {
          Text($r('app.string.field_remind'))
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.field_remind_sub'))
            .fontSize(12)
            .fontColor($r('app.color.text_hint'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.remindEnabled })
          .selectedColor($r('app.color.primary'))
          .onChange((isOn: boolean) => {
            this.remindEnabled = isOn;
          })
      }
      .cardStyle()

      // 备注
      Column({ space: 10 }) {
        Row() {
          Text($r('app.string.field_note'))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
          Blank()
          Text(this.note.length.toString() + '/' + NOTE_MAX.toString())
            .fontSize(12)
            .fontColor($r('app.color.text_hint'))
        }
        .width('100%')
        TextArea({ placeholder: $r('app.string.hint_note'), text: this.note })
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_hint'))
          .backgroundColor(Color.Transparent)
          .maxLength(NOTE_MAX)
          .height(64)
          .padding(0)
          .onChange((value: string) => {
            this.note = value;
          })
      }
      .cardStyle()
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 8 })
  }

  build() {
    Column() {
      ResponsiveContainer({ bgColor: $r('app.color.page_bg') }) {
      Column() {
        this.navBar()
        Scroll() {
          this.fieldCard()
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        Button($r('app.string.action_save'))
          .width('90%')
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.primary'))
          .borderRadius(16)
          .opacity(this.title.trim().length === 0 ? 0.35 : 1)
          .enabled(this.title.trim().length > 0)
          .margin({ bottom: 26 })
          .onClick(() => {
            this.onSave();
          })
      }
      .width('100%')
      .height('100%')
    }
    }
    .width('100%')
    .height('100%')
  }
}

@Styles
function cardStyle() {
  .width('100%')
  .padding(16)
  .margin({ bottom: 14 })
  .backgroundColor($r('app.color.card_bg'))
  .borderRadius(16)
  .shadow({ radius: 10, color: '#0D000000', offsetY: 2 })
}
