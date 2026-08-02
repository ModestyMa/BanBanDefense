// 记账报表页（SPEC_M5 4.2）：月份切换 + 收支结余 + Canvas 分类环形图（支出占比）+ 明细 + 账户总余额
// 调色板取 color.json report_1~6，经 resourceManager 转 hex 供 Canvas 使用
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TransactionData } from '../../data/model/Transaction';
import { TransactionRepository } from '../../data/repository/TransactionRepository';
import { AccountRepository } from '../../data/repository/AccountRepository';
import { AccountData } from '../../data/model/Account';
import { ReportUtils, CategorySum } from '../../common/utils/ReportUtils';
import { MoneyUtils } from '../../common/utils/MoneyUtils';
import { txCategoryMetaOf } from '../../common/constants/AccountConstants';
import { ResponsiveContainer } from '../../components/ResponsiveContainer';
import { BreakpointHelper } from '../../common/utils/BreakpointHelper';

const DOMAIN: number = 0x1501;
const TAG: string = 'AccountReportPage';
const PALETTE_SIZE: number = 6;

@Entry
@ComponentV2
struct AccountReportPage {
  // 断点系统（SPEC_M6 §2）：lg 断点环形图与明细左右分栏
  @Computed get winWidthVp(): number { return AppStorage.get<number>('winWidthVp') ?? 360; }
  @Local year: number = 1970;
  @Local month: number = 1;
  @Local inCents: number = 0;
  @Local outCents: number = 0;
  @Local expenseItems: CategorySum[] = [];
  @Local percents: number[] = [];
  @Local totalBalanceCents: number = 0;
  @Local palette: string[] = [];
  // 环形图底色（Canvas strokeStyle 只接受字符串，运行时由 ring_track 资源解析，随深浅色自适应）
  private ringTrack: string = '#F0EBE4';
  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings);

  private isLg(): boolean {
    return this.winWidthVp > BreakpointHelper.LG_THRESHOLD;
  }

  aboutToAppear(): void {
    const now = new Date();
    this.year = now.getFullYear();
    this.month = now.getMonth() + 1;
    this.buildPalette();
    this.loadReport().catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '报表加载失败: %{public}s', err.message);
    });
  }

  private buildPalette(): void {
    const rm = getContext(this).resourceManager;
    const res: Resource[] = [
      $r('app.color.report_1'), $r('app.color.report_2'), $r('app.color.report_3'),
      $r('app.color.report_4'), $r('app.color.report_5'), $r('app.color.report_6')
    ];
    const out: string[] = [];
    for (const r of res) {
      const c: number = rm.getColorSync(r);
      out.push('#' + (c & 0xFFFFFF).toString(16).padStart(6, '0'));
    }
    this.palette = out;
    const track: number = rm.getColorSync($r('app.color.ring_track'));
    this.ringTrack = '#' + (track & 0xFFFFFF).toString(16).padStart(6, '0');
  }

  private async loadReport(): Promise<void> {
    const range: number[] = ReportUtils.monthRange(this.year, this.month);
    const txs: TransactionData[] = await TransactionRepository.listByRange(range[0], range[1]);
    this.inCents = ReportUtils.sumByDirection(txs, 'in');
    this.outCents = ReportUtils.sumByDirection(txs, 'out');
    this.expenseItems = ReportUtils.aggregateByCategory(txs, 'out');
    this.percents = ReportUtils.sharePercents(this.expenseItems);
    const accounts: AccountData[] = await AccountRepository.listAll();
    let total: number = 0;
    for (const acc of accounts) {
      total += MoneyUtils.toCents(acc.balance);
    }
    this.totalBalanceCents = total;
    this.drawRing();
  }

  private isCurrentMonth(): boolean {
    const now = new Date();
    return this.year === now.getFullYear() && this.month === now.getMonth() + 1;
  }

  private shiftMonth(delta: number): void {
    let m: number = this.month + delta;
    let y: number = this.year;
    if (m < 1) {
      m = 12;
      y -= 1;
    } else if (m > 12) {
      m = 1;
      y += 1;
    }
    this.year = y;
    this.month = m;
    this.loadReport().catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '报表切换失败: %{public}s', err.message);
    });
  }

  /** 环形图：Canvas 弧线分段（环宽 24，起始 -90°）；无支出画占位灰环 */
  private drawRing(): void {
    const ctx = this.canvasCtx;
    const cx = 80;
    const cy = 80;
    const radius = 58;
    ctx.clearRect(0, 0, 160, 160);
    ctx.lineWidth = 24;
    ctx.lineCap = 'butt';
    if (this.outCents <= 0 || this.expenseItems.length === 0) {
      ctx.beginPath();
      ctx.strokeStyle = this.ringTrack;
      ctx.arc(cx, cy, radius, 0, Math.PI * 2);
      ctx.stroke();
      return;
    }
    let angle: number = -Math.PI / 2;
    for (let i = 0; i < this.expenseItems.length; i++) {
      const sweep: number = Math.PI * 2 * this.percents[i] / 100;
      // 末段强制闭合到 3π/2，消除浮点缝隙
      const end: number = i === this.expenseItems.length - 1 ? Math.PI * 1.5 : angle + sweep;
      ctx.beginPath();
      ctx.strokeStyle = this.palette.length > 0 ? this.palette[i % PALETTE_SIZE] : '#FF8A65';
      ctx.arc(cx, cy, radius, angle, end);
      ctx.stroke();
      angle = end;
    }
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
      Text($r('app.string.report_title'))
        .fontSize($r('app.float.fontSize_17'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .margin({ right:$r('app.float.margin_right_40') })
    }
    .width('100%')
    .padding({ left:$r('app.float.padding_left_16'), right:$r('app.float.padding_right_16'), top:$r('app.float.padding_top_6'), bottom:$r('app.float.padding_bottom_12') })
  }

  @Builder
  monthSwitcher() {
    Row() {
      Text('‹')
        .fontSize($r('app.float.fontSize_20'))
        .fontColor($r('app.color.text_primary'))
        .padding({ left:$r('app.float.padding_left_16'), right:$r('app.float.padding_right_16'), top:$r('app.float.padding_top_6'), bottom:$r('app.float.padding_bottom_6') })
        .onClick(() => {
          this.shiftMonth(-1);
        })
      Text(getContext(this).resourceManager.getStringSync($r('app.string.report_month_fmt'), this.year, this.month))
        .fontSize($r('app.float.fontSize_16'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('›')
        .fontSize($r('app.float.fontSize_20'))
        .fontColor(this.isCurrentMonth() ? $r('app.color.text_hint') : $r('app.color.text_primary'))
        .padding({ left:$r('app.float.padding_left_16'), right:$r('app.float.padding_right_16'), top:$r('app.float.padding_top_6'), bottom:$r('app.float.padding_bottom_6') })
        .enabled(!this.isCurrentMonth())
        .onClick(() => {
          this.shiftMonth(1);
        })
    }
    .width('100%')
    .padding({ left:$r('app.float.padding_left_16'), right:$r('app.float.padding_right_16') })
  }

  @Builder
  summaryRow() {
    Row() {
      this.summaryCell($r('app.string.report_income'), MoneyUtils.formatAmount(this.inCents), $r('app.color.income_green'))
      this.summaryCell($r('app.string.report_expense'), MoneyUtils.formatAmount(this.outCents), $r('app.color.danger'))
      this.summaryCell($r('app.string.report_balance'), MoneyUtils.formatAmount(this.inCents - this.outCents),
        this.inCents - this.outCents >= 0 ? $r('app.color.income_green') : $r('app.color.danger'))
    }
    .width('100%')
    .padding({ left:$r('app.float.padding_left_16'), right:$r('app.float.padding_right_16') })
  }

  @Builder
  summaryCell(label: Resource, value: string, valueColor: Resource) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize($r('app.float.fontSize_12'))
        .fontColor($r('app.color.text_hint'))
      Text(value)
        .fontSize($r('app.float.fontSize_17'))
        .fontWeight(FontWeight.Bold)
        .fontColor(valueColor)
    }
    .layoutWeight(1)
  }

  @Builder
  ringArea() {
    Stack() {
      Canvas(this.canvasCtx)
        .width($r('app.float.width_160'))
        .height($r('app.float.height_160'))
        .onReady(() => {
          this.drawRing();
        })
      Column({ space: 2 }) {
        Text(this.outCents > 0 ? $r('app.string.report_expense') : $r('app.string.report_empty'))
          .fontSize($r('app.float.fontSize_11'))
          .fontColor($r('app.color.text_hint'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width($r('app.float.width_110'))
          .textAlign(TextAlign.Center)
        if (this.outCents > 0) {
          Text(MoneyUtils.formatAmount(this.outCents))
            .fontSize($r('app.float.fontSize_16'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }
      }
    }
    .width($r('app.float.width_160'))
    .height($r('app.float.height_160'))
    .margin({ top:$r('app.float.margin_top_8'), bottom:$r('app.float.margin_bottom_8') })
  }

  @Builder
  detailList() {
    Column({ space: 10 }) {
      ForEach(this.expenseItems, (item: CategorySum, index: number) => {
        Row({ space: 10 }) {
          Text('●')
            .fontSize($r('app.float.fontSize_12'))
            .fontColor(this.palette.length > 0 ? this.palette[index % PALETTE_SIZE] : '#FF8A65')
          Text(txCategoryMetaOf(item.key).emoji + ' ' +
            getContext(this).resourceManager.getStringSync(txCategoryMetaOf(item.key).nameRes))
            .fontSize($r('app.float.fontSize_14'))
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text(MoneyUtils.formatAmount(item.cents))
            .fontSize($r('app.float.fontSize_14'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(this.percents[index].toString() + '%')
            .fontSize($r('app.float.fontSize_13'))
            .fontColor($r('app.color.text_hint'))
            .width($r('app.float.width_44'))
            .textAlign(TextAlign.End)
        }
        .width('100%')
        // BUG-008：key 只用分类名时，切换月份后同分类金额变化不会重建行（金额/占比停留在上月）
      }, (item: CategorySum, index: number) => item.key + ':' + item.cents.toString() + ':' + index.toString())
    }
    .width('100%')
    .padding($r('app.float.padding_16'))
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.borderRadius_16'))
  }

  @Builder
  balanceCard() {
    Column({ space: 6 }) {
      Row() {
        Text($r('app.string.report_total_balance'))
          .fontSize($r('app.float.fontSize_14'))
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
        Text(MoneyUtils.formatAmount(this.totalBalanceCents))
          .fontSize($r('app.float.fontSize_16'))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.totalBalanceCents >= 0 ? $r('app.color.income_green') : $r('app.color.danger'))
      }
      .width('100%')
      Text($r('app.string.report_reconcile_hint'))
        .fontSize($r('app.float.fontSize_11'))
        .fontColor($r('app.color.text_hint'))
        .width('100%')
    }
    .width('100%')
    .padding($r('app.float.padding_16'))
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.borderRadius_16'))
  }

  build() {
    Column() {
      ResponsiveContainer({ bgColor: $r('app.color.page_bg') }) {
      Scroll() {
        Column({ space: 16 }) {
          this.navBar()
          this.monthSwitcher()
          this.summaryRow()
          if (this.isLg() && this.expenseItems.length > 0) {
            // lg 断点：环形图与分类明细左右分栏（SPEC_M6 §4）
            Row({ space: 16 }) {
              Column() {
                this.ringArea()
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)
              Column() {
                this.detailList()
              }
              .layoutWeight(1)
            }
            .width('100%')
            .padding({ left:$r('app.float.padding_left_16'), right:$r('app.float.padding_right_16') })
            .alignItems(VerticalAlign.Top)
          } else {
            Row() {
              this.ringArea()
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            if (this.expenseItems.length > 0) {
              Column() {
                this.detailList()
              }
              .width('100%')
              .padding({ left:$r('app.float.padding_left_16'), right:$r('app.float.padding_right_16') })
            }
          }
          Column() {
            this.balanceCard()
          }
          .width('100%')
          .padding({ left:$r('app.float.padding_left_16'), right:$r('app.float.padding_right_16'), bottom:$r('app.float.padding_bottom_20') })
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
    }
    }
    .width('100%')
    .height('100%')
  }
}
