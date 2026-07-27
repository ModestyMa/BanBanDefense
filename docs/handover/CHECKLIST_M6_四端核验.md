# CHECKLIST M6 — 四端编译与运行核验清单

- 版本：v1.0 ｜ 日期：2026-07-27 ｜ 维护：老板逐项打勾，Kimi Work 逐项消问题
- 用法：在 DevEco Studio 里按 A→F 顺序做。**任何一项失败：不要自己改代码**，把「报错原文 + 失败项编号」贴回对话，Kimi Work 修复后重推 GitHub。
- 关联：SPEC_M6_四端适配.md §7（验收标准）/ §9（降级预案）/ §10（假设 API 清单）

---

## 0. 前置准备（必做，否则编译必挂）

- [x] ~~0-1 手动补 PNG 图标~~ **已作废（2026-07-27）**：图标全面 SVG 化并推送，`git pull` 即可获得全部图标资源，无需任何手动拷贝
- [ ] 0-2 检查根 `build-profile.json5` 的 modules 数组含 `entry` + `wearable` 两个 module
- [ ] 0-3 DevEco 打开工程后先 **Build → Clean Project**，再 **Sync Now**（同步 hvigor）

---

## A. 编译核验（假设 API 清单，SPEC §10）

编译命令：直接 **Build → Build Hap(s)/APP(s) → Build APP(s)**，phone/tablet/2in1 与 wearable 应各出包。

- [ ] A-1 `windowStage.getMainWindow()` / `window.on('windowSizeChange')`（EntryAbility.ets）编译通过
- [ ] A-2 `display.getDefaultDisplaySync()`（EntryAbility 首帧断点判断）编译通过
- [ ] A-3 `@BuilderParam` 默认值写法、`@StorageLink` 在 @ComponentV2 组件中编译通过（ResponsiveContainer.ets / MainPage.ets）
- [ ] A-4 Tabs `.vertical()` + `barPosition: BarPosition.Start` 编译通过（MainPage.ets，PC 左侧导航）
- [ ] A-5 wearable module 的 `relationalStore.getRdbStore` / `preferences.getPreferencesSync` 编译通过（手表端 DatabaseHelper）
- [ ] A-6 Swiper `.vertical(true)` 编译通过（WatchMainPage.ets）
- [ ] A-7 手表 SVG 图标编译通过：`wearable/src/main/resources/base/media/*.svg` + `layered_image.json`
- [ ] A-8 四端各自编译出包成功（entry 包覆盖 phone/tablet/2in1 + wearable 包）

> 编译全过 → 进入运行核验；编译报错 → 贴报错原文给我，通常 1 轮内修掉。

---

## B. 手机端回归（xs，<640vp）—— 硬指标：与 W5 零变化

用 Previewer（phone）或手机模拟器/真机，逐项对照改动前：

- [ ] B-1 首页 4 Tab（首页/倒数日/番茄/记账）在**底部**，样式与之前一致
- [ ] B-2 首页三卡仍为**竖排**（宠物卡 → 今日番茄 → 本月收支），无横排、无居中限宽
- [ ] B-3 点「首页」Tab 进首页（不进记账）——历史问题复核
- [ ] B-4 倒数日：列表/新增/编辑/删除、超 3 个提示「Pro 即将上线」
- [ ] B-5 番茄钟：开始/暂停/完成，完成 1 个 exp +2
- [ ] B-6 记账：记 1 笔 exp +1、余额变动正确；记账报表页布局正常
- [ ] B-7 设置页：隐私政策可打开；清除全部数据可用
- [ ] B-8 记账浮层（页面内浮层降级版）弹出/关闭/保存正常

## C. 平板端（md/lg，640–840vp 及 ≥840vp）

用 Previewer 切 tablet，或平板模拟器：

- [ ] C-1 导航形态正确（按 SPEC：宽屏转左侧竖排导航）
- [ ] C-2 内容居中限宽（最大 640vp），两侧留白均匀，不拉伸变形
- [ ] C-3 首页三卡横排（lg 下），卡片等高、间距正常
- [ ] C-4 记账报表左右分栏（lg 下），无重叠无溢出
- [ ] C-5 各页面滚动正常（ResponsiveContainer 不得吞滚动）

## D. PC 端（2in1，窗口可拖拽）

用 2in1 设备模拟器（或平板模拟器开自由多窗）：

- [ ] D-1 左侧竖排导航可用，4 Tab 切换正常
- [ ] D-2 **拖拽窗口边缘缩放**，跨过 640vp / 840vp 两个断点时布局切换流畅、无错乱、无闪烁死循环
- [ ] D-3 窗口拖到最窄（<640vp）时回到手机式底部导航布局
- [ ] D-4 窗口拖宽后首页三卡横排、报表分栏正确出现

> 若 D-1/D-2 左侧导航样式怪异：按 SPEC §9 已定预案降级为「宽屏保持底部导航 + 限宽容器」，告诉我即可，不重开方案。

## E. 手表端（wearable 模拟器）

- [ ] E-1 三屏竖滑切换正常：概览 → 快记 → 倒数日（Swiper vertical）
- [ ] E-2 首启自动初始化默认账户（概览页有数据而非全空）
- [ ] E-3 概览页：宠物状态 + 今日收支数字正确
- [ ] E-4 快记页：输入金额、选方向/分类、保存成功；保存后余额与概览刷新
- [ ] E-5 快记 1 笔后宠物 exp +1（回概览页看等级/经验变化）
- [ ] E-6 倒数日页：列表天数计算正确

> 若 E-4 保存报错（手表 RDB 行为差异）：按 SPEC §9 降级为手表纯只读（砍快记），告诉我确认即可。

## F. 深浅色模式

- [ ] F-1 手机端深/浅切换无视觉事故（重点看卡片底色与文字对比度）
- [ ] F-2 平板/PC 深/浅切换正常
- [ ] F-3 手表端深色默认正常

---

## 结果回报格式（照这个贴，我修得最快）

```
核验环境：DevEco 版本 / 模拟器 or 真机 / 设备类型
失败项编号：如 A-3、D-2
现象：（一句话）
报错原文：（编译窗口或 Log 原文，整段贴）
```

## 通过判定

- A 区全过 + B 区全过 = 可继续主线（手机端没改坏是底线）
- C/D/E/F 有单项不过 → 先按 §9 降级预案走，不阻塞；修复排到整包回归
- 全部通过 → 07 文档 W6 行勾掉「四端适配」，MVP 只剩「上架打包」
