// 番茄计时页（Tabs 内嵌组件，SPEC_M2 4.1 三态：IDLE/FOCUSING/RESTING）
import { router, promptAction } from '@kit.ArkUI';
import { pomodoroEngine, PomodoroState } from '../../service/PomodoroEngine';
import {
  PomodoroRoutes, DURATION_PRESETS, DURATION_MIN, DURATION_MAX, DURATION_STEP,
  BASE_TAGS, CUSTOM_TAG_MAX, REST_MIN
} from '../../common/constants/PomodoroConstants';

@ComponentV2
export struct PomodoroTimerPage {
  private engine = pomodoroEngine;
  @Local customTag: string = '';

  private tagDialog: CustomDialogController = new CustomDialogController({
    builder: CustomTagDialog({
      onConfirm: (tag: string) => {
        this.customTag = tag;
        this.engine.tag = tag;
      }
    }),
    customStyle: true
  });

  private mmss(): string {
    const sec = this.engine.remainSec;
    const m = Math.floor(sec / 60);
    const s = sec % 60;
    const mm = m < 10 ? '0' + m : m.toString();
    const ss = s < 10 ? '0' + s : s.toString();
    return mm + ':' + ss;
  }

  private petEmoji(): string {
    if (this.engine.state === PomodoroState.IDLE) {
      return '😴';
    }
    if (this.engine.state === PomodoroState.RESTING) {
      return '☕';
    }
    const total = this.engine.durationMin * 60;
    const ratio = total > 0 ? this.engine.remainSec / total : 1;
    if (ratio > 0.5) {
      return '💪';
    }
    if (ratio > 0.1) {
      return '🔥';
    }
    return '🎉';
  }

  private hintText(): Resource {
    if (this.engine.state === PomodoroState.FOCUSING) {
      return $r('app.string.hint_focusing');
    }
    if (this.engine.state === PomodoroState.RESTING) {
      return $r('app.string.hint_resting');
    }
    return $r('app.string.hint_ready');
  }

  private ringTotal(): number {
    return this.engine.state === PomodoroState.RESTING ? REST_MIN * 60 : this.engine.durationMin * 60;
  }

  private ringColor(): Resource {
    return this.engine.state === PomodoroState.RESTING ? $r('app.color.rest_green') : $r('app.color.primary');
  }

  private allTags(): string[] {
    const tags: string[] = [];
    for (const t of BASE_TAGS) {
      tags.push(t);
    }
    tags.push(this.customTag.length > 0 ? this.customTag : '');
    return tags;
  }

  private isCustomTag(tag: string): boolean {
    return BASE_TAGS.indexOf(tag) < 0;
  }

  private askGiveUp(): void {
    AlertDialog.show({
      title: $r('app.string.giveup_title'),
      message: $r('app.string.giveup_msg'),
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: $r('app.string.giveup_stay'),
        fontColor: $r('app.color.text_secondary'),
        action: () => {}
      },
      secondaryButton: {
        value: $r('app.string.btn_giveup'),
        fontColor: $r('app.color.danger'),
        action: () => {
          this.engine.giveUp();
          promptAction.showToast({ message: $r('app.string.toast_given_up') });
        }
      }
    });
  }

  @Builder
  navBar() {
    Row() {
      Text('')
        .width($r('app.float.width_30'))
      Text($r('app.string.pomodoro_title'))
        .fontSize($r('app.float.fontSize_17'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('📊')
        .fontSize($r('app.float.fontSize_20'))
        .width($r('app.float.width_30'))
        .textAlign(TextAlign.End)
        .onClick(() => {
          router.pushUrl({ url: PomodoroRoutes.STATS });
        })
    }
    .width('100%')
    .padding({ left:$r('app.float.padding_left_16'), right:$r('app.float.padding_right_16'), top:$r('app.float.padding_top_6'), bottom:$r('app.float.padding_bottom_10') })
  }

  @Builder
  ring() {
    Stack() {
      Progress({
        value: this.engine.remainSec,
        total: this.ringTotal(),
        type: ProgressType.Ring
      })
        .color(this.ringColor())
        .backgroundColor($r('app.color.ring_track'))
        .style({ strokeWidth: 14 })
        .width($r('app.float.width_260'))
        .height($r('app.float.height_260'))
      Column({ space: 4 }) {
        Text(this.petEmoji())
          .fontSize($r('app.float.fontSize_44'))
        Text(this.engine.state === PomodoroState.IDLE
          ? (this.engine.durationMin < 10 ? '0' + this.engine.durationMin : this.engine.durationMin.toString()) + ':00'
          : this.mmss())
          .fontSize($r('app.float.fontSize_44'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(this.hintText())
          .fontSize($r('app.float.fontSize_14'))
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width($r('app.float.width_260'))
    .height($r('app.float.height_260'))
    .margin({ top:$r('app.float.margin_top_18'), bottom:$r('app.float.margin_bottom_8') })
  }

  @Builder
  idleConfig() {
    Column() {
      // 时长
      Column({ space: 10 }) {
        Text($r('app.string.label_duration'))
          .fontSize($r('app.float.fontSize_13'))
          .fontColor($r('app.color.text_secondary'))
        Row({ space: 8 }) {
          ForEach(DURATION_PRESETS, (m: number) => {
            Text(m.toString())
              .fontSize($r('app.float.fontSize_14'))
              .fontWeight(this.engine.durationMin === m ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.engine.durationMin === m ? $r('app.color.primary') : $r('app.color.text_secondary'))
              .backgroundColor(this.engine.durationMin === m ? $r('app.color.today_bg') : $r('app.color.card_bg'))
              .borderRadius($r('app.float.borderRadius_12'))
              .border({
                width: 1.5,
                color: this.engine.durationMin === m ? $r('app.color.primary') : $r('app.color.divider')
              })
              .padding({ left: 0, right: 0, top:$r('app.float.padding_top_9'), bottom:$r('app.float.padding_bottom_9') })
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .onClick(() => {
                this.engine.durationMin = m;
                this.engine.remainSec = m * 60;
              })
          }, (m: number) => m.toString())
        }
        .width('100%')
        Row({ space: 12 }) {
          Slider({
            value: this.engine.durationMin,
            min: DURATION_MIN,
            max: DURATION_MAX,
            step: DURATION_STEP
          })
            .blockColor($r('app.color.primary'))
            .trackColor($r('app.color.ring_track'))
            .selectedColor($r('app.color.primary'))
            .layoutWeight(1)
            .onChange((value: number) => {
              this.engine.durationMin = Math.round(value);
              this.engine.remainSec = Math.round(value) * 60;
            })
          Text(this.engine.durationMin.toString() + ' ' +
            getContext(this).resourceManager.getStringSync($r('app.string.unit_minute')))
            .fontSize($r('app.float.fontSize_15'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary'))
            .width($r('app.float.width_62'))
            .textAlign(TextAlign.End)
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left:$r('app.float.padding_left_24'), right:$r('app.float.padding_right_24'), top:$r('app.float.padding_top_10'), bottom:$r('app.float.padding_bottom_10') })

      // 标签
      Column({ space: 10 }) {
        Text($r('app.string.label_tag'))
          .fontSize($r('app.float.fontSize_13'))
          .fontColor($r('app.color.text_secondary'))
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.allTags(), (tag: string) => {
            Text(tag.length === 0 ? $r('app.string.tag_custom') : tag)
              .fontSize($r('app.float.fontSize_13'))
              .fontColor(this.engine.tag === tag && tag.length > 0 ? $r('app.color.primary') : $r('app.color.text_secondary'))
              .backgroundColor(this.engine.tag === tag && tag.length > 0 ? $r('app.color.today_bg') : $r('app.color.card_bg'))
              .borderRadius($r('app.float.borderRadius_12'))
              .border({
                width: 1.5,
                color: this.engine.tag === tag && tag.length > 0 ? $r('app.color.primary') : $r('app.color.divider')
              })
              .padding({ left:$r('app.float.padding_left_14'), right:$r('app.float.padding_right_14'), top:$r('app.float.padding_top_8'), bottom:$r('app.float.padding_bottom_8') })
              .margin({ right:$r('app.float.margin_right_8'), bottom:$r('app.float.margin_bottom_8') })
              .onClick(() => {
                if (tag.length === 0 || this.isCustomTag(tag)) {
                  this.tagDialog.open();
                } else {
                  this.engine.tag = tag;
                }
              })
          }, (tag: string, index: number) => index.toString() + tag)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left:$r('app.float.padding_left_24'), right:$r('app.float.padding_right_24'), top:$r('app.float.padding_top_10'), bottom:$r('app.float.padding_bottom_10') })
    }
    .width('100%')
  }

  build() {
    Column() {
      this.navBar()
      Scroll() {
        Column() {
          this.ring()
          if (this.engine.state === PomodoroState.IDLE) {
            this.idleConfig()
          } else if (this.engine.state === PomodoroState.FOCUSING) {
            Text(this.engine.tag + ' · ' + this.engine.durationMin.toString() + ' ' +
              getContext(this).resourceManager.getStringSync($r('app.string.unit_minute')))
              .fontSize($r('app.float.fontSize_12'))
              .fontColor($r('app.color.primary'))
              .backgroundColor($r('app.color.today_bg'))
              .borderRadius($r('app.float.borderRadius_12'))
              .padding({ left:$r('app.float.padding_left_14'), right:$r('app.float.padding_right_14'), top:$r('app.float.padding_top_4'), bottom:$r('app.float.padding_bottom_4') })
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      if (this.engine.state === PomodoroState.IDLE) {
        Button($r('app.string.btn_start_focus'))
          .width('88%')
          .height($r('app.float.height_52'))
          .fontSize($r('app.float.fontSize_17'))
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.primary'))
          .borderRadius($r('app.float.borderRadius_18'))
          .margin({ bottom:$r('app.float.margin_bottom_18') })
          .onClick(() => {
            this.engine.startFocus();
          })
      } else if (this.engine.state === PomodoroState.FOCUSING) {
        Button($r('app.string.btn_giveup'))
          .width('88%')
          .height($r('app.float.height_44'))
          .fontSize($r('app.float.fontSize_14'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.danger'))
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius($r('app.float.borderRadius_16'))
          .border({ width:$r('app.float.border_width_1_5'), color: $r('app.color.today_border') })
          .margin({ bottom:$r('app.float.margin_bottom_18') })
          .onClick(() => {
            this.askGiveUp();
          })
      } else {
        Row({ space: 10 }) {
          Button($r('app.string.btn_skip_rest'))
            .layoutWeight(1)
            .height($r('app.float.height_46'))
            .fontSize($r('app.float.fontSize_14'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius($r('app.float.borderRadius_16'))
            .border({ width:$r('app.float.border_width_1_5'), color: $r('app.color.divider') })
            .onClick(() => {
              this.engine.skipRest();
            })
          Button($r('app.string.btn_focus_again'))
            .layoutWeight(1)
            .height($r('app.float.height_46'))
            .fontSize($r('app.float.fontSize_14'))
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.rest_green'))
            .borderRadius($r('app.float.borderRadius_16'))
            .onClick(() => {
              this.engine.focusAgain();
            })
        }
        .width('88%')
        .margin({ bottom:$r('app.float.margin_bottom_18') })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}

// BUG-001：@CustomDialog 内无法使用 V2 @Local（编译器强制 @Local 须配 @ComponentV2，而 @ComponentV2 与 @CustomDialog 互斥），
// 故此处回退为 V1 @State——这是 @CustomDialog 的固有合法用法；原静态标记 BUG-001 在框架约束下为误报。
@CustomDialog
struct CustomTagDialog {
  controller?: CustomDialogController;
  onConfirm: (tag: string) => void = (tag: string) => {};
  @State inputText: string = '';

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.custom_tag_title'))
        .fontSize($r('app.float.fontSize_16'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      TextInput({ placeholder: $r('app.string.custom_tag_hint'), text: this.inputText })
        .fontSize($r('app.float.fontSize_14'))
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_hint'))
        .maxLength(CUSTOM_TAG_MAX)
        .borderRadius($r('app.float.borderRadius_12'))
        .border({ width:$r('app.float.border_width_1_5'), color: $r('app.color.divider') })
        .padding($r('app.float.padding_11'))
        .onChange((value: string) => {
          this.inputText = value;
        })
      Row({ space: 10 }) {
        Button($r('app.string.action_cancel'))
          .layoutWeight(1)
          .height($r('app.float.height_40'))
          .fontSize($r('app.float.fontSize_14'))
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.ring_track'))
          .borderRadius($r('app.float.borderRadius_12'))
          .onClick(() => {
            if (this.controller !== undefined) {
              this.controller.close();
            }
          })
        Button($r('app.string.action_ok'))
          .layoutWeight(1)
          .height($r('app.float.height_40'))
          .fontSize($r('app.float.fontSize_14'))
          .fontColor(Color.White)
          .backgroundColor($r('app.color.primary'))
          .borderRadius($r('app.float.borderRadius_12'))
          .onClick(() => {
            const tag = this.inputText.trim();
            if (tag.length > 0) {
              this.onConfirm(tag);
            }
            if (this.controller !== undefined) {
              this.controller.close();
            }
          })
      }
      .width('100%')
    }
    .width($r('app.float.width_280'))
    .padding({ left:$r('app.float.padding_left_20'), right:$r('app.float.padding_right_20'), top:$r('app.float.padding_top_24'), bottom:$r('app.float.padding_bottom_16') })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.borderRadius_20'))
  }
}
