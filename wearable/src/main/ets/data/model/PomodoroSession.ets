// 【手表端副本】与 entry module 同步维护，V1.0 抽 HAR 后删除（SPEC_M6 决策 8）
// 番茄专注记录实体
export interface PomodoroSessionData {
  id: number;
  startTime: number;
  endTime: number;
  durationMin: number;
  /** work | study | sport | read | 自定义文本 */
  tag: string;
}
