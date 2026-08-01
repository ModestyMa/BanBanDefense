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
      .fontSize($r('app.float.fontSize_13'))
      .fontColor(this.txDirection === dir ? Color.White : $r('app.color.text_secondary'))
      .backgroundColor(this.txDirection === dir ? $r('app.color.primary') : $r('app.color.card_bg'))
      .borderRadius($r('app.float.borderRadius_12'))
      .padding({ left:$r('app.float.padding_left_16'), right:$r('app.float.padding_right_16'), top:$r('app.float.padding_top_6'), bottom:$r('app.float.padding_bottom_6') })
      .onClick(() => {
        this.txDirection = dir;
        // 切换方向后复位分类，避免支出分类落到收入流水上
        this.category = dir === TxDirection.OUT ? TxCategory.FOOD : TxCategory.SALARY;
      })
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 6 }) {
          Text($r('app.string.watch_quick_add'))
            .fontSize($r('app.float.fontSize_16'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          // 金额
          Row({ space: 6 }) {
            Text('¥')
              .fontSize($r('app.float.fontSize_18'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_secondary'))
            TextInput({ placeholder: $r('app.string.tx_hint_amount'), text: this.amountText })
              .type(InputType.NUMBER_DECIMAL)
              .fontSize($r('app.float.fontSize_18'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_hint'))
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .padding(0)
              .onChange((value: string) => {
                this.amountText = value;
              })
              .enableKeyboardOnFocus(false)
          }
          .width('100%')
          .padding($r('app.float.padding_12'))
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius($r('app.float.borderRadius_14'))

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
                  .fontSize($r('app.float.fontSize_18'))
                Text(meta.nameRes)
                  .fontSize($r('app.float.fontSize_10'))
                  .fontColor(this.category === meta.key ? $r('app.color.primary') : $r('app.color.text_secondary'))
              }
              .padding({ left:$r('app.float.padding_left_10'), right:$r('app.float.padding_right_10'), top:$r('app.float.padding_top_6'), bottom:$r('app.float.padding_bottom_6') })
              .borderRadius($r('app.float.borderRadius_12'))
              .border({
                width: 1.5,
                color: this.category === meta.key ? $r('app.color.primary') : $r('app.color.divider')
              })
              .backgroundColor(this.category === meta.key ? $r('app.color.today_bg') : $r('app.color.card_bg'))
              .margin({ right:$r('app.float.margin_right_6'), bottom:$r('app.float.margin_bottom_6') })
              .onClick(() => {
                this.category = meta.key;
              })
            }, (meta: TxCategoryMeta) => meta.key)
          }
          .width('100%')
        }
        .width('100%')
        .padding($r('app.float.padding_12'))
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.PARENT_FIRST
      })

      Button($r('app.string.action_save'))
        .width('100%')
        .height($r('app.float.height_42'))
        .fontSize($r('app.float.fontSize_15'))
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.primary'))
        .borderRadius($r('app.float.borderRadius_14'))
        .opacity(this.canSave() ? 1 : 0.35)
        .enabled(this.canSave())
        .onClick(() => {
          this.onSave();
        })
        .margin({ left: $r('app.float.padding_12'), right: $r('app.float.padding_12'), bottom: $r('app.float.padding_12') })
    }
    .width('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
