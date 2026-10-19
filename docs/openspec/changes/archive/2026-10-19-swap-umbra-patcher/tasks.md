# Tasks

## 1. 引入候选 Patcher 列表

- [x] 1.1 在 `DownloadManager.swift` 内新增 `private static let patcherBundleIDs = ["wiki.qaq.umbra.patcher", "com.roothide.patcher"]`，注释标明顺序即优先级；验证：文件编译通过，两处消费点引用同一数组。 <!-- comet-task:743865d9-ee64-4b8d-8d38-1e126c8ce262 -->

## 2. 改造 patchPackage 交接

- [x] 2.1 将 `patchPackage` 中 `IsAppAvailable("com.roothide.patcher")` + `ShareFileToApp` 改为遍历 `patcherBundleIDs`，首个 `IsAppAvailable` 命中的 ID 作为分享目标；验证：源码阅读确认无硬编码旧 ID 残留，`ShareFileToApp` 使用循环内命中 ID。 <!-- comet-task:8613c027-7207-4d25-b10b-044a0e17e830 -->
- [x] 2.2 确认全部候选不可用时仍回退系统分享面板（现有 `UIActivityViewController` 分支）；验证：阅读确认遍历后 fallback 路径与改动前一致。 <!-- comet-task:b6af3a98-cea0-43d7-86a0-c7998b48c39c -->

## 3. 改造 showPatchAlert 安装引导

- [x] 3.1 将 `installedPackage(identifier:)` 检测改为遍历 `patcherBundleIDs`，首个命中决定 "Convert"；验证：阅读确认检测不再硬编码旧 ID。 <!-- comet-task:8963da22-637b-4ea0-a1c4-6e0e7f5bf2f0 -->
- [x] 3.2 未装任何 Patcher 时，`Get Patcher` 跳转依次尝试新包 `wiki.qaq.umbra.patcher` 与旧包 `com.roothide.patcher` 的详情页，首个构建成功的 present；验证：阅读确认 fallback 顺序正确，全部失败时维持现有无跳转按钮分支。 <!-- comet-task:bedee3ec-10e9-433f-8ae4-b36cc78f0c04 -->

## 4. 验证

- [x] 4.1 运行构建（`xcodebuild` 模拟器 scheme 或 `comet check run build`）确认无编译错误；验证：构建命令 exit code 0。 <!-- comet-task:649a1b91-9127-43fb-9d37-aec412837d33 -->
- [x] 4.2 对照 delta spec 五组场景逐一核对实现分支；验证：每个场景可落到对应代码分支，无遗漏。 <!-- comet-task:4c5be54b-0778-4ffa-a286-f47b41a6f6c3 -->
- [x] 4.3 真机实测（用户确认改验收方式，2026-10-19）：本环境无 RootHide 真机，验收改为静态核对 + 构建验证 + 独立审查（reviewer 三轮最终 PASS，7 个 spec 场景全部落对应分支）；真机行为由用户日常使用时验证。 <!-- comet-task:ff080cf7-1c1e-43d5-bb7c-7ffc08e7a3af -->
