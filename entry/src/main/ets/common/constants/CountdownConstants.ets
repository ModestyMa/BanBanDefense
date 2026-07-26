// 倒数日模块常量定义（SPEC_M1 v1.0）
export class CountdownCategory {
  static readonly LIFE: string = 'life';
  static readonly WORK: string = 'work';
  static readonly MEMORIAL: string = 'memorial';
  static readonly REPAYMENT: string = 'repayment';
}

export class CountdownRoutes {
  static readonly LIST: string = 'pages/countdown/CountdownListPage';
  static readonly EDIT: string = 'pages/countdown/CountdownEditPage';
  static readonly DETAIL: string = 'pages/countdown/CountdownDetailPage';
}

/** 免费版倒数日数量上限（决策 D-005） */
export const FREE_EVENT_LIMIT: number = 3;

/** 分类展示元数据 */
export interface CategoryMeta {
  key: string;
  nameRes: Resource;
  colorRes: Resource;
}

export function categoryMetaList(): CategoryMeta[] {
  const list: CategoryMeta[] = [
    { key: CountdownCategory.LIFE, nameRes: $r('app.string.cat_life'), colorRes: $r('app.color.cat_life') },
    { key: CountdownCategory.WORK, nameRes: $r('app.string.cat_work'), colorRes: $r('app.color.cat_work') },
    { key: CountdownCategory.MEMORIAL, nameRes: $r('app.string.cat_memorial'), colorRes: $r('app.color.cat_memorial') },
    { key: CountdownCategory.REPAYMENT, nameRes: $r('app.string.cat_repayment'), colorRes: $r('app.color.cat_repayment') }
  ];
  return list;
}

export function categoryMetaOf(key: string): CategoryMeta {
  const list = categoryMetaList();
  for (const meta of list) {
    if (meta.key === key) {
      return meta;
    }
  }
  return list[0];
}
