---
change: swap-umbra-patcher
design-doc: docs/openspec/changes/swap-umbra-patcher/design.md
base-ref: 5aa56849a469dfcbc022ff05aaba15cf6eb092f8
archived-with: 2026-10-19-swap-umbra-patcher
---
<!-- comet-task-authority: docs/openspec/changes/swap-umbra-patcher/tasks.md -->

# Implementation Plan — swap-umbra-patcher

## 概述

在 `Sileo/Backend/Download Manager/DownloadManager.swift` 中将 Patcher 检测从硬编码 `com.roothide.patcher` 改为有序候选数组（Umbra 优先、旧版兜底），覆盖 `patchPackage`（deb 交接）与 `showPatchAlert`（安装引导）两个消费点。设计依据：`docs/openspec/changes/swap-umbra-patcher/design.md`（D1/D2/D3）。执行配置：autonomous / direct / standard review。

## 任务

<!-- comet-task-ref:743865d9-ee64-4b8d-8d38-1e126c8ce262 -->
### 1.1 新增候选数组
- 范围：`DownloadManager` 内新增 `private static let patcherBundleIDs`，注释标明顺序即优先级。
- 依赖：无。
- 验收：文件编译通过；两处消费点引用同一数组。

<!-- comet-task-ref:8613c027-7207-4d25-b10b-044a0e17e830 -->
### 2.1 patchPackage 遍历交接
- 范围：`patchPackage` 中按 `patcherBundleIDs.first { IsAppAvailable($0) }` 取首个可用 App，`ShareFileToApp` 使用命中 ID；无命中走现有系统分享面板（2.2 同一分支）。
- 依赖：1.1。
- 验收：无硬编码旧 ID 残留；fallback 路径与改动前一致。

<!-- comet-task-ref:b6af3a98-cea0-43d7-86a0-c7998b48c39c -->
### 2.2 回退系统分享面板保持
- 范围：确认全部候选不可用时现有 `UIActivityViewController` 分支不变。
- 依赖：2.1。
- 验收：阅读确认 fallback 结构与改动前一致。

<!-- comet-task-ref:8963da22-637b-4ea0-a1c4-6e0e7f5bf2f0 -->
### 3.1 showPatchAlert 首中检测
- 范围：`installedPackage(identifier:)` 改为遍历 `patcherBundleIDs`，首个命中 → "Convert"。
- 依赖：1.1。
- 验收：检测不再硬编码旧 ID。

<!-- comet-task-ref:bedee3ec-10e9-433f-8ae4-b36cc78f0c04 -->
### 3.2 Get Patcher 详情页回退
- 范围：未装任何 Patcher 时按 `[新ID, 旧ID]` 顺序依次尝试 `URLManager.viewController(url:)` 构建详情页，首个成功者 present；全部失败维持现有无按钮分支。
- 依赖：3.1。
- 验收：回退顺序正确；全失败路径保持现有行为。

<!-- comet-task-ref:649a1b91-9127-43fb-9d37-aec412837d33 -->
### 4.1 构建验证
- 范围：运行项目构建确认无编译错误。
- 依赖：2.x、3.x 完成。
- 验收：`comet check run swap-umbra-patcher build --local -- xcodebuild ...` exit code 0。

<!-- comet-task-ref:4c5be54b-0778-4ffa-a286-f47b41a6f6c3 -->
### 4.2 Spec 场景分支核对
- 范围：对照 delta spec 8 个场景逐一核对实现分支。
- 依赖：4.1。
- 验收：每个场景落到对应代码分支，记录在 checkpoint。

<!-- comet-task-ref:ff080cf7-1c1e-43d5-bb7c-7ffc08e7a3af -->
### 4.3 真机实测（如有条件）
- 范围：三种安装态实测交接与跳转。
- 依赖：4.1。
- 验收：真机行为符合 spec；无设备条件时在 Verify 记录偏差并由用户确认接受。

## 约束与回退

- 单文件改动；回退即 revert `DownloadManager.swift`。
- 不改动警告弹窗结构、特殊源处理、`checkRootHide`/`checkRootlessV2` 路径；不新增本地化字符串、设置项。
- 提交在 build guard 通过后进行（Runtime 顺序）。
