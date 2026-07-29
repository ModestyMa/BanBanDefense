# 伴伴 C1+C2+C3 特色 mini-SPEC（V1.0）

- 角色：产品策划（签字方：老板，2026-07-30）
- 依据：`work/docs/特色提案.md` §五（已签字：完整版 C1+C2+C3 全部进 V1.0）
- 硬约束（来自 `docs/handover/06_AI_CONTEXT.md`）：
  - 联动规则**只写 `service/PetEngine.ets`**（§6 铁律）
  - 所有用户可见字符串**必须 `$r()` 资源**，禁止硬编码
  - 禁 `any` / `unknown` / 解构；状态管理 V2（`@ObservedV2`/`@Trace`）
  - 不引入网络权限、不引入第三方依赖、不新增数据库表
  - 单项 ≤3 主程序人日，8/14 冻结前完成 + 回归

---

## 〇、资源约定（所有文案入 `resources/base/string.json`）

本文档中所有 `pet_speech_*`、`privacy_*`、`pet_clock_*` 字符串 key 均由产品侧提供文案，主程序只负责接 `$r()`。带 `{0}`/`{1}` 的用 `resourceManager.getStringSync($r('...'), [param])` 渲染。

---

## 一、C1 宠物碎碎念（2 人日）

### 1.1 目标
宠物根据本地行为数据说一句话，让"四合一"价值被感知。出现在两处：首页宠物区气泡、2×4 卡片文案行。

### 1.2 数据结构（禁 any，明确类型）

在 `PetEngine.ets` 新增：

```typescript
/** 碎碎念结果：最终渲染文案 + 配套表情 */
export interface PetSpeech {
  text: string;   // 已渲染的最终本地化文案（来自 $r 资源 + 参数）
  emoji: string;  // 气泡前缀表情
}
```

### 1.3 核心接口（逻辑只进 PetEngine）

```typescript
static async getPetSpeech(): Promise<PetSpeech>
```

内部聚合来源（均为本地库读，无网络）：
- `PetRepository.getOrCreate()` → `mood`、`streakDays`、`lastActiveDate`
- `PomodoroRepository.listSince(today)` → 今日 `focusMinutes`、`focusCount`
- `TransactionRepository.listByRange(today, today+DAY_MS)` → 今日 `billCount`（出+入）
- `TransactionRepository` 最近一笔（用于判断"几天没记账"）→ `lastTxDate`
- `CountdownRepository.listAll()` → 最近未来事件 `cdDays`、`cdTitle`
- `new Date().getHours()` → `hour`

### 1.4 触发优先级与文案表（从高到低，命中即返回）

| 优先级 | 触发条件 | 文案 key | 渲染结果示例 | emoji |
|---|---|---|---|---|
| 1 | `hour >= 23 \|\| hour < 6` | `pet_speech_night` | 夜深了，明天再战～ | 🌙 |
| 2 | `focusCount > 0` | `pet_speech_focus` | 陪你专注了 {0} 分钟，我骄傲！ | 💪 |
| 3 | `cdDays >= 0 && cdDays <= 3` | `pet_speech_countdown` | 『{0}』还有 {1} 天，别忘了哦 | 📅 |
| 4 | 今日 `billCount > 0` | 已记账（见下） | 今天的账都记好啦～ | 💰 |
| 5 | 今日 `billCount == 0` 且距 `lastTxDate` ≥ 3 天 | `pet_speech_no_bill` | 钱包最近过得怎么样呀？ | 🐱 |
| 6 | `streakDays >= 7` | `pet_speech_streak` | 我们已经连续 {0} 天见面啦！ | 🎉 |
| 7 | `mood == 0` | `pet_speech_mood_happy` | 今天也要加油呀！ | 😺 |
| 7 | `mood == 1` | `pet_speech_mood_normal` | 在等你来玩呢～ | 😼 |
| 7 | `mood == 2` | `pet_speech_mood_sad` | 喵？想我了没 | 🙀 |

默认兜底（任何异常）：返回 `pet_speech_default`「今天也要加油呀！」+ 😺，不得抛错中断 UI。

> 优先级说明：深夜 > 刚专注 > 临近倒数日 > 已记账 > 久未记账 > 长连续 > 心情兜底。这样无论用户当天做了什么，宠物都有"在关心你"的话可说。

### 1.5 文案资源清单（产品侧提供，入 string.json）

```
pet_speech_night       = 夜深了，明天再战～
pet_speech_focus       = 陪你专注了 %1$s 分钟，我骄傲！   （%1$s = focusMinutes）
pet_speech_countdown   = 『%1$s』还有 %2$s 天，别忘了哦      （%1$s = cdTitle, %2$s = cdDays）
pet_speech_billed      = 今天的账都记好啦～
pet_speech_no_bill     = 钱包最近过得怎么样呀？
pet_speech_streak      = 我们已经连续 %1$s 天见面啦！       （%1$s = streakDays）
pet_speech_mood_happy  = 今天也要加油呀！
pet_speech_mood_normal = 在等你来玩呢～
pet_speech_mood_sad    = 喵？想我了没
pet_speech_default     = 今天也要加油呀！
```

### 1.6 UI 改动点

1. **首页宠物区**（`pages/home/HomePage.ets` `petCard()`）：表情下方加一行气泡 `Text`，内容来自 `homeVM.petSpeechText` + `homeVM.petSpeechEmoji`。
2. **HomeViewModel**：`aboutToAppear`/`load()` 内调用 `PetEngine.getPetSpeech()` 填充新增 `@Trace petSpeechText: string` 与 `@Trace petSpeechEmoji: string`（默认空串，加载失败不显示气泡）。
3. **卡片 2×4**（`FormExtensionAbility` 卡片 UI）：在现有三档表情下方加一行文案（复用同一 `getPetSpeech()` 结果）。卡片刷新时机沿用既有"1 分钟内心情刷新"通道，不新增定时任务。
4. 卡片 2×2 空间不足，**不加**文案（仅首页 + 2×4 卡片）。

### 1.7 验收
- [ ] `getPetSpeech()` 在 PetEngine 内实现，无 any/unknown
- [ ] 首页气泡与卡片文案均来自 `$r()` 渲染，无硬编码
- [ ] 模拟"今日记账后打开""临近倒数日""深夜打开"三种场景，文案正确切换
- [ ] 异常时不崩溃、有兜底文案

---

## 二、C2 零联网隐私徽章 + 隐私宣言页（1 人日）

### 2.1 目标
把"零网络权限"从 README 卖点变成产品内可见资产 + 商店首图素材。

### 2.2 交付物

#### 2.2.1 隐私宣言页（新页面 `pages/settings/PrivacyManifestPage.ets`）
- 静态页，无逻辑。内容来自 `$r()` 资源：
  - 标题：`privacy_manifest_title` = 伴伴的隐私承诺
  - 正文段落（多条 `privacy_manifest_p1` ~ `p4`）：
    - p1：伴伴没有任何网络权限。你的账单、专注记录、纪念日，从未离开这台设备。
    - p2：我们不做账号、不上云、不卖数据、不推广告。
    - p3：不信？打开系统的「设置 → 应用 → 伴伴 → 权限」，你会看到列表里只有通知。
    - p4：你的数据，永远只属于你。
  - 配一个徽章样式（见 2.2.3）。

#### 2.2.2 设置页入口（`pages/settings/SettingsPage.ets`）
- 顶部加一行入口「隐私承诺」→ 跳转 `PrivacyManifestPage`。文案 `settings_privacy_promise`。

#### 2.2.3 徽章组件（静态 `@Builder`，可复用）
- 样式：圆角胶囊 + 🛡 图标 + 文字 `badge_zero_network` = 0 网络权限。
- 使用位置：关于页顶部、首启隐私弹窗（`MainPage.ets` 的 `PrivacyDialog`）、商店首图（由 T11 上架专员引用文案）。

### 2.3 文案资源清单
```
privacy_manifest_title   = 伴伴的隐私承诺
privacy_manifest_p1      = 伴伴没有任何网络权限。你的账单、专注记录、纪念日，从未离开这台设备。
privacy_manifest_p2      = 我们不做账号、不上云、不卖数据、不推广告。
privacy_manifest_p3      = 不信？打开系统的「设置 → 应用 → 伴伴 → 权限」，你会看到列表里只有通知。
privacy_manifest_p4      = 你的数据，永远只属于你。
settings_privacy_promise = 隐私承诺
badge_zero_network       = 0 网络权限
```

### 2.4 验收
- [ ] 隐私宣言页可达（设置页入口点击进入）
- [ ] 徽章样式在关于页/首启弹窗正确显示，文字来自 `$r()`
- [ ] 宣言措辞与 `PrivacyPolicyPage.ets` 现有隐私政策一致（不冲突）

---

## 三、C3 宠物作息钟（2.5 人日）

### 3.1 目标
宠物卡片按真实时间切换状态，让卡片"活"起来，形成记忆点。

### 3.2 时段规则（新增 `PetEngine` 纯函数）

```typescript
/** 时段枚举（禁 any，明确 const 字面量） */
export enum PetTimeOfDay {
  SLEEP = 0,    // 睡觉 00:00–05:59
  MORNING = 1,  // 早安 06:00–08:59
  DAY = 2,      // 白天 09:00–22:59
  NIGHT = 3     // 准备睡 23:00–23:59
}

static timeOfDayFromHour(hour: number): PetTimeOfDay
```

### 3.3 表情映射（叠加在现有 mood 之上）

| 时段 | 表情 emoji | 说明 |
|---|---|---|
| SLEEP | 😴 | 睡觉 Zzz；**此时段 mood 不降级**，永远显示睡觉态 |
| MORNING | 🌞 | 伸懒腰/早安 |
| DAY | 沿用现有 mood 三档（😺/😼/🙀） | 正常 |
| NIGHT | 🛏 | 准备睡 |

> 规则：SLEEP / NIGHT 时段**强制覆盖** mood 表情；MORNING 显示早安表情；DAY 沿用 mood。

### 3.4 卡片调度改动
- 卡片定时刷新逻辑（现有"1 分钟内心情刷新"通道）调用 `PetEngine.timeOfDayFromHour(new Date().getHours())` 叠加 mood，输出最终表情。
- 不新增 FormExtension 定时任务；复用现有刷新配额。

### 3.5 表情资源（C3 主要变数：美术素材）
- 需要 2–3 套新增表情图（睡觉/早安/准备睡），风格需与现有宠物一致。
- 若美术素材 8/9 前未就绪，**降级方案**：用系统 emoji（😴/🌞/🛏）代替自绘图，C3 仍可按 1.5 人日交付（逻辑 + emoji 版）。

### 3.6 文案资源（可选，早安/睡觉提示）
```
pet_clock_morning = 早安！新的一天开始啦～
pet_clock_sleep  = 嘘——我先睡啦，明天见
```
（可选择性在卡片/首页显示，非必须）

### 3.7 验收
- [ ] 23:00–6:00 卡片显示睡觉态，mood 不降级
- [ ] 6:00–9:00 显示早安态
- [ ] 9:00–23:00 沿用 mood 三档
- [ ] 真机验证时段切换刷新正常（系统刷新配额内）
- [ ] 降级（emoji 版）也能正确显示

---

## 四、联调与回归约束

1. **C2 → C1 → C3 顺序**：C2 最简单先收口（8/5–8/6），C1 主逻辑（8/7–8/9），C3 逻辑+素材并行（8/10–8/11）。
2. **共用通道**：C1 文案刷新与 C3 时段切换均复用现有卡片"1 分钟内心情刷新"机制，不新增定时任务。
3. **回归窗口**：8/12–8/14 留作特色回归 + 整包回归（T12），不挤占。
4. **冻结红线**：8/14 后不再新增任何代码；V1.0 深度功能（农历/CSV 导入/预算）按原路线图推进，不进本版。

---

*mini-SPEC 完。主程序凭此 SPEC 开工，无需等待产品侧另行说明。*
