// 账户管理页（SPEC_M4 4.2）：账户列表（余额）+ 新建/编辑浮层；有流水的账户禁止删除
import { router, promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { accountVM } from '../../viewmodel/AccountViewModel';
import { AccountData, newAccount } from '../../data/model/Account';
import { AccountRepository } from '../../data/repository/AccountRepository';
import { MoneyUtils } from '../../common/utils/MoneyUtils';
import { AccountTypeMeta, accountTypeList, accountTypeMetaOf } from '../../common/constants/AccountConstants';
import { ResponsiveContainer } from '../../components/ResponsiveContainer';

const DOMAIN: number = 0x1402;
const TAG: string = 'AccountManagePage';

@Entry
@ComponentV2
struct AccountManagePage {
  private vm = accountVM;
  @Local editingAccId: number = 0;
  @Local accName: string = '';
  @Local accType: string = 'cash';
  @Local accBalanceText: string = '';

  onPageShow(): void {
    this.vm.load().catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '账户加载失败: %{public}s', err.message);
    });
  }

  private isValidBalance(text: string): boolean {
    const trimmed = text.trim();
    if (!/^-?\d+(\.\d{1,2})?$/.test(trimmed)) {
      return false;
    }
    const v = Number(trimmed);
    return Math.abs(v) <= 99999999.99;
  }

  private canSave(): boolean {
    return this.accName.trim().length > 0 && this.isValidBalance(this.accBalanceText);
  }

  private startNew(): void {
    this.editingAccId = -1;
    this.accName = '';
    this.accType = 'cash';
    this.accBalanceText = '0';
  }

  private startEdit(acc: AccountData): void {
    this.editingAccId = acc.id;
    this.accName = acc.name;
    this.accType = acc.type;
    this.accBalanceText = MoneyUtils.formatAmount(MoneyUtils.toCents(acc.balance));
  }

  private closeEditor(): void {
    this.editingAccId = 0;
  }

  private onSave(): void {
    const acc = newAccount();
    acc.id = this.editingAccId > 0 ? this.editingAccId : 0;
    acc.name = this.accName.trim();
    acc.type = this.accType;
    acc.icon = accountTypeMetaOf(this.accType).emoji;
    acc.balance = MoneyUtils.toYuan(MoneyUtils.toCents(Number(this.accBalanceText.trim())));
    acc.sort = this.vm.accounts.length;
    acc.createdAt = Date.now();
    const isNew: boolean = this.editingAccId === -1;
    const task: Promise<number> = isNew ? AccountRepository.insert(acc) : AccountRepository.update(acc);
    task
      .then(() => {
        return this.vm.load();
      })
      .then(() => {
        promptAction.showToast({ message: $r('app.string.toast_acc_saved') });
        this.closeEditor();
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, '账户保存失败: %{public}s', err.message);
        promptAction.showToast({ message: $r('app.string.toast_save_failed') });
      });
  }

  private onDelete(): void {
    const targetId = this.editingAccId;
    AccountRepository.hasTransactions(targetId)
      .then((has: boolean) => {
        if (has) {
          promptAction.showToast({ message: $r('app.string.toast_acc_has_tx') });
          return;
        }
        AlertDialog.show({
          title: $r('app.string.acc_delete'),
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
              AccountRepository.deleteById(targetId)
                .then(() => {
                  if (this.vm.accountId === targetId) {
                    this.vm.accountId = 0;
                  }
                  return this.vm.load();
                })
                .then(() => {
                  promptAction.showToast({ message: $r('app.string.toast_acc_deleted') });
                  this.closeEditor();
                })
                .catch((err: Error) => {
                  hilog.error(DOMAIN, TAG, '账户删除失败: %{public}s', err.message);
                });
            }
          }
        });
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, '账户流水检查失败: %{public}s', err.message);
      });
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
      Text($r('app.string.account_manage'))
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

  /**
   * BUG-008：ForEach key 只用 id 时，账户改名/余额变动（记账后）不会触发行重建。
   * 把可变字段并入 key，内容变化即生成新 key。
   */
  private static accKey(acc: AccountData): string {
    return acc.id.toString() + ':' + acc.name + ':' + acc.type + ':' + acc.balance.toString() + ':' + acc.icon + ':' + acc.sort.toString();
  }

  @Builder
  accountRow(acc: AccountData) {
    Row({ space: 12 }) {
      Text(acc.icon)
        .fontSize($r('app.float.fontSize_24'))
      Column({ space: 2 }) {
        Text(acc.name)
          .fontSize($r('app.float.fontSize_16'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(accountTypeMetaOf(acc.type).nameRes)
          .fontSize($r('app.float.fontSize_12'))
          .fontColor($r('app.color.text_hint'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(MoneyUtils.formatAmount(MoneyUtils.toCents(acc.balance)))
        .fontSize($r('app.float.fontSize_16'))
        .fontWeight(FontWeight.Bold)
        .fontColor(acc.balance >= 0 ? $r('app.color.income_green') : $r('app.color.danger'))
    }
    .width('100%')
    .padding($r('app.float.padding_16'))
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.borderRadius_16'))
    .shadow({ radius: 10, color: '#0D000000', offsetY: 2 })
    .onClick(() => {
      this.startEdit(acc);
    })
  }

  @Builder
  editorOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.mask_scrim'))
        .onClick(() => {
          this.closeEditor();
        })
      Column({ space: 14 }) {
        Text(this.editingAccId === -1 ? $r('app.string.acc_new') : $r('app.string.acc_edit'))
          .fontSize($r('app.float.fontSize_16'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        Column({ space: 8 }) {
          Text($r('app.string.acc_field_name'))
            .fontSize($r('app.float.fontSize_13'))
            .fontColor($r('app.color.text_secondary'))
          TextInput({ placeholder: $r('app.string.acc_name_hint'), text: this.accName })
            .fontSize($r('app.float.fontSize_15'))
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_hint'))
            .backgroundColor(Color.Transparent)
            .maxLength(10)
            .padding(0)
            .onChange((value: string) => {
              this.accName = value;
            })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Column({ space: 8 }) {
          Text($r('app.string.acc_field_type'))
            .fontSize($r('app.float.fontSize_13'))
            .fontColor($r('app.color.text_secondary'))
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(accountTypeList(), (meta: AccountTypeMeta) => {
              Text(meta.emoji + ' ' + getContext(this).resourceManager.getStringSync(meta.nameRes))
                .fontSize($r('app.float.fontSize_13'))
                .fontColor(this.accType === meta.key ? $r('app.color.primary') : $r('app.color.text_secondary'))
                .backgroundColor(this.accType === meta.key ? $r('app.color.today_bg') : $r('app.color.card_bg'))
                .borderRadius($r('app.float.borderRadius_12'))
                .border({
                  width: 1.5,
                  color: this.accType === meta.key ? $r('app.color.primary') : $r('app.color.divider')
                })
                .padding({ left:$r('app.float.padding_left_12'), right:$r('app.float.padding_right_12'), top:$r('app.float.padding_top_7'), bottom:$r('app.float.padding_bottom_7') })
                .margin({ right:$r('app.float.margin_right_8'), bottom:$r('app.float.margin_bottom_8') })
                .onClick(() => {
                  this.accType = meta.key;
                })
            }, (meta: AccountTypeMeta) => meta.key)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Column({ space: 8 }) {
          Text($r('app.string.acc_field_balance'))
            .fontSize($r('app.float.fontSize_13'))
            .fontColor($r('app.color.text_secondary'))
          Row({ space: 8 }) {
            Text('¥')
              .fontSize($r('app.float.fontSize_18'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_secondary'))
            TextInput({ placeholder: '0.00', text: this.accBalanceText })
              .type(InputType.NUMBER_DECIMAL)
              .fontSize($r('app.float.fontSize_18'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_hint'))
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .padding(0)
              .onChange((value: string) => {
                this.accBalanceText = value;
              })
          }
          .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Button($r('app.string.action_save'))
          .width('100%')
          .height($r('app.float.height_46'))
          .fontSize($r('app.float.fontSize_16'))
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.primary'))
          .borderRadius($r('app.float.borderRadius_14'))
          .opacity(this.canSave() ? 1 : 0.35)
          .enabled(this.canSave())
          .onClick(() => {
            this.onSave();
          })

        if (this.editingAccId > 0) {
          Button($r('app.string.acc_delete'))
            .width('100%')
            .height($r('app.float.height_42'))
            .fontSize($r('app.float.fontSize_14'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.danger'))
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius($r('app.float.borderRadius_14'))
            .border({ width:$r('app.float.border_width_1_5'), color: $r('app.color.today_border') })
            .onClick(() => {
              this.onDelete();
            })
        }
      }
      .width('100%')
      .padding($r('app.float.padding_20'))
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      ResponsiveContainer({ bgColor: $r('app.color.page_bg') }) {
      Stack() {
        Column() {
          this.navBar()
          if (this.vm.accounts.length === 0) {
            Column({ space: 12 }) {
              Text($r('app.string.empty_tx_emoji'))
                .fontSize($r('app.float.fontSize_52'))
              Text($r('app.string.acc_empty'))
                .fontSize($r('app.float.fontSize_13'))
                .fontColor($r('app.color.text_hint'))
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else {
            List({ space: 12 }) {
              ForEach(this.vm.accounts, (acc: AccountData) => {
                ListItem() {
                  this.accountRow(acc)
                }
              }, (acc: AccountData) => AccountManagePage.accKey(acc))
            }
            .width('100%')
            .layoutWeight(1)
            .padding({ left:$r('app.float.padding_left_16'), right:$r('app.float.padding_right_16'), bottom:$r('app.float.padding_bottom_12') })
            .scrollBar(BarState.Off)
          }

          Button($r('app.string.acc_new'))
            .width('90%')
            .height($r('app.float.height_48'))
            .fontSize($r('app.float.fontSize_16'))
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.primary'))
            .borderRadius($r('app.float.borderRadius_16'))
            .margin({ bottom:$r('app.float.margin_bottom_26') })
            .onClick(() => {
              this.startNew();
            })
        }
        .width('100%')
        .height('100%')

        if (this.editingAccId !== 0) {
          this.editorOverlay()
        }
      }
      .width('100%')
      .height('100%')
    }
    }
    .width('100%')
    .height('100%')
  }
}
