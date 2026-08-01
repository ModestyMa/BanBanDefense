// 首页聚合 Tab（SPEC_M5 4.1）：宠物状态条 + 今日概览三卡（倒数日/专注/账单），点卡跳对应 Tab
// 跳 Tab 用 TabsController 构造注入（SPEC_M5 §9 定案，不用 AppStorage 轮询）
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { homeVM } from '../../viewmodel/HomeViewModel';
import { MoneyUtils } from '../../common/utils/MoneyUtils';
import { BreakpointHelper } from '../../common/utils/BreakpointHelper';
import { AppContextHolder } from '../../common/AppContextHolder';

const DOMAIN: number = 0x1500;
const TAG: string = 'HomePage';
const ROUTE_SETTINGS: string = 'pages/settings/SettingsPage';

@ComponentV2
export struct HomePage {
  @Require @Param controller: TabsController;
  // 断点系统（SPEC_M6 §2）：lg 断点今日概览三卡横排
  @Computed get winWidthVp(): number { return AppStorage.get<number>('winWidthVp') ?? 360; }
  private vm = homeVM;

  // BUG-004 同根因：build 中经 private 普通方法间接读状态不建立 V2 依赖，一律改 @Computed
  @Computed get isLg(): boolean { return this.winWidthVp > BreakpointHelper.LG_THRESHOLD; }

  aboutToAppear(): void {
    this.vm.load().catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '首页加载失败: %{public}s', err.message);
    });
  }

  // BUG-004 修复（2026-08-02）：三卡文案原为 private 普通方法，build 经方法调用间接读取
  // homeVM(@ObservedV2 外部单例) 的 @Trace 字段 → ArkUI V2 依赖未建立，异步 load() 晚于首帧
  // 完成时永不重绘（冷启动 28% 概率三卡空白且不自愈）。改 @Computed get 后依赖成立。
  // resourceManager 走 AppContextHolder 兜底（EntryAbility 早已 set），避免 @Computed 求值
  // 时机早于组件挂载时 getContext(this) 不可用。兜底写法与 MainPage.ets:96/109 一致。

  @Computed
  get countdownMain(): string {
    const context = AppContextHolder.get() ?? getContext(this);
    const rm = context.resourceManager;
    if (!this.vm.hasCountdown) {
      return rm.getStringSync($r('app.string.home_cd_empty'));
    }
    if (this.vm.cdDays === 0) {
      return this.vm.cdTitle + ' · ' + rm.getStringSync($r('app.string.day_today'));
    }
    return this.vm.cdTitle + ' · ' + rm.getStringSync($r('app.string.day_future_fmt'), this.vm.cdDays);
  }

  @Computed
  get focusMain(): string {
    const context = AppContextHolder.get() ?? getContext(this);
    const rm = context.resourceManager;
    if (this.vm.focusCount === 0) {
      return rm.getStringSync($r('app.string.home_focus_empty'));
    }
    return rm.getStringSync($r('app.string.home_focus_fmt'), this.vm.focusMinutes, this.vm.focusCount);
  }

  @Computed
  get billMain(): string {
    const context = AppContextHolder.get() ?? getContext(this);
    const rm = context.resourceManager;
    if (this.vm.billOutCount + this.vm.billInCount === 0) {
      return rm.getStringSync($r('app.string.home_bill_empty'));
    }
    const outText: string = rm.getStringSync($r('app.string.home_bill_out_fmt'),
      MoneyUtils.formatAmount(this.vm.billOutCents), this.vm.billOutCount);
    if (this.vm.billInCount === 0) {
      return outText;
    }
    const inText: string = rm.getStringSync($r('app.string.home_bill_in_fmt'),
      MoneyUtils.formatAmount(this.vm.billInCents), this.vm.billInCount);
    return outText + '\n' + inText;
  }

  @Builder
  navBar() {
    Row() {
      Text($r('app.string.EntryAbility_label'))
        .fontSize($r('app.float.fontSize_28'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Text('⚙')
        .fontSize($r('app.float.fontSize_22'))
        .fontColor($r('app.color.text_secondary'))
        .padding($r('app.float.padding_6'))
        .onClick(() => {
          router.pushUrl({ url: ROUTE_SETTINGS });
        })
    }
    .width('100%')
    .padding({ left:$r('app.float.padding_left_20'), right:$r('app.float.padding_right_20'), top:$r('app.float.padding_top_8'), bottom:$r('app.float.padding_bottom_4') })
  }

  /** 宠物状态条：心情 + 等级 + 连续天数 + 打卡状态（纯展示，不跳转——SPEC_M5 原设计跳记账已按老板反馈撤回） */
  @Builder
  petCard() {
    Row({ space: 14 }) {
      Text(this.vm.petEmoji)
        .fontSize($r('app.float.fontSize_44'))
      Column({ space: 4 }) {
        Row({ space: 10 }) {
          Text('Lv.' + this.vm.petLevel.toString())
            .fontSize($r('app.float.fontSize_15'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.home_streak_fmt', this.vm.streakDays))
            .fontSize($r('app.float.fontSize_13'))
            .fontColor($r('app.color.text_secondary'))
        }
        Text(this.vm.activeToday ? $r('app.string.home_pet_active') : $r('app.string.home_pet_idle'))
          .fontSize($r('app.float.fontSize_13'))
          .fontColor(this.vm.activeToday ? $r('app.color.income_green') : $r('app.color.text_hint'))
        // C1 碎碎念气泡（mini-SPEC §1.6-1）：文案为空时不渲染
        if (this.vm.petSpeechText.length > 0) {
          Text(this.vm.petSpeechEmoji + ' ' + this.vm.petSpeechText)
            .fontSize($r('app.float.fontSize_13'))
            .fontColor($r('app.color.primary'))
            .padding({ left:$r('app.float.padding_left_10'), right:$r('app.float.padding_right_10'), top:$r('app.float.padding_top_5'), bottom:$r('app.float.padding_bottom_5') })
            .backgroundColor($r('app.color.today_bg'))
            .borderRadius($r('app.float.borderRadius_10'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding($r('app.float.padding_16'))
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.borderRadius_16'))
    .shadow({ radius: 10, color: '#0D000000', offsetY: 2 })
  }

  /** 今日概览卡（图标 + 标题 + 主文案 + 跳转箭头） */
  @Builder
  overviewCard(icon: string, title: string, main: string, targetIndex: number) {
    Row({ space: 14 }) {
      Text(icon)
        .fontSize($r('app.float.fontSize_26'))
      Column({ space: 4 }) {
        Text(title)
          .fontSize($r('app.float.fontSize_13'))
          .fontColor($r('app.color.text_hint'))
        Text(main)
          .fontSize($r('app.float.fontSize_15'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .lineHeight($r('app.float.lineHeight_22'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›')
        .fontSize($r('app.float.fontSize_22'))
        .fontColor($r('app.color.text_hint'))
    }
    .width('100%')
    .padding($r('app.float.padding_16'))
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.borderRadius_16'))
    .shadow({ radius: 10, color: '#0D000000', offsetY: 2 })
    .onClick(() => {
      this.controller.changeIndex(targetIndex);
    })
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        this.navBar()
        Column({ space: 12 }) {
          this.petCard()
          if (this.isLg) {
            // lg 断点：今日概览三卡横排（SPEC_M6 §4）
            Row({ space: 12 }) {
              Column() {
                this.overviewCard('📅', getContext(this).resourceManager.getStringSync($r('app.string.tab_countdown')),
                  this.countdownMain, 1)
              }
              .layoutWeight(1)
              Column() {
                this.overviewCard('🍅', getContext(this).resourceManager.getStringSync($r('app.string.pomodoro_title')),
                  this.focusMain, 2)
              }
              .layoutWeight(1)
              Column() {
                this.overviewCard('💰', getContext(this).resourceManager.getStringSync($r('app.string.tab_account')),
                  this.billMain, 3)
              }
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          } else {
            this.overviewCard('📅', getContext(this).resourceManager.getStringSync($r('app.string.tab_countdown')),
              this.countdownMain, 1)
            this.overviewCard('🍅', getContext(this).resourceManager.getStringSync($r('app.string.pomodoro_title')),
              this.focusMain, 2)
            this.overviewCard('💰', getContext(this).resourceManager.getStringSync($r('app.string.tab_account')),
              this.billMain, 3)
          }
        }
        .width('100%')
        .padding({ left:$r('app.float.padding_left_16'), right:$r('app.float.padding_right_16'), bottom:$r('app.float.padding_bottom_20') })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
