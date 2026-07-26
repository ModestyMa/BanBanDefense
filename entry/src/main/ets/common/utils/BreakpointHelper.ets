// 断点助手（SPEC_M6 §2）：窗口宽度经 AppStorage 全局共享（EntryAbility 监听窗口变化写入）
// 断点：xs(<600) 手机竖屏 / sm(600~840) 横屏小平板 / lg(>840) 平板 PC
export class BreakpointHelper {
  static readonly KEY_WIDTH: string = 'winWidthVp';
  static readonly LG_THRESHOLD: number = 840;

  /** 当前窗口宽度（vp）；未初始化时按手机竖屏 360 兜底 */
  static width(): number {
    const w = AppStorage.get<number>(BreakpointHelper.KEY_WIDTH);
    return w === undefined ? 360 : w;
  }

  /** 是否 lg 断点（平板/PC：左侧导航 + 横排布局） */
  static isLg(): boolean {
    return BreakpointHelper.width() > BreakpointHelper.LG_THRESHOLD;
  }
}
