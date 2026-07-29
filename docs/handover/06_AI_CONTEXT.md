# AI_CONTEXT — 伴伴 App 编码上下文（Kimi Work 编码时的自我约束唯一权威源）

> 用途：执行编码的 AI（D-012 起为 Qoder）执行任何编码任务前**重读本文件全文**（自我约束注入，权威源）。
> 维护：Kimi Work 与 Qoder 交接期间由 Kimi Work 冻结至 2026-07-28 快照；此后由执行方在每次验收完成后更新模块状态表与决策摘要。
> 最后更新：2026-07-28（D-012 交接 Qoder，冻结快照入仓库 docs/handover/）

---

## 1. 项目事实（FACTS）

- 产品：伴伴（BanBan）—— HarmonyOS NEXT 融合效率 App。
- 模块：倒数日 + 番茄钟 + 资产记账 + 服务卡片宠物（桌面调度中枢）。
- 目标系统：HarmonyOS NEXT，Stage 模型，单 HAP 双 module（entry 手机/平板/PC + wearable 手表，SPEC_M6 / D-010）。
- **SDK 基线：compatibleSdkVersion 6.1.0(23)，targetSdkVersion 6.1.0(23)，hvigor modelVersion 6.1.0，runtimeOS HarmonyOS**（本机工具链为 6.1.0，曾报 "Unsupported modelVersion 6.1.1"；代码按 API 23 编写）。
- 语言：ArkTS 严格模式；UI：ArkUI 声明式。
- 数据：@kit.ArkData relationalStore，全部本地存储，**无网络权限、无云端**。
- 提醒：@kit.ReminderKit（reminderAgent）。
- 卡片：FormExtensionAbility + ArkTS 卡片（2×2 / 2×4），postCardAction 跳转调度。
- **工程根目录：`C:\Users\User\Desktop\HarmanyOSAPP\BanBanDefense`**
- **bundleName：`com.modestyma.banban`**（D-011 正式定稿 2026-07-27，AGC 建应用同名不可再改；vendor ModestyMa）
- 版本控制：Git 已初始化（本仓库身份 banban-dev），main 分支首次提交 `d38d44f`。

## 2. 硬性禁令（VIOLATIONS = REJECT）

1. 禁止 `any` / `unknown`；所有变量、参数、返回值显式类型。
2. 禁止解构赋值（`const {a} = obj`）；逐属性显式取出。
3. 禁止将类实例作为对象字面量传参；接口数据用 interface。
4. 禁止编造 API：不确定的接口写入文件顶部注释 `// 假设API清单:` 供人工核对。
5. 禁止硬编码字符串/颜色/尺寸：一律 `$r('app.xxx')`；禁止写死屏幕宽度。
6. 页面（pages/）禁止直接访问数据库：必须经 `data/repository/`。
7. 联动规则（经验值/心情/连续打卡）只允许写在 `service/PetEngine.ets`。
8. 状态管理新代码用 V2：@ObservedV2 / @Trace / @Local / @Param；同组件不混 V1/V2。
9. 异步统一 async/await；数据库/文件操作必须 try-catch。
10. 禁止引入第三方依赖（MVP 期），图表自绘 Canvas。

## 3. 目录约定（MAP）

```
entry/src/main/ets/
├── entryability/EntryAbility.ets
├── formability/               # 卡片 FormExtensionAbility
├── pages/                     # Index / countdown/* / pomodoro/* / account/* / settings/*
├── components/                # 复用组件
├── viewmodel/                 # 页面状态与逻辑
├── service/                   # PetEngine.ets、提醒调度
├── data/{database,repository,model}/
├── common/{constants,utils}/
└── widget/pages/              # 卡片 UI（受限子集）
entry/src/main/resources/      # base/element(string,color,float) + media
```

## 4. 数据模型（SCHEMA，建表照此）

```
Account(id PK, name, type[wechat|alipay|bank|cash], balance, icon, sort, created_at)
Transaction(id PK, account_id FK, amount, direction[expense|income], category,
            counterparty, trade_time, source[manual|import|screenshot], external_no?, created_at)
CountdownEvent(id PK, title, target_date, is_lunar, repeat_rule?, category,
               linked_account_id?, note, created_at)
PomodoroSession(id PK, start_time, end_time, duration_min, tag, event_id?)
PetState(id PK 单行, level, exp, skin, mood[0|1|2], streak_days, last_active_date)
ImportBatch(id PK, source, file_name, imported_count, created_at)   # V1.0 启用
```

## 5. 命名与风格

- 页面 `XxxPage`；组件 `XxxComponent`；仓储 `XxxRepository`；服务 `XxxEngine/XxxService`；工具小驼峰；常量 `UPPER_SNAKE`。
- 主色 `#FF8A65`；圆角卡片风格；深浅色双适配。
- Commit：`[模块] 动作: 摘要 (by KimiWork|manual)`。

## 6. 联动规则（BUSINESS RULES）

- 记账 1 笔：exp +1；完成 1 个番茄：exp +2；当日首笔记账：卡片显示"已记账"。
- mood：近 3 天无行为 → 2（蔫了）；有 1 天 → 1（平常）；≥2 天 → 0（开心）。
- 连续打卡：当天有记账或完成番茄即算打卡，中断归零。
- 免费版上限：倒数日 ≤3 个（MVP 先 toast"Pro 即将上线"）。

## 7. 模块状态表（STATUS — Kimi Work 维护）

| 模块 | 状态 | 备注 |
|---|---|---|
| DevEco 工程初始化 | ✅ 完成 | BanBanDefense，Git 首提 d38d44f，2026-07-26 |
| 数据底座（建库+仓储） | ✅ 完成 | 6 张表 + CountdownRepository，2026-07-26 |
| 倒数日 | ✅ 完成（App 内） | 编译通过 commit bc46eca；卡片展示随 W3 卡片模块 |
| 番茄钟 | ✅ 完成 | 编译通过 commit 7d5dc36；含 MainPage Tabs 改造 + PetEngine 骨架 |
| 服务卡片宠物 | ✅ 完成（待真机核验） | 编译通过 commit 9a83ee7；真机验证项（杀进程提醒/卡片添加刷新）排到 W4 后统一做 |
| 手动记账 | ✅ 完成（待编译/真机核验） | 本地 commit b60e3a0 已推 GitHub（5 批，blob 抽查一致）；bindSheet→页面内浮层降级（SPEC_M4 §9-2 预留）；真机验证与 M3 挂起项统一做 |
| 首页聚合 + 设置/隐私页 | ✅ 完成（待编译/真机核验） | 本地 commit a02ff65 已推 GitHub（7 批，blob 抽查一致）；含记账报表/首启隐私弹窗/清除全部数据；Tabs 定案 4 个（首页/倒数日/番茄/记账）；余额对账降级为总余额+手动校准提示（SPEC_M5 决策 6） |
| 四端适配（手机/平板/PC/手表） | ✅ 完成（待编译/四端核验） | SPEC_M6：Part A commit d38bcf4 + Part B commit 05b96ba/4853f5a 已推 GitHub（抽查哈希一致）；收尾修正 commit 432c768（@StorageLink→@Computed、bgColor、txDirection）5 批推送一致；wearable hvigorfile.ts 补齐 commit 6d6ccae；假设 API 清单见 SPEC_M6 §10 待 DevEco 核验 |
| C1 宠物碎碎念 | ✅ 完成（待编译/真机核验） | T7 实现：PetEngine.getPetSpeech() 9 级优先级；2026-07-30 |
| C2 零联网隐私徽章 | ✅ 完成（待编译/真机核验） | T7 实现：ZeroNetworkBadge + PrivacyManifestPage（设置页入口）；2026-07-30 |
| C3 宠物作息钟 | ✅ 完成（待编译/真机核验） | T7 实现：PetTimeOfDay + 表情叠加；卡片 2×2 承载（见 §10 偏差）2026-07-30 |
| 上架打包 | 🔶 进行中 | SPEC_M7 决策 1/5 已签字（D-011）；包名 com.modestyma.banban 全仓替换 + 隐私政策邮箱定稿（commit 5d7af05，远端 ac5c353/36e7aa0 抽查一致）；图标 SVG 化 + Pages html 已推送；老板人工项见 SPEC_M7 §4（AGC S1–S14） |
| CSV 账单导入（V1.0） | 🔒 锁定 | MVP 后 |
| 闪控球（V1.5） | 🔒 锁定 | 需白名单 |

## 8. 最近决策摘要（DECISIONS — 最新在上）

- 2026-07-28 D-012：编码执行交回 Qoder（Kimi Code/Qwen Code）全程干活，Kimi Work 转文档维护与评审；本文件重新作为 Qoder 必读上下文；关键文档快照入仓库 docs/handover/。
- 2026-07-27 D-011：正式包名 com.modestyma.banban（vendor ModestyMa）；隐私政策联系邮箱 938632014@qq.com（App 内 txt + Pages html 同步）；SPEC_M7 决策 1/5 签字确认。
- 2026-07-26 D-010：MVP 四端同发（手机/平板/PC/手表）；手表独立 wearable module 只做概览/快记/倒数日三屏；各端数据独立本地存储为已知取舍（Pro 云同步解决）。
- 2026-07-26 D-009：工作模式变更——编码执行由 Qoder 收回，Kimi Work 全程包干（调度+编码一体），DevEco 仅编译/验证/上架；05 手册升 v2.0。
- 2026-07-26 D-008：工程名 BanBanDefense / bundleName com.example.banbandefense 为占位，上架前改为正式包名；SDK 基线 6.1.0(23)/6.1.1(24)。
- 2026-07-25 D-005：免费版倒数日上限 3 个；MVP 不做付费，上限提示"Pro 即将上线"。
- 2026-07-25 D-004：状态管理新代码统一 V2 装饰器。
- 2026-07-25 D-003：MVP 不申请网络权限，全部数据本地，作为审核与卖点策略。
- 2026-07-25 D-002：账单获取路径 = CSV 文件导入（主）+ 闪控球截屏（V1.5 辅），不接 API。
- 2026-07-25 D-001：桌面宠物 = 互动服务卡片（主形态），不做安卓式全局悬浮窗（权限不可行）。

## 9. 常见陷阱备忘（GOTCHAS — 持续追加）

- 本机 hvigor 只支持 modelVersion 6.1.0：新建工程/升级 DevEco 后若报 "Unsupported modelVersion"，把 oh-package.json5、hvigor/hvigor-config.json5、build-profile.json5 三处版本对齐本机工具链。
- 卡片 UI 是 ArkTS 受限子集：无网络、动画/组件能力受限，生成后必人工核验。
- reminderAgent 需要通知权限授权；杀进程后行为必须真机验证。
- reminderAgent 权限正确名是 ohos.permission.PUBLISH_AGENT_REMINDER（normal 级 system_grant）。早期误写为 ohos.permission.REMINDER_AGENT，DevEco 编译报错后已修正（2026-07-26，module.json5）。
- 支付宝账单 CSV 是 GBK 编码且前约 25 行为说明文字（V1.0 时注意）。
- AI 易编造 Kit 接口：凡出现不眼熟的 `@kit.*` 引用，先停手核对官方文档。
- GitHub 推送通道（MCP push_files）仅支持文本：图标等二进制一律用 SVG（已全部落地：entry/AppScope/wearable 三处图标 2026-07-27 起均为 SVG，仓库无二进制缺口，clone 即可构建）。
- 新建 module 必须带模块级 hvigorfile.ts（手建 wearable 曾漏，报 00303148 Hvigorfile not found，2026-07-27 已补）。
- MCP push_files 推送文本时注意文件末尾换行：推完用 blob SHA 对比 `git rev-parse HEAD:path`，尾换行不一致会导致哈希不符（build-profile.json5 已因此重推一次，2026-07-27）。
- 多 module 工程部署报错「deviceType 或 apiVersion 与 module.json5 不匹配」时，先查 DevEco 运行配置选中的 module（wearable 包不能装手机/PC），再查设备 apiVersion（2026-07-28 鸿蒙 PC 实测，原因就是误选 wearable）。
