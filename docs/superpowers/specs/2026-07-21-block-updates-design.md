# 屏蔽更新（Block Updates）设计

**日期：** 2026-07-21  
**项目：** Sileo-roothide  
**状态：** 设计已确认，待实现计划  
**参考：** Saily `blockedUpdateTable`（仅借鉴思路，不照抄实现）

---

## 1. 背景与目标

### 1.1 问题

用户希望对某些已安装软件**不要被更新列表打扰**，常见动机：

- 新版本有回归 / beta 不稳定，想等下一版
- 某包永远不想再提示更新

### 1.2 现状（Sileo-roothide）

| 能力 | 现状 |
|------|------|
| 更新列表 | `PackageListManager.availableUpdates()` |
| dpkg Hold | 详情页「Ignore Updates」→ `DpkgWrapper.ignoreUpdates`；更新页「Ignored Updates」分区 |
| App 层屏蔽 | **无** |
| 全部更新 | `upgradeAll` 依赖 `availableUpdates()`，再滤 hold |

### 1.3 Saily 参考（差异点）

- Saily：`blockedUpdateTable: [String]`，按包 ID **永久**屏蔽；`obtainUpdateForPackage` 直接返回空
- 入口：包菜单 Block/Unblock + 设置已屏蔽列表
- **不支持**「只屏蔽此版本」

本功能在 Saily 之上增加**版本上限屏蔽**，UI 使用系统 Context Menu，数据模型不照抄 `[String]`。

### 1.4 目标

1. **永久屏蔽**：该包永不进入更新列表 / 角标 / 全部更新  
2. **屏蔽此版本（上限）**：候选版本 `≤ V` 时隐藏；出现**严格大于** `V` 的版本时重新提示  
3. 版本比较必须走 **dpkg 规则**（含 `~beta`、`-N`、hash revision 等）  
4. 与现有 dpkg Hold **并存且独立**，不写系统 hold  

### 1.5 非目标（首期）

- 同步 / 写入 dpkg hold  
- 更新页展示「已屏蔽」分区  
- 左滑快捷、批量多选  
- 导出 / 导入 / iCloud  
- 按源或架构屏蔽  
- 自动删除「已超过上限」的规则记录  
- 完整多语言（首期 Base + zh-Hans）  

---

## 2. 已确认需求决策

| 决策点 | 选择 |
|--------|------|
| 上限语义 | **B**：屏蔽到该版本及以下（`≤ V` 隐藏，`> V` 复活） |
| 模式 | **A**：双模式显式二选一（永久 / 上限） |
| 入口 | **ABCD**：更新列表、详情页、已安装列表、设置管理 |
| 列表主交互 | 长按 Context Menu（详情页菜单补齐） |
| 手动安装 | **A**：不拦截，仅过滤自动更新面 |
| 更新页呈现 | **A**：被屏蔽包装完全消失 |
| 与 dpkg | **A**：纯 App 层，不动 hold |
| 实现路线 | **方案 1**：`UpdateBlockManager` + 单点过滤 `availableUpdates()` |

---

## 3. 架构

```text
┌─────────────────────────────────────────────────────────┐
│  UI 入口                                                 │
│  · 更新/已安装列表 Context Menu                          │
│  · 包详情「更多」菜单                                     │
│  · 设置 → 已屏蔽更新管理页                                │
└───────────────────────────┬─────────────────────────────┘
                            │ 读写规则
                            ▼
┌─────────────────────────────────────────────────────────┐
│  UpdateBlockManager（单例，对齐 WishListManager 风格）     │
│  · rules: [packageID → UpdateBlockRule]                 │
│  · isUpdateBlocked(id, candidateVersion) → Bool         │
│  · UserDefaults 持久化 + didChange 通知                  │
└───────────────────────────┬─────────────────────────────┘
                            │ 查询
                            ▼
┌─────────────────────────────────────────────────────────┐
│  PackageListManager.availableUpdates()                   │
│  … checkRootHide / dpkg 版本比较 …                       │
│  + UpdateBlockManager 过滤（新增唯一过滤点）               │
└───────────────────────────┬─────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
  更新列表 / 分区      角标数量              upgradeAll
  （再滤 hold）
```

**原则：** 屏蔽判定只在 `availableUpdates()` 一处生效；角标与全部更新自动一致。手动加入下载队列 / 详情点更新 **不**二次拦截。

---

## 4. 数据模型与持久化

### 4.1 类型

```swift
enum UpdateBlockMode: String, Codable {
    case permanent   // 永久屏蔽该包所有更新提示
    case maxVersion  // 屏蔽候选版本 ≤ 记录版本
}

struct UpdateBlockRule: Codable, Equatable {
    var packageID: String        // 包 identity（写入时规范化）
    var mode: UpdateBlockMode
    var maxVersion: String?      // mode == .maxVersion 时必填
    var createdAt: Date          // 管理列表排序 / 展示
}
```

- 一包一条规则；新写入覆盖旧规则  
- `displayName` 等缓存字段可选，**不作为判定依据**（首期可不存）

### 4.2 存储

| 项 | 约定 |
|----|------|
| 介质 | `UserDefaults` |
| Key | `UpdateBlockRules`（实现时可微调，保持单一 key） |
| 格式 | 编码后的 `[UpdateBlockRule]`（JSON 或 PropertyList） |
| 内存 | `packageID → rule` 字典，O(1) 查询 |
| 风格 | 对齐 `WishListManager`：`shared`、reload、变更通知 |

### 4.3 判定 API（唯一真相源）

```text
isUpdateBlocked(packageID, candidateVersion) -> Bool

  permanent        → true
  maxVersion(V)    → NOT DpkgWrapper.isVersion(candidateVersion, greaterThan: V)
                     // 即 candidate ≤ V 时屏蔽；严格 > V 时不屏蔽
  无规则           → false
```

版本比较**强制**使用：

```swift
DpkgWrapper.isVersion(_:greaterThan:)
```

禁止字符串比较或自写版本解析。

### 4.4 写入语义

| 操作 | 行为 |
|------|------|
| 永久屏蔽 | 写入/覆盖为 `permanent` |
| 屏蔽此版本 `V` | 写入 `maxVersion = V`（覆盖旧规则） |
| 取消屏蔽 | 删除该 `packageID` |
| 清空全部 | 清空表并通知 |
| 空 packageID | 拒绝写入 |
| maxVersion 模式但版本缺失 | 视为无效；读入时剔除，不屏蔽 |

### 4.5 通知

`UpdateBlockManager.didChangeNotification`（命名实现时对齐项目习惯）。  
监听方：更新列表、角标刷新路径、设置管理页。

### 4.6 线程

`availableUpdates()` 可能在后台队列调用；`isUpdateBlocked` 与规则读写需线程安全（串行队列或读写锁）。

---

## 5. 过滤链路

### 5.1 插入点

在 `PackageListManager.availableUpdates()` 内，已通过「有更新 + checkRootHide + 候选 > 已装」之后：

```text
if UpdateBlockManager.shared.isUpdateBlocked(
     packageID: package.package,
     candidateVersion: latestPackage.version
   ) { continue }
```

### 5.2 下游（无需再滤）

| 消费方 | 效果 |
|--------|------|
| 更新列表 `availableUpdates` 数组 | 被屏蔽包装不出现 |
| 角标 `badgeValue` / `applicationIconBadgeNumber` | 数量自动减少 |
| `upgradeAll` | 不会排队被屏蔽包 |

### 5.3 与 dpkg Hold 的顺序

```text
availableUpdates()
  → 已滤 App 屏蔽
  → UI / upgradeAll 再按 wantInfo == .hold 分成「可更新」与「Ignored Updates」
```

| 状态 | 更新页 |
|------|--------|
| 仅 App 屏蔽 | 完全不出现 |
| 仅 hold | 进 Ignored Updates（现有行为） |
| 两者皆有 | 完全不出现（App 屏蔽优先） |

### 5.4 上限规则「自动复活」

无定时器、无状态迁移：

1. 用户屏蔽上限到 `V`  
2. 源刷新后候选变为 `V'`  
3. 若 `V' > V`（dpkg 序）→ `isUpdateBlocked == false` → 重新进列表  
4. **规则记录保留**在设置页（首期不自动删除）

### 5.5 失败策略

| 情况 | 行为 |
|------|------|
| UserDefaults 损坏 | 空表启动，不崩溃 |
| 版本比较异常 | **fail-open：不屏蔽**（避免误伤合法更新） |

### 5.6 明确不拦截

- 详情页 / 队列手动安装、更新、降级  
- `DownloadManager` 二次过滤  
- apt/dpkg 系统解析层  

---

## 6. UI 设计

### 6.1 列表：长按 Context Menu

`PackageListViewController` 已有 iOS 13+ context menu（`contextMenuConfigurationForItemAt` → `pvc.actions()`）。  
在 package actions 中增加屏蔽项（**不替换**现有 Hold）。

**未屏蔽：**

```
屏蔽更新…
  ├─ 永久屏蔽
  └─ 屏蔽此版本（显示候选版本字符串）
```

版本来源：

- **更新区**：候选（newest）版本  
- **已安装且无可用更新**：首期仅提供「永久屏蔽」，不展示「屏蔽此版本」  
- **有候选才显示上限项**

**已屏蔽：**

```
取消屏蔽更新
```

不出现：搜索历史 cell、非包 cell。

### 6.2 包详情页「更多」菜单

现有 action sheet 已有 Hold（`Package_Hold_Enable/Disable_Action`）与 Wishlist。  
在 Hold **下方**增加 App 屏蔽：

| 状态 | 菜单项 |
|------|--------|
| 未屏蔽 + 有候选更新 | `屏蔽更新…` → 二级：永久 / 屏蔽到 `V` |
| 未屏蔽 + 无候选 | `永久屏蔽更新` |
| 已屏蔽 | `取消屏蔽更新`（可附带规则说明） |

与 Hold 文案区分示例：

```
忽略更新（系统 Hold）   ← 现有 dpkg
屏蔽更新…               ← 新增 App 层
```

### 6.3 设置：已屏蔽更新管理

在 `SettingsViewController` 增加入口行（建议靠近现有开关区）：

```
已屏蔽更新    ›     // 副标题可选：数量
```

**BlockedUpdatesViewController：**

| 元素 | 行为 |
|------|------|
| 列表 | 按名称或 `createdAt`；显示包名/ID、规则（永久 / ≤ V） |
| 删除 / 左滑 | 取消该条 |
| 点击 | 能解析则打开包详情 |
| 导航栏清空 | 确认 alert 后清空全部 |
| 空态 | 「暂无屏蔽的更新」 |
| 幽灵包 | 已卸载仍显示 ID + 规则，可删 |

### 6.4 反馈

- 屏蔽 / 取消后：列表与角标即时刷新；可选 haptic  
- 不强制 toast（保持 Sileo 克制风格）  
- 统一发 `didChange` 通知  

### 6.5 本地化

首期：

- `Sileo/Base.lproj/Localizable.strings`  
- `Sileo/zh-Hans.lproj/Localizable.strings`  

其余语言可后续 Crowdin。Key 命名建议前缀 `Block_Update_` / `Package_Block_Update_`（实现时与现有 `Package_Hold_*` 并列）。

### 6.6 首期不做的 UI

- 左滑快捷屏蔽  
- 批量多选  
- 更新页「已屏蔽」分区  
- 合并或改写 Hold 文案语义  

---

## 7. 版本比较与验收用例

必须覆盖用户提供的版本形态，且以 dpkg 序为准：

```
1.1.3-4~beta1
1.1.3-4~beta2
1.1.3-3
1.1.3-1
1.1.3
1.1.2-2
1.1.2
1.1.1
1.1-3.d70eeb3-3
1.1-1.a4591ae-2
```

预期关系示例（实现验收）：

```
1.1.3-4~beta1  <  1.1.3-4~beta2  <  1.1.3-4  <  1.1.3-5
```

`1.1-3.d70eeb3-3` 与 `1.1-1.a4591ae-2` 的相对序以 `DpkgWrapper.isVersion` 结果为准，测试中断言与之一致即可。

**场景断言：**

1. 屏蔽上限到 `1.1.3-4~beta2` 后，候选 `1.1.3-4~beta2` / `1.1.3-4~beta1` → 隐藏  
2. 候选变为 `1.1.3-4`（正式）→ 重新显示  
3. 永久屏蔽后任意更高版本 → 仍隐藏  

---

## 8. 边界情况汇总

| 场景 | 预期 |
|------|------|
| 永久 + 更高候选 | 仍隐藏 |
| 上限 + 候选 ≤ V | 隐藏 |
| 上限 + 候选 > V | 列表复活；规则仍在设置中 |
| 模式切换 | 覆盖为新规则 |
| 仅 hold | Ignored Updates 不变 |
| hold + App 屏蔽 | 更新页两侧都不出现 |
| 手动更新 | 不拦截 |
| upgradeAll | 不含被屏蔽包 |
| 卸载后规则 | 设置幽灵项，可删 |
| 重装同 ID | 规则仍生效 |
| 多源同 ID | 按 packageID，不按源 |
| 比较失败 | fail-open 不屏蔽 |
| 模拟器 | App 层表可读写；Hold 仍受现有 `#if` 限制 |

---

## 9. 成功标准

1. 更新列表长按可永久或按版本上限屏蔽，包立即从列表与角标消失  
2. 上限屏蔽仅在候选**严格大于** `V` 时复活  
3. 详情页更多菜单可屏蔽 / 取消  
4. 已安装列表可永久屏蔽（无候选时无上限项）  
5. 设置可查看、单删、清空  
6. 手动安装 / 更新不被拦截  
7. Hold 与 App 屏蔽独立，文案可区分  
8. `upgradeAll` 不包含被屏蔽包  
9. 复杂版本号行为符合 dpkg 序  

---

## 10. 主要改动面（实现参考）

| 区域 | 改动 |
|------|------|
| 新建 | `UpdateBlockManager`（+ rule 模型，可同文件） |
| 新建 | `BlockedUpdatesViewController` |
| 修改 | `PackageListManager.availableUpdates()` |
| 修改 | Package actions / Context Menu 菜单源 |
| 修改 | `PackageViewController` 更多菜单 |
| 修改 | `SettingsViewController` 入口 |
| 修改 | `Localizable.strings`（Base、zh-Hans） |
| 工程 | 新文件加入 Xcode target |

---

## 11. 风险与缓解

| 风险 | 缓解 |
|------|------|
| Hold 与 App 屏蔽混淆 | 菜单文案区分；设置页可一行说明 |
| 漏过滤导致 upgradeAll 仍装上 | 只改 `availableUpdates()`；upgradeAll 已依赖它 |
| 版本比较用错 | 强制 `DpkgWrapper.isVersion` + 第 7 节用例 |
| Context Menu 与详情逻辑分叉 | 共用 Manager API + 组装菜单的小组件/函数 |
| fail-open 漏屏蔽 | 可接受；优先避免误杀更新 |

---

## 12. 实现顺序建议（供 writing-plans 展开）

1. `UpdateBlockManager` + 持久化 + 通知 + 线程安全  
2. `availableUpdates()` 接入过滤  
3. 详情页菜单  
4. 列表 Context Menu  
5. 设置管理页  
6. 本地化  
7. 版本序与集成验收  

---

## 13. 文档修订记录

| 日期 | 说明 |
|------|------|
| 2026-07-21 | 初版：brainstorming 确认后落盘 |
