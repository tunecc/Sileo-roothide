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
