// 记账模块视图模型（跨页面单例）：快记面板状态 + 流水分组 + 余额联动编排（SPEC_M4 5.2/5.3/5.4）
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AccountData } from '../data/model/Account';
import { TransactionData, newTransaction } from '../data/model/Transaction';
import { AccountRepository } from '../data/repository/AccountRepository';
import { TransactionRepository } from '../data/repository/TransactionRepository';
import { PetEngine } from '../service/PetEngine';
import { PetCardService } from '../service/PetCardService';
import { MoneyUtils } from '../common/utils/MoneyUtils';
import { DateUtils } from '../common/utils/DateUtils';
import { TxDirection, TxCategory, expenseCategoryList, incomeCategoryList } from '../common/constants/AccountConstants';
import { DatabaseHelper } from '../data/database/DatabaseHelper';

const DOMAIN: number = 0x1400;
const TAG: string = 'AccountViewModel';

/** 按日分组（组内流水已按 trade_time 倒序） */
export class DayGroup {
  dayStart: number = 0;
  items: TransactionData[] = [];
}

@ObservedV2
export class AccountViewModel {
  @Trace accounts: AccountData[] = [];
  @Trace groups: DayGroup[] = [];
  // 快记/编辑面板字段
  @Trace amountText: string = '';
  @Trace direction: string = TxDirection.OUT;
  @Trace category: string = TxCategory.FOOD;
  @Trace accountId: number = 0;
  @Trace note: string = '';
  /** 0 = 新建；>0 = 正在编辑的流水 id */
  @Trace editingId: number = 0;
  /** 编辑时的发生日期（当天 00:00 时间戳） */
  @Trace editDayStart: number = 0;

  /** 载入账户与流水并分组；首次调用初始化默认账户 */
  async load(): Promise<void> {
    // BUG-007：页面 aboutToAppear 可能抢在 EntryAbility 异步 init 完成前调用，先等数据底座就绪
    await DatabaseHelper.ready();
    await AccountRepository.initDefaultsIfEmpty();
    this.accounts = await AccountRepository.listAll();
    if (this.accountId === 0 && this.accounts.length > 0) {
      this.accountId = this.accounts[0].id;
    }
    const all = await TransactionRepository.listAll();
    this.groups = AccountViewModel.buildGroups(all);
  }

  private static buildGroups(all: TransactionData[]): DayGroup[] {
    const out: DayGroup[] = [];
    for (const tx of all) {
      const d = new Date(tx.tradeTime);
      const dayStart = DateUtils.dayStartOf(d.getFullYear(), d.getMonth() + 1, d.getDate());
      let group: DayGroup | null = null;
      for (const g of out) {
        if (g.dayStart === dayStart) {
          group = g;
          break;
        }
      }
      if (group === null) {
        group = new DayGroup();
        group.dayStart = dayStart;
        out.push(group);
      }
      group.items.push(tx);
    }
    return out;
  }

  accountOf(id: number): AccountData | null {
    for (const acc of this.accounts) {
      if (acc.id === id) {
        return acc;
      }
    }
    return null;
  }

  setDirection(d: string): void {
    if (this.direction === d) {
      return;
    }
    this.direction = d;
    const list = d === TxDirection.IN ? incomeCategoryList() : expenseCategoryList();
    this.category = list[0].key;
  }

  canSave(): boolean {
    return MoneyUtils.isValidAmount(this.amountText) && this.accountId > 0;
  }

  /** 保存（新建或编辑）。抛异常表示失败（页面 toast）。 */
  async save(): Promise<void> {
    const cents: number = MoneyUtils.toCents(Number(this.amountText.trim()));
    if (this.editingId === 0) {
      await this.saveNew(cents);
    } else {
      await this.saveEdit(cents);
    }
    this.resetForm();
    await this.load();
  }

  private async saveNew(cents: number): Promise<void> {
    const tx = newTransaction();
    tx.accountId = this.accountId;
    tx.amount = MoneyUtils.toYuan(cents);
    tx.direction = this.direction;
    tx.category = this.category;
    tx.note = this.note.trim();
    tx.tradeTime = Date.now();
    tx.createdAt = Date.now();
    const delta: number = this.direction === TxDirection.IN ? cents : -cents;
    let newId: number = 0;
    try {
      newId = await TransactionRepository.insert(tx);
      await AccountRepository.adjustBalance(this.accountId, delta);
    } catch (err) {
      // 补偿：余额调整失败则删掉刚插入的流水
      if (newId > 0) {
        try {
          await TransactionRepository.deleteById(newId);
        } catch (compErr) {
          hilog.error(DOMAIN, TAG, '补偿删除流水失败: %{public}s', JSON.stringify(compErr));
        }
      }
      throw err as Error;
    }
    // 宠物联动：仅新建计经验与打卡（SPEC_M4 5.4）
    PetEngine.addExp(1)
      .then(() => {
        return PetEngine.touchActive();
      })
      .then(() => {
        return PetCardService.pushToCards();
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, '记账联动失败: %{public}s', err.message);
      });
  }

  private async saveEdit(cents: number): Promise<void> {
    const oldTx = await TransactionRepository.findById(this.editingId);
    if (oldTx === null) {
      throw new Error('流水不存在 id=' + this.editingId.toString());
    }
    const newTx = newTransaction();
    newTx.id = oldTx.id;
    newTx.accountId = this.accountId;
    newTx.amount = MoneyUtils.toYuan(cents);
    newTx.direction = this.direction;
    newTx.category = this.category;
    newTx.note = this.note.trim();
    newTx.tradeTime = this.editDayStart > 0
      ? this.editDayStart + (Date.now() - DateUtils.todayStart())
      : oldTx.tradeTime;
    newTx.source = oldTx.source;
    newTx.createdAt = oldTx.createdAt;

    const oldDelta: number = oldTx.direction === TxDirection.IN ? -MoneyUtils.toCents(oldTx.amount) : MoneyUtils.toCents(oldTx.amount);
    const newDelta: number = this.direction === TxDirection.IN ? cents : -cents;
    let step = 0;
    try {
      await AccountRepository.adjustBalance(oldTx.accountId, oldDelta); // 1 回滚旧值
      step = 1;
      await AccountRepository.adjustBalance(newTx.accountId, newDelta); // 2 应用新值
      step = 2;
      await TransactionRepository.update(newTx); // 3 更新流水
    } catch (err) {
      // 补偿：按已执行步骤逆向回退
      try {
        if (step >= 2) {
          await AccountRepository.adjustBalance(newTx.accountId, -newDelta);
        }
        if (step >= 1) {
          await AccountRepository.adjustBalance(oldTx.accountId, -oldDelta);
        }
      } catch (compErr) {
        hilog.error(DOMAIN, TAG, '编辑补偿失败: %{public}s', JSON.stringify(compErr));
      }
      throw err as Error;
    }
  }

  /** 删除流水：先回滚余额再删库，删库失败则恢复余额 */
  async deleteTx(tx: TransactionData): Promise<void> {
    const reverse: number = tx.direction === TxDirection.IN ? -MoneyUtils.toCents(tx.amount) : MoneyUtils.toCents(tx.amount);
    let adjusted = false;
    try {
      await AccountRepository.adjustBalance(tx.accountId, reverse);
      adjusted = true;
      await TransactionRepository.deleteById(tx.id);
    } catch (err) {
      if (adjusted) {
        try {
          await AccountRepository.adjustBalance(tx.accountId, -reverse);
        } catch (compErr) {
          hilog.error(DOMAIN, TAG, '删除补偿失败: %{public}s', JSON.stringify(compErr));
        }
      }
      throw err as Error;
    }
    await this.load();
  }

  /** 进入编辑态：把流水值填入面板 */
  startEdit(tx: TransactionData): void {
    this.editingId = tx.id;
    this.amountText = MoneyUtils.formatAmount(MoneyUtils.toCents(tx.amount));
    this.direction = tx.direction;
    this.category = tx.category;
    this.accountId = tx.accountId;
    this.note = tx.note;
    const d = new Date(tx.tradeTime);
    this.editDayStart = DateUtils.dayStartOf(d.getFullYear(), d.getMonth() + 1, d.getDate());
  }

  /** 退出编辑态/保存后复位（保留方向/分类/账户便于连续记账） */
  resetForm(): void {
    this.editingId = 0;
    this.amountText = '';
    this.note = '';
    this.editDayStart = 0;
  }
}

/** 跨页面共享单例 */
export const accountVM: AccountViewModel = new AccountViewModel();
