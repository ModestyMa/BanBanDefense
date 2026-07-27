# SPEC_M6 四端适配（手机/平板/PC/手表）— 功能规格说明书

- 版本：v1.0 | 日期：2026-07-26 | 状态：✅ 老板已签字（2026-07-27，"开工"确认）
- 依据：老板 2026-07-26 决策「MVP 需要包含 PC 和手表，PC/手机/手表/平板四端同时发布」（修订 03 文档第六章的时间点，范围不变）+ 03_技术架构设计 六、多端策略
- 前置：W1~W5 全部落地（手机端功能完整）
- 风险标注：本规格含**新建手表 module**（工程结构变动）与**响应式布局改造**（触及全部页面）；含假设 API 清单（§10）

---

## 0. 必须先对齐的工程现实（老板决策依据）

1. **手机/平板/PC（2in1）同宗**：同一 HAP、同一套 ArkUI 页面，加断点自适应即可，工作量可控。
2. **手表（wearable）是另一个世界**：屏幕 ~390×450vp、无底部 Tabs 导航、无服务卡片体系、交互以单栏滚动+按钮为主。架构文档原定「独立轻量 module」（V2.0 提前到 MVP）。
3. **数据不互通**：MVP 无网络权限红线（D-003），四端各自独立本地数据库——手表上记的账**不会**出现在手机上。这是 MVP 固有取舍，上架文案需明示「各端数据独立存储」（Pro 云同步解决）。
4. 手表端功能必须**砍**：只做「看 + 快记」，不做番茄计时、不做报表、不做账户管理、不做提醒。

## 1. 设计决策固化（需求基准）

| # | 结论 |
|---|---|
| 1 | `module.json5` deviceTypes 扩展：手机端 module 加 `"tablet"` + `"2in1"`；手表为**新建独立 module**（`wearable`，deviceTypes `["wearable"]`），架构文档「独立轻量 module」路线不变 |
| 2 | 三端（手机/平板/PC）自适应走**断点系统**：新增 `common/utils/BreakpointHelper.ets`，按窗口宽度分 xs(<600) / sm(600~840) / lg(>840)，宽度经 AppStorage 全局共享（EntryAbility 监听窗口变化写入） |
| 3 | 全页面套**限宽容器**：新增 `components/ResponsiveContainer.ets`——内容最大宽 640vp，超过则水平居中、两侧留白（手机端行为完全不变） |
| 4 | MainPage 宽屏导航：lg 断点下 Tabs 改 `barPosition: Start`（左侧竖排），tabItem 变横向（图标+文字一排）；xs/sm 保持底部导航 |
| 5 | 首页三卡：lg 断点横排一行三列（Row + layoutWeight），xs/sm 竖排 |
| 6 | 报表页：lg 断点环形图与分类明细**左右分栏**（图左表右）；xs/sm 保持上下 |
| 7 | 手表端（wearable module）功能范围——**只做 3 屏**：① 概览屏（宠物心情/等级/连续天数 + 今日支出/收入合计）② 快记屏（金额 + 支出/收入 + 分类 emoji 网格 + 保存，账户默认第一个自动初始化）③ 倒数日屏（标题 + 天数列表）。导航用单栏 Swiper 或垂直 List + 页内按钮，无 Tabs |
| 8 | 手表端数据层：复制基础层文件进 wearable module（DateUtils / MoneyUtils / DatabaseHelper / Account·Transaction·CountdownEvent·PetState 模型 / 4 个仓储 / PetEngine），**不抽 HAR**（03 文档：V1.0 后再抽，避免工程大改） |
| 9 | 手表端不做：番茄计时、报表、账户管理、提醒调度、服务卡片、隐私弹窗（上架隐私政策覆盖全端，手表首启不弹窗——无网络无提醒权限申请，无必要） |
| 10 | 验证方式：DevEco 预览器/模拟器四端（phone / tablet / 2in1 / wearable）编译运行；手机端回归无变化为硬指标 |
| 11 | 上架打包：四端同一应用包发布（AGC 多设备类型），属 W6 范围 |

## 2. 断点与布局规范

| 断点 | 宽度 | 设备 | 布局行为 |
|---|---|---|---|
| xs | <600vp | 手机竖屏 | 现状（底部导航/竖排卡片/上下报表） |
| sm | 600~840vp | 手机横屏/折叠展开/小平板 | 限宽容器生效（640 居中），其余同 xs |
| lg | >840vp | 平板/PC | 左侧导航 + 首页三卡横排 + 报表左右分栏 |

- 字号/色板/圆角不动；只动布局结构，不动业务逻辑
- 宽度一律不写死（03 文档 MVP 编码纪律），新增布局同理

## 3. 新增/改动文件清单（手机端 module）

| 文件 | 职责 | 新/改 |
|---|---|---|
| `common/utils/BreakpointHelper.ets` | 断点判定 + 窗口宽度读写（AppStorage 键 `winWidthVp`） | 新 |
| `components/ResponsiveContainer.ets` | 限宽居中容器（@ComponentV2，slot 式包裹） | 新 |
| `entryability/EntryAbility.ets` | onWindowStageCreate 后注册窗口尺寸监听 → 写 AppStorage | 改 |
| `pages/MainPage.ets` | lg 断点：barPosition Start + tabItem 横向 | 改 |
| `pages/home/HomePage.ets` | 套容器；lg 三卡横排 | 改 |
| `pages/account/AccountReportPage.ets` | 套容器；lg 图表明细分栏 | 改 |
| `pages/countdown/*.ets`（3 页） | 套容器 | 改 |
| `pages/pomodoro/*.ets`（2 页） | 套容器 | 改 |
| `pages/account/AccountPage.ets / AccountManagePage.ets` | 套容器 | 改 |
| `pages/settings/*.ets`（2 页） | 套容器 | 改 |
| `module.json5` | deviceTypes + tablet + 2in1 | 改（人工核验区） |

## 4. 手表端 module（wearable/）文件清单

```
wearable/
├── module.json5                  # type: entry, deviceTypes: ["wearable"]
└── src/main/ets/
    ├── entryability/EntryAbility.ets        # 仅初始化 DB + AppContextHolder
    ├── pages/
    │   ├── WatchMainPage.ets                # 单栏 Swiper 容器（3 屏滑动）
    │   ├── WatchOverviewPage.ets            # 宠物 + 今日收支
    │   ├── WatchQuickAddPage.ets            # 金额/方向/分类/保存
    │   └── WatchCountdownPage.ets           # 倒数日列表
    ├── viewmodel/WatchViewModel.ets         # 精简聚合（复用仓储）
    ├── data/  service/  common/             # 复制基础层（决策 8）
    └── resources/                           # 手表端 string/color（精简版）
```

- 快记保存同样走 PetEngine.addExp(1) + touchActive（无卡片推送——手表无 PetCardService）
- 默认账户初始化复用 AccountRepository.initDefaultsIfEmpty

## 5. 复用与复制边界（决策 8 明细）

| 层 | 文件 | 手表端 |
|---|---|---|
| 复制 | DateUtils / MoneyUtils / DatabaseHelper / Account·Transaction·CountdownEvent·PomodoroSession·PetState 模型 / Account·Transaction·Countdown 仓储 / PetEngine / AppContextHolder | 原样复制，改 import 路径 |
| 不复制 | PetCardService / ReminderService / PomodoroEngine / DataResetService / ReportUtils / 全部 ViewModel / 全部页面 | — |

> 复制文件头部加注释「与 entry module 同步维护，V1.0 抽 HAR 后删除」

## 6. 资源与配置

- entry/module.json5：deviceTypes → ["phone", "tablet", "2in1"]
- wearable/module.json5：新建（bundleName 同包，仅通知权限都不申请——手表端无提醒）
- build-profile.json5：modules 数组注册 wearable module（人工核验区）
- 手表端资源：独立精简 string.json/color.json（复用同名 key，值相同）

## 7. 验收清单（合入前逐项打勾）

- [ ] 手机端（xs）四大模块回归：布局与 W5 完全一致，零变化
- [ ] 平板/PC（lg）：左侧导航、内容居中限宽、首页三卡横排、报表左右分栏
- [ ] 窗口拖拽缩放（PC）：断点切换流畅无布局错乱
- [ ] 手表端三屏可用：概览数据正确 / 快记保存后余额与概览刷新 / 倒数日天数正确
- [ ] 手表端首启自动初始化默认账户；快记后宠物 exp+1
- [ ] 四端各自编译通过（phone/tablet/2in1 同包 + wearable 包）
- [ ] 深浅色模式四端无视觉事故

## 8. 里程碑影响（07 文档 W6 行修订建议）

- W6 增加「四端适配回归 + 四端上架包」；手表端若模拟器验证受阻，按缓冲策略砍手表（保三端），**不动上架日期**
- 09 决策日志补 D-010：四端 MVP 同发（老板 2026-07-26 拍板），数据各端独立为已知取舍

## 9. 风险与降级预案

| 风险 | 预案 |
|---|---|
| Tabs barPosition Start 在 lg 下样式怪异 | 降级：lg 保持底部导航 + 限宽容器（保底可用） |
| ResponsiveContainer 套层导致个别页面滚动失效 | 容器只限宽不干预滚动；问题页面单独退回直写布局 |
| 手表模拟器/DevEco wearable 支持不全 | 先编译通过 + 预览器验证；真机验证排 W6 后；最坏按 §8 砍手表 |
| wearable 端 RDB/preferences API 行为差异 | §10 假设清单核验；不一致则手表端降级为纯只读（砍掉快记） |
| 复制文件与 entry 漂移 | 文件头注释 + V1.0 抽 HAR 根治；本期改动需双写（接受） |

## 10. 假设 API 清单（人工核验后删除）

1. `windowStage.getMainWindow()` / `window.on('windowSizeChange')` 监听窗口尺寸（EntryAbility 注册）
2. wearable 设备上 `relationalStore.getRdbStore` / `preferences.getPreferencesSync` 与手机行为一致
3. Swiper 组件在 wearable 的垂直滑动导航可用
4. AGC 支持同一应用包发布 phone/tablet/2in1/wearable 多设备类型（W6 核验）

## 11. 签字

老板确认本 SPEC 后，Kimi Work 按 §3→§4 顺序施工（先三端自适应，后手表 module），完成后更新 06_AI_CONTEXT 状态表并提交推送。
