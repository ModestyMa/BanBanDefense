// 记账模块常量（SPEC_M4 §1-4/5）：分类与账户类型元数据，emoji 即图标
export class TxDirection {
  static readonly OUT: string = 'out';
  static readonly IN: string = 'in';
}

export class TxCategory {
  static readonly FOOD: string = 'food';
  static readonly TRANSPORT: string = 'transport';
  static readonly SHOPPING: string = 'shopping';
  static readonly HOUSING: string = 'housing';
  static readonly ENTERTAINMENT: string = 'entertainment';
  static readonly SALARY: string = 'salary';
  static readonly OTHER: string = 'other';
}

export class AccountType {
  static readonly CASH: string = 'cash';
  static readonly WECHAT: string = 'wechat';
  static readonly ALIPAY: string = 'alipay';
  static readonly BANK: string = 'bank';
  static readonly OTHER: string = 'other';
}

export class AccountRoutes {
  static readonly MANAGE: string = 'pages/account/AccountManagePage';
  static readonly REPORT: string = 'pages/account/AccountReportPage';
}

/** 分类展示元数据 */
export interface TxCategoryMeta {
  key: string;
  nameRes: Resource;
  emoji: string;
  direction: string;
}

export function expenseCategoryList(): TxCategoryMeta[] {
  const list: TxCategoryMeta[] = [
    { key: TxCategory.FOOD, nameRes: $r('app.string.txcat_food'), emoji: '🍜', direction: TxDirection.OUT },
    { key: TxCategory.TRANSPORT, nameRes: $r('app.string.txcat_transport'), emoji: '🚌', direction: TxDirection.OUT },
    { key: TxCategory.SHOPPING, nameRes: $r('app.string.txcat_shopping'), emoji: '🛍️', direction: TxDirection.OUT },
    { key: TxCategory.HOUSING, nameRes: $r('app.string.txcat_housing'), emoji: '🏠', direction: TxDirection.OUT },
    { key: TxCategory.ENTERTAINMENT, nameRes: $r('app.string.txcat_entertainment'), emoji: '🎮', direction: TxDirection.OUT },
    { key: TxCategory.OTHER, nameRes: $r('app.string.txcat_other'), emoji: '📦', direction: TxDirection.OUT }
  ];
  return list;
}

export function incomeCategoryList(): TxCategoryMeta[] {
  const list: TxCategoryMeta[] = [
    { key: TxCategory.SALARY, nameRes: $r('app.string.txcat_salary'), emoji: '💰', direction: TxDirection.IN },
    { key: TxCategory.OTHER, nameRes: $r('app.string.txcat_other'), emoji: '📦', direction: TxDirection.IN }
  ];
  return list;
}

export function txCategoryMetaOf(key: string): TxCategoryMeta {
  const all = expenseCategoryList().concat(incomeCategoryList());
  for (const meta of all) {
    if (meta.key === key) {
      return meta;
    }
  }
  return expenseCategoryList()[0];
}

/** 账户类型元数据 */
export interface AccountTypeMeta {
  key: string;
  nameRes: Resource;
  emoji: string;
}

export function accountTypeList(): AccountTypeMeta[] {
  const list: AccountTypeMeta[] = [
    { key: AccountType.CASH, nameRes: $r('app.string.acctype_cash'), emoji: '💵' },
    { key: AccountType.WECHAT, nameRes: $r('app.string.acctype_wechat'), emoji: '💚' },
    { key: AccountType.ALIPAY, nameRes: $r('app.string.acctype_alipay'), emoji: '💙' },
    { key: AccountType.BANK, nameRes: $r('app.string.acctype_bank'), emoji: '💳' },
    { key: AccountType.OTHER, nameRes: $r('app.string.acctype_other'), emoji: '🔖' }
  ];
  return list;
}

export function accountTypeMetaOf(key: string): AccountTypeMeta {
  const list = accountTypeList();
  for (const meta of list) {
    if (meta.key === key) {
      return meta;
    }
  }
  return list[0];
}
