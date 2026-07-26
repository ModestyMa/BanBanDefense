// 倒数日实体（interface 用于数据传递，遵守 ArkTS 禁令：类实例不作对象字面量传参）
export interface CountdownEventData {
  /** 数据库主键，新建时为 0 */
  id: number;
  title: string;
  /** 目标日当地 00:00 毫秒时间戳 */
  targetDate: number;
  /** life | work | memorial | repayment */
  category: string;
  isTop: boolean;
  remindEnabled: boolean;
  note: string;
  /** 已调度的 reminder id 列表（JSON 数组字符串，无则空串） */
  reminderIds: string;
  createdAt: number;
}

export function newCountdownEvent(): CountdownEventData {
  const ev: CountdownEventData = {
    id: 0,
    title: '',
    targetDate: 0,
    category: 'life',
    isTop: false,
    remindEnabled: true,
    note: '',
    reminderIds: '',
    createdAt: 0
  };
  return ev;
}
