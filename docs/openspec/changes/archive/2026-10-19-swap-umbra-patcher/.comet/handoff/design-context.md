# Comet Design Handoff

- Change: swap-umbra-patcher
- Phase: design
- Mode: compact
- Context hash: 9993a0703bcaceb27b8692fcc20e7a8721c591f4fdf05bb414c3ffff8ab5c59d

Generated-by: comet-handoff.sh
Task hash policy: task-content-v1. Read tasks.md for live completion; excerpts are design-time context.

OpenSpec remains the canonical capability spec. This handoff is a deterministic, source-traceable context pack, not an agent-authored summary.

## docs/openspec/changes/swap-umbra-patcher/proposal.md

- Source: docs/openspec/changes/swap-umbra-patcher/proposal.md
- Lines: 1-30
- SHA256: 061214a0ad90b42f8d6f15503fe5fba6b42cfbba2cbf568c0e42fe9ab196f5c2

```md
# Proposal

## Why

Sileo 当前把需要转换的 deb 分享给旧版 RootHide Patcher（`com.roothide.patcher`）。OwnGoal Studio 发布的 Umbra Patcher 3.0-1 使用新包 ID `wiki.qaq.umbra.patcher`，其 deb 声明 `Conflicts`/`Replaces: com.roothide.patcher`，安装时自动顶替旧包。若 Sileo 只认旧 ID，已迁移到 Umbra Patcher 的设备将检测不到 Patcher，掉回系统分享面板，转换流程中断。

## What Changes

- 在 `DownloadManager.swift` 中引入有序候选列表 `["wiki.qaq.umbra.patcher", "com.roothide.patcher"]`，作为 Patcher 检测的唯一来源；后期新增第三方 Patcher 只改这一处数组。
- `patchPackage`：按列表顺序找到第一个可用的 Patcher App（`IsAppAvailable`），把下载的 deb 分享给它；全部不可用则回退系统分享面板（保留现有行为）。
- `showPatchAlert`：按列表顺序找到第一个已安装的 Patcher 包（`installedPackage(identifier:)`），有则按钮显示 "Convert" 并直接下载转换；未装任何 Patcher 时，跳转 `sileo://package/wiki.qaq.umbra.patcher` 详情页；若新包在源中不可见（详情页无法打开），回退跳转旧包 `sileo://package/com.roothide.patcher`，两者都不可用时保留现有 alert（无跳转按钮的路径不变）。
- alert 文案按钮 "Get Patcher" / "Convert" 语义不变，不新增本地化字符串。
- 不移除对旧包的兼容：设备上仍装旧版 Patcher 且未升级的用户，转换流程不受影响。

## Capabilities

### New Capabilities

- `patcher-handoff`: Sileo 与外部 Patcher App 之间的检测、排序、deb 交接与安装引导行为。

### Modified Capabilities

（无既有 spec，本项目 specs 目录为空。）

## Impact

- 代码：`Sileo/Backend/Download Manager/DownloadManager.swift`（`patchPackage`、`showPatchAlert` 两段，共约 20 行改动）。
- API/依赖：无新增依赖；继续使用 `IsAppAvailable` / `ShareFileToApp`（`Sileo/Contrib/AppFileShare.m`）与 `PackageListManager.installedPackage`。
- 用户可见行为：装有任一 Patcher 的设备继续一键 Convert；已换装 Umbra Patcher 的设备恢复一键 Convert；两者皆未装时引导安装新包。
- 风险：Umbra Patcher 接受 deb 分享的入参方式与旧版一致（同一 `org.debian.deb-archive` 文档类型，`LSSupportsOpeningDocumentsInPlace: 0`），按 `AppFileShare` 的 LSApplicationWorkspace 分享路径验证。

```

## docs/openspec/changes/swap-umbra-patcher/design.md

- Source: docs/openspec/changes/swap-umbra-patcher/design.md
- Lines: 1-74
- SHA256: 5724be8e3f28e2aa2f93304e93abee92823b9d8e39addddbeabb7bd81b857d59

```md
---
comet_change: swap-umbra-patcher
role: technical-design
canonical_spec: openspec
---

# Design

## Context

Sileo 中 Patcher 相关逻辑全部集中在 `Sileo/Backend/Download Manager/DownloadManager.swift`：

- `patchPackage(package:fileURL:)`（约 774–802 行）：下载 deb 后 `IsAppAvailable("com.roothide.patcher")` → `ShareFileToApp` 直接交接，失败回退系统分享面板。
- `showPatchAlert()`（嵌套于 `add(package:queue:...)`，约 916–951 行）：检测 `installedPackage(identifier: "com.roothide.patcher")` 决定 "Convert" / "Get Patcher"，未装时跳 `sileo://package/com.roothide.patcher` 详情页。

交接通道为 `Sileo/Contrib/AppFileShare.m` 的 LSApplicationWorkspace 私有 API，按 bundle ID 寻址，与 App 的包 ID 无耦合。Umbra Patcher 3.0-1 的 deb 声明 `Conflicts`/`Replaces: com.roothide.patcher`（见 `/Users/tune/Downloads/RootHidePatcher/control`），系统在安装时自动卸载旧包，因此两个 Patcher 实际不会共存。Umbra Patcher 的 Info.plist 注册了同一文档类型 `org.debian.deb-archive`（`LSSupportsOpeningDocumentsInPlace: 0`），旧版分享路径对其同样成立。

用户已确认的决策：候选列表按序检测（新包优先、旧包兜底）；未装时沿用现有两态交互（Convert / Get Patcher 详情页）；工作区为当前目录。

## Goals / Non-Goals

**Goals:**

- 换装 Umbra Patcher 的设备恢复一键 Convert，无需改 Sileo 之外的东西
- 仍装旧版 Patcher 的设备行为完全不变
- 后续接入第三个 Patcher 时只改一处候选数组

**Non-Goals:**

- 不实现"检测到多个 Patcher 时弹选择框"——Conflicts/Replaces 保证不会双装，为不存在场景加 UI 属于过度设计
- 不改变警告弹窗的结构、文案键、按钮样式与特殊源（`apt.procurs.us` / `ellekit.space`）处理
- 不改动 `checkRootHide` / `checkRootlessV2` 等 roothide 支持检测路径
- 不新增本地化字符串或设置项

## Decisions

### D1. 模块级有序候选数组，而非散落的字符串常量

```swift
private static let patcherBundleIDs = [
    "wiki.qaq.umbra.patcher",   // Umbra Patcher
    "com.roothide.patcher",     // 旧版 roothide Patcher 兜底
]
```

放在 `DownloadManager` 内部 private static，`patchPackage` 与 `showPatchAlert` 共用同一顺序来源。

- 备选 A：直接把两处字符串替换成新 ID——最省事，但旧版用户回退能力丢失（未升级 Umbra 且卸了旧包的设备会直接掉到系统分享面板）。
- 备选 B：封装成独立 `PatcherRegistry` 类型——当前只有两个消费点、无状态，抽类型是提前抽象，违反周边代码的直写风格。

### D2. 检测均为"首次命中即停"，两个消费点各自独立遍历

- `patchPackage`：`patcherBundleIDs.first { IsAppAvailable($0) }`，命中即 `ShareFileToApp`；遍历完无命中 → 现有系统分享面板回退。
- `showPatchAlert`：`patcherBundleIDs.first { installedPackage(identifier: $0) != nil }`，命中 → "Convert"；未命中 → "Get Patcher" 跳新包详情页，详情页构建失败再尝试旧包 ID，两者都失败则维持现有"不添加跳转按钮"分支。

不需要"两个都检测再比较"的中间态：Conflicts/Replaces 使双装不可能，首中即最优。

### D3. 详情页跳转的回退实现

`URLManager.viewController(url:)` 对源中不存在的包会返回 nil（现有代码即依赖此行为处理旧包缺失）。因此按 `[新ID, 旧ID]` 顺序逐个尝试构建详情页，第一个成功者 present；全部失败走现有无按钮分支。不预先查询源列表——直接复用 URLManager 的判定，与现有代码路径一致。

## Risks / Trade-offs

- [Umbra Patcher 拒绝 LSApplicationWorkspace 分享（未注册 Scene/打开方式处理）] → 实现已确认其 Info.plist 声明了 `org.debian.deb-archive` 文档类型；Verify 阶段在真机以 Umbra 安装态实测 deb 交接，失败则保留系统分享面板回退，功能不劣化于现状。
- [候选数组遗漏未来第三方 Patcher] → 数组是唯一修改点，扩展成本低；spec 已固定"按序首中"语义。
- [旧包兜底长期存留形成死代码] → 可接受；待 Umbra 覆盖率确认后，后续 change 可移除旧 ID 项，spec 场景"仅安装旧版 Patcher"同步删除。

## Migration Plan

单文件改动，随 Sileo 正常发版。回滚即 revert 该文件。无数据迁移、无配置变更。

## Open Questions

无——跳转目标（新包详情页，失败回退旧包）已由用户确认。

```

## docs/openspec/changes/swap-umbra-patcher/tasks.md

- Source: docs/openspec/changes/swap-umbra-patcher/tasks.md
- Lines: 1-21
- SHA256: ec8ecf5fbe6e5f4247857ebe2ebeeec7a4b7671e95ea9cce7bfa720351283d6a

```md
# Tasks

## 1. 引入候选 Patcher 列表

- [ ] 1.1 在 `DownloadManager.swift` 内新增 `private static let patcherBundleIDs = ["wiki.qaq.umbra.patcher", "com.roothide.patcher"]`，注释标明顺序即优先级；验证：文件编译通过，两处消费点引用同一数组。

## 2. 改造 patchPackage 交接

- [ ] 2.1 将 `patchPackage` 中 `IsAppAvailable("com.roothide.patcher")` + `ShareFileToApp` 改为遍历 `patcherBundleIDs`，首个 `IsAppAvailable` 命中的 ID 作为分享目标；验证：源码阅读确认无硬编码旧 ID 残留，`ShareFileToApp` 使用循环内命中 ID。
- [ ] 2.2 确认全部候选不可用时仍回退系统分享面板（现有 `UIActivityViewController` 分支）；验证：阅读确认遍历后 fallback 路径与改动前一致。

## 3. 改造 showPatchAlert 安装引导

- [ ] 3.1 将 `installedPackage(identifier:)` 检测改为遍历 `patcherBundleIDs`，首个命中决定 "Convert"；验证：阅读确认检测不再硬编码旧 ID。
- [ ] 3.2 未装任何 Patcher 时，`Get Patcher` 跳转依次尝试新包 `wiki.qaq.umbra.patcher` 与旧包 `com.roothide.patcher` 的详情页，首个构建成功的 present；验证：阅读确认 fallback 顺序正确，全部失败时维持现有无跳转按钮分支。

## 4. 验证

- [ ] 4.1 运行构建（`xcodebuild` 模拟器 scheme 或 `comet check run build`）确认无编译错误；验证：构建命令 exit code 0。
- [ ] 4.2 对照 delta spec 五组场景逐一核对实现分支；验证：每个场景可落到对应代码分支，无遗漏。
- [ ] 4.3 真机实测（如有条件）：仅装 Umbra Patcher → 转换直接交接；仅装旧 Patcher → 行为不变；两者未装 → 跳新包详情页。验证：真机日志与用户可观察行为符合 spec。

```

## docs/openspec/changes/swap-umbra-patcher/.openspec.yaml

- Source: docs/openspec/changes/swap-umbra-patcher/.openspec.yaml
- Lines: 1-2
- SHA256: b552ab6519df8f66b705724100f565c5cd842bc9389aeaa177da9cec3d02a685

```md
schema: spec-driven
created: 2026-10-19

```

## docs/openspec/changes/swap-umbra-patcher/specs/patcher-handoff/spec.md

- Source: docs/openspec/changes/swap-umbra-patcher/specs/patcher-handoff/spec.md
- Lines: 1-51
- SHA256: 16e0c2e7aec8e9943ff72966515e3643ea4c4551211b78302fb2cb23ea531d6e

```md
# Spec Delta

## Purpose

规范 Sileo 与外部 Patcher App（Umbra Patcher / 旧版 RootHide Patcher）之间的检测优先级、deb 交接与安装引导行为，保证换装任一版本的 Patcher 后转换流程保持可用。

## ADDED Requirements

### Requirement: Patcher 候选优先级

Sileo 必须按固定有序列表检测 Patcher：依次为 `wiki.qaq.umbra.patcher`（Umbra Patcher）、`com.roothide.patcher`（旧版 RootHide Patcher）；列表中第一个满足条件的候选生效。

#### Scenario: 仅安装 Umbra Patcher
- **WHEN** 设备上只安装了 `wiki.qaq.umbra.patcher`
- **THEN** Sileo 将其识别为可用 Patcher，转换与交接均指向该 App

#### Scenario: 仅安装旧版 Patcher
- **WHEN** 设备上只安装了 `com.roothide.patcher`
- **THEN** Sileo 继续将其识别为可用 Patcher，行为与改动前一致

### Requirement: deb 交接

用户确认 Convert 后，Sileo 下载目标 deb 并交给候选列表中第一个可通过系统打开方式 API 分享的 Patcher App；分享失败或无可用 App 时回退系统分享面板。

#### Scenario: 可用 Patcher 存在
- **WHEN** 候选列表中存在已安装且分享成功的 Patcher
- **THEN** deb 文件直接交给该 Patcher，不弹出系统分享面板

#### Scenario: 无可用 Patcher App
- **WHEN** 候选列表中没有任何 App 可接受分享
- **THEN** 弹出系统分享面板，用户自行选择去向（现有回退行为）

### Requirement: 未安装时的安装引导

候选列表中没有任何已安装的 Patcher 时，警告弹窗的 "Get Patcher" 动作跳转 `sileo://package/wiki.qaq.umbra.patcher` 详情页；该详情页无法打开时回退 `sileo://package/com.roothide.patcher`。

#### Scenario: 两个 Patcher 均未安装
- **WHEN** 设备上未检测到任何候选 Patcher 包
- **THEN** "Get Patcher" 打开 Umbra Patcher 的包详情页；用户可从详情页安装

#### Scenario: 新包详情页不可达
- **WHEN** Umbra Patcher 不在当前源列表中、详情页无法构建
- **THEN** 回退打开旧版 `com.roothide.patcher` 详情页；仍不可达时不显示跳转按钮（保持现有约束）

### Requirement: 已装 Patcher 的直接转换

候选列表中存在已安装的 Patcher 包时，警告弹窗显示 "Convert" 按钮；点击后直接进入下载并交接流程，不再跳转详情页。

#### Scenario: 已安装任一 Patcher
- **WHEN** 候选列表中检测到已安装的 Patcher 包
- **THEN** 按钮显示 "Convert"，点击后下载 deb 并按交接要求交给对应 Patcher

```
