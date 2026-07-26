// 番茄钟模块常量（SPEC_M2）
export class PomodoroRoutes {
  static readonly STATS: string = 'pages/pomodoro/PomodoroStatsPage';
}

/** 休息时长（分钟，固定） */
export const REST_MIN: number = 5;

/** 时长快捷档（分钟） */
export const DURATION_PRESETS: number[] = [15, 25, 45, 60];

/** 滑块范围与步进 */
export const DURATION_MIN: number = 5;
export const DURATION_MAX: number = 120;
export const DURATION_STEP: number = 5;

/** 内置标签 */
export const BASE_TAGS: string[] = ['工作', '学习', '运动', '阅读'];

/** 自定义标签最大字数 */
export const CUSTOM_TAG_MAX: number = 8;

/** 番茄结束提醒的 notificationId 基数（避开倒数日 id*10+slot 区间） */
export const POMODORO_NOTIFY_ID: number = 900001;
