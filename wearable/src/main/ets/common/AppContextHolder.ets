// 【手表端副本】与 entry module 同步维护，V1.0 抽 HAR 后删除（SPEC_M6 决策 8）
// 应用级上下文持有器：让 service 层（无 UI 组件环境）也能拿到 UIAbilityContext
import { common } from '@kit.AbilityKit';

export class AppContextHolder {
  private static context: common.UIAbilityContext | null = null;

  static set(ctx: common.UIAbilityContext): void {
    AppContextHolder.context = ctx;
  }

  static get(): common.UIAbilityContext | null {
    return AppContextHolder.context;
  }
}
