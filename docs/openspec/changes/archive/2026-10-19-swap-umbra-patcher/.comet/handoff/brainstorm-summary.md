# Brainstorm Summary

- Change: swap-umbra-patcher
- Date: 2026-10-19

## 确认的技术方案

在 `DownloadManager.swift` 中引入模块级有序候选数组 `patcherBundleIDs = ["wiki.qaq.umbra.patcher", "com.roothide.patcher"]`，两个消费点按序检测、首中即停：

- `patchPackage`：`patcherBundleIDs.first { IsAppAvailable($0) }` 命中即 `ShareFileToApp`；全部不可用回退系统分享面板（现有行为）。
- `showPatchAlert`：`patcherBundleIDs.first { installedPackage(identifier:) != nil }` 命中显示 "Convert"；未装任何 Patcher 时 "Get Patcher" 依次尝试新旧包详情页，首个构建成功者 present，全部失败维持现有无按钮分支。

用户已确认：候选优先新包、回退旧包；未装时沿用现有两态交互（不弹选择框、不加设置项）；工作区 current。

## 关键取舍与风险

- Conflicts/Replaces 保证两 Patcher 不双装 → "首中即停"优于"检测多个弹选择框"（后者被用户否决）。
- 保留旧包兜底 → 未升级 Umbra 且卸了旧包的设备避免直接掉到系统分享面板。
- Umbra Patcher 拒绝 LSApplicationWorkspace 分享的风险 → 已确认其 Info.plist 声明 `org.debian.deb-archive` 文档类型；真机验证，失败保留回退路径，不劣化现状。

## 测试策略

- 构建：`comet check run build`（xcodebuild）确认编译通过。
- 分支核对：对照 delta spec 场景逐一确认实现分支。
- 真机（如有条件）：三种安装态（仅 Umbra / 仅旧版 / 均未装）实测交接与跳转。

## Spec Patch

无——open 阶段 delta spec 已含全部所需场景。
