// 记账 Tab 主页（SPEC_M4 4.1）：顶部常驻快速记账面板 + 下方按日分组流水
// 编辑用页面内浮层实现（SPEC_M4 §9-2 的降级方案：不用 bindSheet，规避 Tabs 内嵌兼容风险）
import { router, promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { accountVM, DayGroup } from '../../viewmodel/AccountViewModel';
import { AccountData } from '../../data/model/Account';
import { TransactionData } from '../../data/model/Transaction';
import { DateUtils } from '../../common/utils/DateUtils';
import { MoneyUtils } from '../../common/utils/MoneyUtils';
import {
  TxDirection, AccountRoutes, TxCategoryMeta,
  expenseCategoryList, incomeCategoryList, txCategoryMetaOf
} from '../../common/constants/AccountConstants';

const DOMAIN: number = 0x1401;
const TAG: string = 'AccountPage';

@ComponentV2
export struct AccountPage {
  private vm = accountVM;

  aboutToAppear(): void {
    this.vm.load().catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '记账页加载失败: %{public}s', err.message);
    });
  }

  private groupLabel(dayStart: number): string {
    const rm = getContext(this).resourceManager;
    const days = DateUtils.dayInfo(dayStart).days;
    if (days === 0) {
      return rm.getStringSync($r('app.string.day_today_short'));
    }
    if (days === -1) {
      return rm.getStringSync($r('app.string.day_yesterday'));
    }
    const d = new Date(dayStart);
    return rm.getStringSync($r('app.string.md_fmt'), d.getMonth() + 1, d.getDate());
  }

  private accountNameOf(id: number): string {
    const acc = this.vm.accountOf(id);
    return acc === null ? '' : acc.name;
  }

  private confirmDelete(tx: TransactionData): void {
    AlertDialog.show({
      title: $r('app.string.action_delete'),
      message: $r('app.string.delete_tx_confirm_msg'),
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
          this.vm.deleteTx(tx)
            .then(() => {
              promptAction.showToast({ message: $r('app.string.toast_tx_deleted') });
            })
            .catch((err: Error) => {
              hilog.error(DOMAIN, TAG, '删除流水失败: %{public}s', err.message);
              promptAction.showToast({ message: $r('app.string.toast_save_failed') });
            });
        }
      }
    });
  }

  private onSave(): void {
    this.vm.save()
      .then(() => {
        promptAction.showToast({ message: $r('app.string.toast_tx_saved') });
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, '保存流水失败: %{public}s', err.message);
        promptAction.showToast({ message: $r('app.string.toast_tx_failed') });
      });
  }

  @Builder
  navBar() {
    Row() {
      Text($r('app.string.tab_account'))
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Text('⚙ ' + getContext(this).resourceManager.getStringSync($r('app.string.account_manage')))
        .fontSize(14)
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          router.pushUrl({ url: AccountRoutes.MANAGE });
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 4 })
  }

  @Builder
  directionChips() {
    Row({ space: 8 }) {
      Text($r('app.string.tx_dir_out'))
        .dirChipStyle(this.vm.direction === TxDirection.OUT)
        .onClick(() => {
          this.vm.setDirection(TxDirection.OUT);
        })
      Text($r('app.string.tx_dir_in'))
        .dirChipStyle(this.vm.direction === TxDirection.IN)
        .onClick(() => {
          this.vm.setDirection(TxDirection.IN);
        })
    }
  }

  @Builder
  amountRow() {
    Row({ space: 8 }) {
      this.directionChips()
      Blank()
      Text('¥')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_secondary'))
      TextInput({ placeholder: $r('app.string.tx_hint_amount'), text: this.vm.amountText })
        .type(InputType.NUMBER_DECIMAL)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_hint'))
        .textAlign(TextAlign.End)
        .backgroundColor(Color.Transparent)
        .layoutWeight(1)
        .maxLength(10)
        .padding(0)
        .onChange((value: string) => {
          this.vm.amountText = value;
        })
    }
    .width('100%')
  }

  @Builder
  categoryChips() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.vm.direction === TxDirection.IN ? incomeCategoryList() : expenseCategoryList(),
        (meta: TxCategoryMeta) => {
          Row({ space: 4 }) {
            Text(meta.emoji)
              .fontSize(14)
            Text(meta.nameRes)
              .fontSize(13)
              .fontColor(this.vm.category === meta.key ? $r('app.color.primary') : $r('app.color.text_secondary'))
          }
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .borderRadius(12)
          .border({
            width: 1.5,
            color: this.vm.category === meta.key ? $r('app.color.primary') : $r('app.color.divider')
          })
          .backgroundColor(this.vm.category === meta.key ? $r('app.color.today_bg') : $r('app.color.card_bg'))
          .margin({ right: 8, bottom: 8 })
          .onClick(() => {
            this.vm.category = meta.key;
          })
        }, (meta: TxCategoryMeta) => meta.key)
    }
    .width('100%')
  }

  @Builder
  accountChips() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.vm.accounts, (acc: AccountData) => {
          Text(acc.icon + ' ' + acc.name)
            .fontSize(13)
            .fontColor(this.vm.accountId === acc.id ? $r('app.color.primary') : $r('app.color.text_secondary'))
            .backgroundColor(this.vm.accountId === acc.id ? $r('app.color.today_bg') : $r('app.color.card_bg'))
            .borderRadius(12)
            .border({
              width: 1.5,
              color: this.vm.accountId === acc.id ? $r('app.color.primary') : $r('app.color.divider')
            })
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .onClick(() => {
              this.vm.accountId = acc.id;
            })
        }, (acc: AccountData) => acc.id.toString())
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  /** 快记/编辑共用面板（isEdit 控制标题与日期行） */
  @Builder
  txPanel(isEdit: boolean) {
    Column({ space: 14 }) {
      if (isEdit) {
        Row() {
          Text($r('app.string.edit_tx_title'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text(DateUtils.formatDate(this.vm.editDayStart))
            .fontSize(14)
            .fontColor($r('app.color.primary'))
            .onClick(() => {
              DatePickerDialog.show({
                start: new Date(2000, 0, 1),
                end: new Date(),
                selected: new Date(this.vm.editDayStart),
                onDateAccept: (value: Date) => {
                  this.vm.editDayStart = DateUtils.dayStartOf(
                    value.getFullYear(), value.getMonth() + 1, value.getDate());
                }
              });
            })
        }
        .width('100%')
      }
      this.amountRow()
      this.categoryChips()
      this.accountChips()
      TextInput({ placeholder: $r('app.string.tx_hint_note'), text: this.vm.note })
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_hint'))
        .backgroundColor(Color.Transparent)
        .maxLength(30)
        .padding(0)
        .onChange((value: string) => {
          this.vm.note = value;
        })
      Button($r('app.string.tx_save'))
        .width('100%')
        .height(46)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.primary'))
        .borderRadius(14)
        .opacity(this.vm.canSave() ? 1 : 0.35)
        .enabled(this.vm.canSave())
        .onClick(() => {
          this.onSave();
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .shadow({ radius: 10, color: '#0D000000', offsetY: 2 })
  }

  @Builder
  txRow(tx: TransactionData) {
    Row({ space: 12 }) {
      Text(txCategoryMetaOf(tx.category).emoji)
        .fontSize(22)
      Column({ space: 2 }) {
        Text(txCategoryMetaOf(tx.category).nameRes)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text((tx.note.length > 0 ? tx.note + ' · ' : '') + this.accountNameOf(tx.accountId))
          .fontSize(12)
          .fontColor($r('app.color.text_hint'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(MoneyUtils.signedText(tx.direction, MoneyUtils.toCents(tx.amount)))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(tx.direction === TxDirection.IN ? $r('app.color.income_green') : $r('app.color.danger'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .onClick(() => {
      this.vm.startEdit(tx);
    })
  }

  @Builder
  deleteButton(tx: TransactionData) {
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
      this.confirmDelete(tx);
    })
  }

  @Builder
  txList() {
    List({ space: 10 }) {
      ForEach(this.vm.groups, (group: DayGroup) => {
        ListItemGroup({ header: this.groupHeader(group.dayStart) }) {
          ForEach(group.items, (tx: TransactionData) => {
            ListItem() {
              this.txRow(tx)
            }
            .swipeAction({
              end: {
                builder: () => {
                  this.deleteButton(tx);
                }
              }
            })
          }, (tx: TransactionData) => tx.id.toString())
        }
      }, (group: DayGroup) => group.dayStart.toString())
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16, bottom: 20 })
    .scrollBar(BarState.Off)
  }

  @Builder
  groupHeader(dayStart: number) {
    Text(this.groupLabel(dayStart))
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_hint'))
      .width('100%')
      .padding({ left: 4, top: 4, bottom: 2 })
  }

  @Builder
  emptyView() {
    Column({ space: 14 }) {
      Text($r('app.string.empty_tx_emoji'))
        .fontSize(56)
      Text($r('app.string.empty_tx'))
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

  /** 编辑浮层（dim 背景 + 底部面板） */
  @Builder
  editOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.vm.resetForm();
        })
      Column() {
        this.txPanel(true)
        Button($r('app.string.action_cancel'))
          .width('100%')
          .height(42)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(14)
          .margin({ top: 10 })
          .onClick(() => {
            this.vm.resetForm();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 24 })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      Column({ space: 12 }) {
        this.navBar()
        Column() {
          this.txPanel(false)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })

        if (this.vm.groups.length === 0) {
          this.emptyView()
        } else {
          this.txList()
        }
      }
      .width('100%')
      .height('100%')

      if (this.vm.editingId > 0) {
        this.editOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}

@Extend(Text)
function dirChipStyle(selected: boolean) {
  .fontSize(14)
  .fontWeight(selected ? FontWeight.Bold : FontWeight.Normal)
  .fontColor(selected ? Color.White : $r('app.color.text_secondary'))
  .backgroundColor(selected ? $r('app.color.primary') : $r('app.color.ring_track'))
  .borderRadius(14)
  .padding({ left: 16, right: 16, top: 7, bottom: 7 })
}
