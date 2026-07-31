// 番茄计时引擎（SPEC_M2 3.2）：目标时间戳法，状态机 IDLE → FOCUSING → RESTING → IDLE
// MVP 不做暂停（番茄法反模式）；杀进程会话丢失为已知限制（SPEC_M2 第 5 节）
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PomodoroRepository } from '../data/repository/PomodoroRepository';
import { PomodoroSessionData } from '../data/model/PomodoroSession';
import { PetEngine } from './PetEngine';
import { PetCardService } from './PetCardService';
import { ReminderService } from './ReminderService';
import { AppContextHolder } from '../common/AppContextHolder';
import { REST_MIN, POMODORO_NOTIFY_ID } from '../common/constants/PomodoroConstants';

const DOMAIN: number = 0x1200;
const TAG: string = 'PomodoroEngine';

export class PomodoroState {
  static readonly IDLE: string = 'IDLE';
  static readonly FOCUSING: string = 'FOCUSING';
  static readonly RESTING: string = 'RESTING';
}

@ObservedV2
export class PomodoroEngine {
  @Trace state: string = PomodoroState.IDLE;
  @Trace remainSec: number = 25 * 60;
  @Trace durationMin: number = 25;
  @Trace tag: string = '工作';

  private endTs: number = 0;
  private timerId: number = -1;
  private reminderId: number = 0;

  startFocus(): void {
    this.state = PomodoroState.FOCUSING;
    this.endTs = Date.now() + this.durationMin * 60000;
    this.scheduleEndReminder();
    this.startTicker();
    this.tick();
  }

  giveUp(): void {
    this.cancelEndReminder();
    this.stopTicker();
    this.backToIdle();
  }

  skipRest(): void {
    this.stopTicker();
    this.backToIdle();
  }

  focusAgain(): void {
    this.stopTicker();
    this.backToIdle();
    this.startFocus();
  }

  private backToIdle(): void {
    this.state = PomodoroState.IDLE;
    this.remainSec = this.durationMin * 60;
  }

  private startTicker(): void {
    this.stopTicker();
    this.timerId = setInterval(() => {
      this.tick();
    }, 1000);
  }

  private stopTicker(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  /** 每秒重算剩余（时间戳法，切后台回前台零漂移）；回前台也可手动调用 */
  tick(): void {
    if (this.state === PomodoroState.IDLE) {
      return;
    }
    const remainMs = this.endTs - Date.now();
    if (remainMs <= 0) {
      if (this.state === PomodoroState.FOCUSING) {
        this.completeFocus();
      } else {
        this.finishRest();
      }
      return;
    }
    this.remainSec = Math.ceil(remainMs / 1000);
  }

  /** 专注自然完成：写库 + 经验 +2 + 打卡 → 自动进休息 */
  private completeFocus(): void {
    this.stopTicker();
    const session: PomodoroSessionData = {
      id: 0,
      startTime: this.endTs - this.durationMin * 60000,
      endTime: this.endTs,
      durationMin: this.durationMin,
      tag: this.tag
    };
    PomodoroRepository.insert(session)
      .then(() => {
        return PetEngine.addExp(2);
      })
      .then(() => {
        return PetEngine.touchActive();
      })
      .then(() => {
        return PetCardService.pushToCards();
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, '专注记录/经验写入失败: %{public}s', err.message);
      });
    this.state = PomodoroState.RESTING;
    this.endTs = Date.now() + REST_MIN * 60000;
    this.remainSec = REST_MIN * 60;
    this.startTicker();
  }

  private finishRest(): void {
    this.stopTicker();
    this.backToIdle();
  }

  private scheduleEndReminder(): void {
    const context = AppContextHolder.get();
    if (context === null) {
      hilog.warn(DOMAIN, TAG, '无 Context，跳过番茄结束提醒调度');
      return;
    }
    const rm = context.resourceManager;
    const title: string = rm.getStringSync($r('app.string.remind_pomodoro_title'));
    const content: string = rm.getStringSync($r('app.string.remind_pomodoro_content'), this.tag);
    ReminderService.scheduleAt(this.endTs, title, content, POMODORO_NOTIFY_ID)
      .then((id: number) => {
        this.reminderId = id;
      })
      .catch((err: Error) => {
        hilog.warn(DOMAIN, TAG, '番茄结束提醒调度失败: %{public}s', err.message);
      });
  }

  private cancelEndReminder(): void {
    if (this.reminderId > 0) {
      const id = this.reminderId;
      this.reminderId = 0;
      ReminderService.cancelOne(id).catch((err: Error) => {
        hilog.warn(DOMAIN, TAG, '取消番茄提醒失败: %{public}s', err.message);
      });
    }
  }
}

/** 跨页面共享单例 */
export const pomodoroEngine: PomodoroEngine = new PomodoroEngine();
