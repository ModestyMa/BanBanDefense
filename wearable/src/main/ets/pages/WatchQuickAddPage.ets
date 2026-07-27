// 手表快记屏（SPEC_M6 决策 7-②）：金额 + 支出/收入 + 分类 emoji 网格 + 保存
// 保存走默认账户：插流水 → 调余额 → PetEngine.addExp(1) + touchActive（无卡片推送）
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { watchVM } from '../viewmodel/WatchViewModel';
import { TransactionRepository } from '../data/repository/TransactionRepository';
import { AccountRepository } from '../data/repository/AccountRepository';
import { PetEngine } from '../service/PetEngine';
import { TransactionData, newTransaction } from '../data/model/Transaction';
import { MoneyUtils } from '../common/utils/MoneyUtils';
import { TxDirection, TxCategory, TxCategoryMeta, expenseCategoryList, incomeCategoryList }
  from '../common/constants/AccountConstants';

const DOMAIN: number = 0x2001;
const TAG: string = 'WatchQuickAddPage';

@ComponentV2
export struct WatchQuickAddPage {
  private vm = watchVM;
  @Local amountText: string = '';
  @Local txDirection: string = TxDirection.OUT;
  @Local category: string = TxCategory.FOOD;

  aboutToAppear(): void {
    this.vm.load().catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '手表快记加载失败: %{public}s', err.message);
    });
  }

  private categories(): TxCategoryMeta[] {
    return this.txDirection === TxDirection.OUT ? expenseCategoryList() : incomeCategoryList();
  }

  private canSave(): boolean {
    return MoneyUtils.isValidAmount(this.amountText) && this.vm.defaultAccountId > 0;
  }

  private onSave(): void {
    const cents: number = MoneyUtils.toCents(Number(this.amountText.trim()));
    const tx: TransactionData = newTransaction();
    tx.accountId = this.vm.defaultAccountId;
    tx.amount = MoneyUtils.toYuan(cents);
    tx.direction = this.txDirection;
    tx.category = this.category;
    tx.note = '';
    tx.tradeTime = Date.now();
    tx.source = 'manual';
    tx.createdAt = Date.now();
    const delta: number = this.txDirection === TxDirection.IN ? cents : -cents;
    TransactionRepository.insert(tx)
      .then(() => {
        return AccountRepository.adjustBalance(tx.accountId, delta);
      })
      .then(() => {
        return PetEngine.addExp(1);
      })
      .then(() => {
        return PetEngine.touchActive();
      })
      .then(() => {
        promptAction.showToast({ message: $r('app.string.toast_tx_saved') });
        this.amountText = '';
        return this.vm.load();
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, '手表快记保存失败: %{public}s', err.message);
        promptAction.showToast({ message: $r('app.string.toast_tx_failed') });
      });
  }

  @Builder
  txDirectionChip(label: Resource, dir: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.txDirection === dir ? Color.White : $r('app.color.text_secondary'))
      .backgroundColor(this.txDirection === dir ? $r('app.color.primary') : $r('app.color.card_bg'))
      .borderRadius(12)
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      .onClick(() => {
        this.txDirection = dir;
        // 切换方向后复位分类，避免支出分类落到收入流水上
        this.category = dir === TxDirection.OUT ? TxCategory.FOOD : TxCategory.SALARY;
      })
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text($r('app.string.watch_quick_add'))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        // 金额
        Row({ space: 6 }) {
          Text('¥')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_secondary'))
          TextInput({ placeholder: $r('app.string.tx_hint_amount'), text: this.amountText })
            .type(InputType.NUMBER_DECIMAL)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_hint'))
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .padding(0)
            .onChange((value: string) => {
              this.amountText = value;
            })
        }
        .width('100%')
        .padding(12)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(14)

        // 方向
        Row({ space: 10 }) {
          this.txDirectionChip($r('app.string.tx_dir_out'), TxDirection.OUT)
          this.txDirectionChip($r('app.string.tx_dir_in'), TxDirection.IN)
        }
        .width('100%')

        // 分类 emoji 网格
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.categories(), (meta: TxCategoryMeta) => {
            Column({ space: 2 }) {
              Text(meta.emoji)
                .fontSize(20)
              Text(meta.nameRes)
                .fontSize(10)
                .fontColor(this.category === meta.key ? $r('app.color.primary') : $r('app.color.text_secondary'))
            }
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(12)
            .border({
              width: 1.5,
              color: this.category === meta.key ? $r('app.color.primary') : $r('app.color.divider')
            })
            .backgroundColor(this.category === meta.key ? $r('app.color.today_bg') : $r('app.color.card_bg'))
            .margin({ right: 6, bottom: 6 })
            .onClick(() => {
              this.category = meta.key;
            })
          }, (meta: TxCategoryMeta) => meta.key)
        }
        .width('100%')

        Button($r('app.string.action_save'))
          .width('100%')
          .height(42)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.primary'))
          .borderRadius(14)
          .opacity(this.canSave() ? 1 : 0.35)
          .enabled(this.canSave())
          .onClick(() => {
            this.onSave();
          })
      }
      .width('100%')
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    .scrollBar(BarState.Off)
  }
}
