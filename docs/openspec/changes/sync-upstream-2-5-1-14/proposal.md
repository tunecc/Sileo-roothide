# Proposal

## Why

上游 `roothide/Sileo-roothide` 已发布 2.5.1-13 与 2.5.1-14，带来 Jailbreak 检测重构（含 Relaxin 支持）、iOS 26 兼容、dpkg 半配置/损坏包处理、数据库与搜索缓存并发安全、多处崩溃防护等修复。本 fork 自 2.5.1-12 起积累了大量定制（源管理增强、屏蔽更新、Umbra Patcher 优先、roothide 构建链路修复、iPad 搜索状态修复等），需要持续同步上游，否则分叉会越来越大、后续合并成本持续上升。

## What Changes

- 合并 `upstream/main` 的 4 个提交（`c001f54` 2.5.1-13、`9e528bf` fix、`92a3b74` Optimization and improvement、`84645de` 2.5.1-14）到 fork 的 `main`。
- 采用上游构建链修复：使用 `patches/alderis-ios26-tab.patch` 与 Makefile `patch-deps` 目标，删除 fork 的 `Scripts/patch-alderis-checkout.sh` 及内联依赖解析/补丁步骤；保留 fork 的 `RUN_CLANG_STATIC_ANALYZER=NO` 与 postinst 安装路径替换修复。
- 采用上游 `.tbd` 架构声明（`arm64`, `arm64e`），替换 fork 的仅 `arm64` 裁剪。
- 采用上游源格式校验的 URL/scheme/host 合法性检查，但适配 fork 的源管理能力：不拒绝自定义 suite 与 components。
- 保留 fork 独有定制：软件源管理/搜索/自动禁用、屏蔽更新（UpdateBlockManager 及 UI）、RootHideCompat 兼容层、Umbra Patcher 优先与安装引导、iPad 搜索状态保持、giveMeRoot 运行时路径与 postinst 路径修复。
- 同步上游对 Jailbreak 枚举的重命名与新增 Relaxin 分支，并修正 fork 代码中的相关引用。
- `MARKETING_VERSION` 采用上游 2.5.1-14。

**BREAKING**: 无对外行为破坏；Jailbreak 为内部枚举，重命名不改变用户可见行为。

## Capabilities

### New Capabilities

- `source-entry-validation`: 添加/导入软件源时对条目格式进行校验，接受合法 http(s) 源并保留自定义 suite/components 支持，拒绝无法解析的条目。

### Modified Capabilities

（无）

## Impact

- 受影响代码：`Sileo/Backend/Root Wrapper/`（Jailbreak、Bootstrap）、`Sileo/Backend/Download Manager/`、`Sileo/Backend/Package Manager/`、`Sileo/Backend/Repo Manager/`、`Sileo/Backend/APT Wrapper/`、`Sileo/Backend/DatabaseManager/`、`Sileo/Backend/Control File Parser/`、`Sileo/UI/` 多个视图控制器、`Makefile`、`Sileo.xcodeproj/project.pbxproj`、`Deps/*.tbd`、`libroothide.tbd`、`patches/`、`Sileo/Info.plist`。
- 受影响依赖/构建：SwiftPM 依赖解析流程、Alderis checkout 补丁、tbd 架构声明。
- 相关既有能力：软件源管理、屏蔽更新、Patcher 交接（`patcher-handoff`）；本次不修改 `patcher-handoff` 的需求。
