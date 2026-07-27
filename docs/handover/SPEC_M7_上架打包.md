# SPEC_M7 — 上架打包（MVP 最后一格）

- 版本：v1.1 ｜ 日期：2026-07-27 ｜ 状态：**决策 1/5 已签字（D-011），其余决策默认采纳；执行中**
- 前置：M6 四端核验通过（CHECKLIST_M6 A+B 区全过，CDE 区无阻塞项）
- 目标：**2026-09-07 内部上架锚点**（09 文档 R-02，激励截止 9/30 前留足审核缓冲）
- 关联：08_合规与上架.md（操作手册）、D-008（占位包名）、M6 §10-4（AGC 多设备类型）

---

## 1. 范围

| 做 | 不做 |
|---|---|
| 包名正式化、release 签名、版本配置定稿 | 任何新功能 |
| 四端（phone/tablet/2in1/wearable）单 App 包发布 | Pro 付费/云同步（V1.0） |
| 隐私政策 URL 上线、商店素材文案 | 闪控球白名单申请（V1.5 前置，上架后启动） |
| 审核提交与被拒响应预案 | 元服务/鲸鸿动能（V1.0 配套） |

## 2. 决策（签字即生效，逐条确认）

1. **正式包名**（✅ 已签字 D-011，2026-07-27）：`com.modestyma.banban`，vendor `ModestyMa`。已改 AppScope/app.json5 + SettingsPage 关于弹窗 + ReminderService BUNDLE_NAME 共 3 处。**AGC 创建应用必须同名，不可再改。**
2. **版本**：versionName 1.0.0 / versionCode 1000000 保持不变（DevEco 默认即合规）。
3. **签名**：AGC 自动生成发布证书 + Profile（推荐，免手动管理密钥）；DevEco 工程 signingConfigs 配置 release 签名（人工核验区，老板操作，Kimi Work 给步骤）。
4. **四端发布形态**：单一 App 包、设备类型勾选 phone + tablet + 2in1 + wearable（M6 §10-4 假设，AGC 创建应用时核验；不支持则降级为手表单独建第二个应用，包名加 `.watch`）。
5. **隐私政策 URL**（✅ 已签字 D-011，2026-07-27）：GitHub Pages 发布本仓库 `docs/privacy_policy.html` → `https://modestyma.github.io/BanBanDefense/privacy_policy.html`（要求仓库 public；若坚持 private 则改用 Gitee Pages，另行配置）。**联系邮箱已定稿 938632014@qq.com**，rawfile txt + html 两处已同步。
6. **应用名**：伴伴（查重备选「伴伴-倒数记账番茄」）；分类：实用工具。
7. **图标定稿**：SVG 爪印图标（本 SPEC 已随代码落地，PNG 已全部移除）；商店 1024×1024 大图由 SVG 导出 PNG（工具导出，非代码仓库交付物）。

## 3. 已完成执行项（Kimi Work，随本 SPEC 落地）

| 项 | 内容 |
|---|---|
| 图标 SVG 化 | entry 3 个 + AppScope 2 个 PNG → SVG（与 wearable 同款爪印设计），仓库从此无二进制缺口，另一台电脑 clone 即可构建 |
| 隐私政策网页 | `docs/privacy_policy.html`（内容与 App 内 rawfile 一致，风格化排版） |
| 包名正式化（S6 已完成） | `com.modestyma.banban` 全仓 3 处替换：AppScope/app.json5、SettingsPage 关于弹窗、ReminderService BUNDLE_NAME（本地 commit 5d7af05，远端抽查哈希一致） |
| 隐私政策邮箱（S7 已完成） | 938632014@qq.com 填入 rawfile txt + Pages html 两处 |

## 4. 老板人工执行清单（DevEco / AGC，按序）

### 4.1 AGC 侧（约 30 分钟）

- [ ] S1 开发者账号实名认证完成（个人开发者）
- [ ] S2 仓库设 public → Settings → Pages → Source: main /docs → 打开 `https://modestyma.github.io/BanBanDefense/privacy_policy.html` 多设备验证可访问
- [ ] S3 AGC 创建应用：名称「伴伴」，包名 `com.modestyma.banban`，分类实用工具
- [ ] S4 设备类型勾选核验（决策 4）：phone/tablet/2in1/wearable 能否同包
- [ ] S5 生成发布证书 + 发布 Profile（AGC 自动签名流程）

### 4.2 DevEco 侧（约 20 分钟）

- [x] ~~S6 正式包名定稿~~ 已完成（D-011，见 §3）
- [x] ~~S7 隐私政策联系邮箱~~ 已完成（D-011，见 §3）
- [ ] S8 DevEco → Build → Generate Key and CSR（或导入 AGC 证书）→ 配置 signingConfigs release
- [ ] S9 Build APP(s)（release）：出 .app 包
- [ ] S10 真机安装 release 包跑整包回归（07 文档清单 + CHECKLIST_M6 B 区）

### 4.3 商店素材（约 40 分钟，真机验证通过后）

- [ ] S11 图标 1024×1024 PNG（从 SVG 导出）
- [ ] S12 截图 ≥3 张：① 首页（宠物+三卡） ② 记账报表环形图 ③ 服务卡片宠物在桌面；加分项：④ 手表三屏 ⑤ PC 左侧导航
- [ ] S13 填写应用介绍（文案见 §5）、隐私政策 URL、权限说明话术（08 文档第二节，直接引用）
- [ ] S14 提交审核，记录提交时间（正常 1–7 工作日）

## 5. 商店文案（定稿可直接粘贴）

**一句话简介**（80 字内）：
> 倒数日 + 番茄钟 + 记账，一只陪你自律的桌面宠物。数据只存本地，永不联网。

**应用介绍**：
> 伴伴是一款融合倒数日、番茄钟与记账的个人效率应用，还有一只住在你桌面卡片里的宠物伴伴——记账、专注、打卡都会让它成长。
>
> 【三大件，刚刚好】倒数日提醒重要日子，番茄钟守住专注时间，记账理清每一分钱。
> 【桌面宠物调度中枢】服务卡片实时显示宠物心情与你的打卡状态，点卡片直达对应功能。
> 【隐私红线】不申请网络权限，全部数据只存在你的设备里。您的账单数据永远不会离开您的设备。可随时一键清除全部数据。
> 【四端随行】手机、平板、PC、手表同步发布，手表上也能一键快记。
>
> 本应用为个人记账工具，不涉及任何支付、理财、借贷服务。

**审核权限话术**（直接引用）：
> ohos.permission.PUBLISH_AGENT_REMINDER：用于用户主动创建的倒数日与专注计时提醒。

## 6. 验收清单（上架 = 全勾）

- [ ] release 包四端真机安装运行无崩溃（24h 观察）
- [ ] 包名/版本号/图标/应用名在关于页与系统设置中显示正确
- [ ] 隐私政策 URL 公网可访问且与 App 内版本一致（含联系邮箱）
- [ ] AGC 审核提交成功
- [ ] 审核通过后：开发者联盟后台核对激励计划报名状态（08 文档第五节，3000 元/款 + 月活 ≥400 口径记录）

## 7. 风险与降级预案

| 风险 | 预案 |
|---|---|
| AGC 不支持四端同包 | 决策 4 降级：手表单独建应用 `.watch`，主包先上架不动日期 |
| 审核被拒 | 按 08 文档第七节拒因表响应；记账误判金融类 → 引用应用介绍末句申诉 |
| GitHub Pages 不可用（仓库想保持 private） | Gitee Pages 镜像同一 html，30 分钟切换 |
| 激励名额被抢完（R-06） | 补贴是启动金非模式，不为此压缩审核质量 |
| 手表端真机验证受阻（M6 §9） | 砍手表保三端上架，手表随 V1.0 补发，不动上架日期 |

## 8. 假设 API / 人工核验清单

1. AGC 单 App 包支持 phone+tablet+2in1+wearable 多设备类型（S4 核验，源自 M6 §10-4）
2. SVG 图标在 release 签名打包流程中正常（S9 出包即知；DevEco 编译期已过则为真）
3. GitHub Pages 对 public 仓库即时生效（S2 核验）

## 9. 里程碑影响（07 文档 W6 行修订）

- W6 = 四端核验（CHECKLIST_M6）→ 上架打包（本 SPEC §4）→ 提交审核
- 审核等待期并行：V1.0 CSV 导入 SPEC 起草（不编码，先签字排队）

## 10. 签字

老板确认本 SPEC（重点：决策 1 包名 / 决策 5 Pages 方案）后，Kimi Work 执行 §3 已完成项的提交推送 + 老板 §4 人工项的逐步陪同；§4 每完成一步回填状态到 06_AI_CONTEXT。
