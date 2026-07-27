# 交接文档 — Qoder 接管伴伴 App 开发（必读）

- 版本：v1.0 ｜ 日期：2026-07-28 ｜ 依据决策：D-012
- 交接方：Kimi Work（编码退出一线，转文档维护与评审）
- 接管方：Qoder（Kimi Code / Qwen Code，全程编码执行）
- 验证方：老板本人（DevEco Studio 编译 / 真机 / AGC 上架）

---

## 0. 你（Qoder）每次开工前的固定动作

1. **重读 `docs/handover/06_AI_CONTEXT.md` 全文**——它是自我约束唯一权威源（事实、硬性禁令、数据模型、状态表、决策、坑）。
2. 重读本文件 §3「当前状态」与 §4「任务队列」，确认接手点。
3. 编码任务涉及哪个模块，再读对应 `docs/handover/` 下的 SPEC 与 CHECKLIST。
4. 开始写码。

> 注意：`docs/handover/` 是 2026-07-28 的冻结快照。老板本机 `伴伴App\` 目录是文档权威源；如有冲突，问老板哪份新。

## 1. 项目一句话

伴伴（BanBan）：HarmonyOS NEXT 融合效率 App（倒数日 + 番茄钟 + 资产记账 + 桌面服务卡片宠物），全部数据本地、零网络权限，MVP 四端同发（手机/平板/PC/手表），目标 2026-09-07 前上架华为应用市场（激励截止 9/30）。

## 2. 工程事实（速查）

| 项 | 值 |
|---|---|
| 工程根目录 | `C:\Users\User\Desktop\HarmanyOSAPP\BanBanDefense` |
| GitHub | `https://github.com/ModestyMa/BanBanDefense`，分支 `main` |
| bundleName | `com.modestyma.banban`（D-011 定稿，AGC 同名不可改） |
| SDK 基线 | compatibleSdkVersion / targetSdkVersion 6.1.0(API 23)，hvigor modelVersion 6.1.0 |
| module | `entry`（phone/tablet/2in1）+ `wearable`（手表，仅概览/快记/倒数日三屏） |
| 语言/UI | ArkTS 严格模式 + ArkUI 声明式，状态管理一律 V2 装饰器 |
| 数据 | @kit.ArkData relationalStore 本地库 6 张表；无网络权限 |
| 图标 | 全部 SVG（entry/AppScope/wearable 三处，爪印设计），仓库无二进制 |
| 隐私政策 | App 内 `entry/src/main/resources/rawfile/privacy_policy.txt`；网页版 `docs/privacy_policy.html`（GitHub Pages 用） |

## 3. 当前状态（2026-07-28 快照）

### 已完成（代码全部在 GitHub main）

- 数据底座、倒数日、番茄钟、服务卡片宠物、手动记账、首页聚合+设置/隐私页（M1–M5）
- M6 四端适配：三端断点自适应（<640 手机 / 640–840 / >840 PC 左侧导航）+ 手表 wearable module 三屏
- M7 代码侧：包名正式化、图标 SVG 化、隐私政策 txt + Pages html、邮箱定稿

### 验证状态（关键！）

| 端 | 状态 |
|---|---|
| 鸿蒙 PC（2in1） | ✅ entry 包已跑通（2026-07-28，曾误选 wearable 模块报 deviceType 不匹配） |
| 手机 | ⬜ 未回归（CHECKLIST_M6 B 区，**底线：与 W5 零视觉变化**） |
| 平板 | ⬜ 未核验（C 区） |
| 手表 | ⬜ 未核验（E 区；模拟器受阻可按预案砍手表保三端） |
| 深浅色 | ⬜ 未核验（F 区） |

**所有代码从未完整编译验证过。** 已知假设 API 清单见 SPEC_M6 §10，文件顶部注释也有 `// 假设API清单:` 标记。编译报错按清单回喂修。

### 老板侧待办（不是 Qoder 的活，别替老板点）

SPEC_M7 §4：AGC 实名/开 Pages/建应用/勾设备类型/生成证书（S1–S5）→ release 签名打包（S8–S10）→ 素材提审（S11–S14）。

## 4. 任务队列（按优先级）

1. **编译消错**：老板 DevEco 编译报错 → 按报错原文修 → 提交推送。先保 entry 编译通过，再保 wearable。
2. **手机端回归配合**：CHECKLIST_M6 B 区任何失败项的修复。
3. **平板/手表/深浅色问题修复**：按 SPEC_M6 §9 降级预案执行，不重开方案。
4. **release 打包配合**：S8–S10 中签名配置、构建报错的修复。
5. 上架后：V1.0 CSV 账单导入（SPEC 未写，等老板安排起草签字后再动）。

## 5. 硬性禁令（违反 = 老板拒收，全文见 06 §2）

- 禁 `any`/`unknown`、禁解构赋值、禁类实例当字面量传参
- 禁编造 API：不确定就写文件顶部 `// 假设API清单:` 注释
- 禁硬编码字符串/颜色/尺寸（一律 `$r('app.xxx')`），禁写死屏宽
- 页面不直连数据库（走 `data/repository/`）；联动规则只写 `service/PetEngine.ets`
- 状态管理 V2（@ObservedV2/@Trace/@Local/@Param/@Computed），同组件不混 V1
- 异步 async/await + try-catch；MVP 期禁第三方依赖
- **已签字决策不重开**（09 决策日志 D-001～D-012）：金额分整数、有流水禁删账户、4 Tab、宠物卡纯展示、浮层记账、四端同发、包名

## 6. 精选坑（全文见 06 §9）

- 本机 hvigor 只认 modelVersion 6.1.0（报 Unsupported 就三处版本对齐）
- 部署报「deviceType/apiVersion 不匹配」：先查 DevEco 运行配置选中的 module（wearable 包不能装手机/PC）
- 新建 module 必须带模块级 `hvigorfile.ts`
- 权限正确名 `ohos.permission.PUBLISH_AGENT_REMINDER`
- 卡片 UI 是 ArkTS 受限子集；reminderAgent 杀进程行为必须真机验证
- 支付宝 CSV 是 GBK 且前 ~25 行说明文字（V1.0 时注意）

## 7. 提交与推送规范

- Commit 格式：`[模块] 动作: 摘要 (by Qoder)`（对照 06 §5）
- 推送：直接 `git push origin main`（Qoder 环境网络可用则直连；不可用改走 GitHub MCP push_files 文本分批，二进制禁推——所以图标一律 SVG）
- 推完抽查：远端 blob SHA 对比 `git rev-parse HEAD:<path>`
- 每次验收完成后更新 06 §7 状态表（老板会同步权威源）

## 8. 文档地图

| 位置 | 内容 |
|---|---|
| `docs/handover/00_交接文档_QODER.md` | 本文件 |
| `docs/handover/06_AI_CONTEXT.md` | 编码自我约束权威源（每次开工重读） |
| `docs/handover/09_风险登记册与决策日志.md` | 全部已签字决策 D-001～D-012 |
| `docs/handover/07_里程碑与验收清单.md` | W1–W6 里程碑与整包回归清单 |
| `docs/handover/SPEC_M6_四端适配.md` + `CHECKLIST_M6_四端核验.md` | 当前验证期的规格与逐项清单 |
| `docs/handover/SPEC_M7_上架打包.md` | 上架决策、AGC 步骤、商店文案 |
| 老板本机 `伴伴App\`（不在仓库） | 01 商业计划书 / 02 PRD / 03 架构 / 04 工程规范 / 05 协作手册 / 08 合规——需要哪份找老板要 |
