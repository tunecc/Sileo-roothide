---
comet_change: swap-umbra-patcher
role: technical-design
canonical_spec: openspec
archived-with: 2026-10-19-swap-umbra-patcher
status: final
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
