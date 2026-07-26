// 番茄专注记录实体
export interface PomodoroSessionData {
  id: number;
  startTime: number;
  endTime: number;
  durationMin: number;
  /** work | study | sport | read | 自定义文本 */
  tag: string;
}
