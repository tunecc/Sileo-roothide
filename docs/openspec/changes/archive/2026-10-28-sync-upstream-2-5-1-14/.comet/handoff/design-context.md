# Comet Design Handoff

- Change: sync-upstream-2-5-1-14
- Phase: design
- Mode: compact
- Context hash: 92aab94bd1114e5d6ff10a9faa3cd548e029e3f653ac8713e2cbddd139217fcf

Generated-by: comet-handoff.sh
Task hash policy: task-content-v1. Read tasks.md for live completion; excerpts are design-time context.

OpenSpec remains the canonical capability spec. This handoff is a deterministic, source-traceable context pack, not an agent-authored summary.

## docs/openspec/changes/sync-upstream-2-5-1-14/proposal.md

- Source: docs/openspec/changes/sync-upstream-2-5-1-14/proposal.md
- Lines: 1-33
- SHA256: a127b71dd09497f7523ccadf8f97d8a8504fa909f04978b77168d319ec3e6b6b

```md
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

```

## docs/openspec/changes/sync-upstream-2-5-1-14/design.md

- Source: docs/openspec/changes/sync-upstream-2-5-1-14/design.md
- Lines: 1-68
- SHA256: 9c4c6e2dc5870759569581ad3020e737c6787999335e73e5285699f4c55382fd

```md
# Design

## Context

- fork 的 `main` 停在 `9dd48ec`（2.5.1-12）并叠加 20 个定制提交；`upstream/main` 已到 `84645de`（2.5.1-14），中间有 4 个提交。
- 本次在独立 worktree 分支 `comet/sync-upstream-2-5-1-14` 上执行合并，父工作区的未提交改动（`.gitignore`、`MARKETING_VERSION=2.5.1-13`）不参与本次 change。
- 双方在构建链上各自实现过同一修复：上游 `patches/alderis-ios26-tab.patch` + Makefile `patch-deps`；fork `Scripts/patch-alderis-checkout.sh` + 内联 `xcodebuild -resolvePackageDependencies`。
- 双方都改过 `Sileo/UI/SourcesViewController/SourcesViewController.swift`、`PackageListViewController.swift`、`NewsViewController.swift`、`PackageListManager.swift`、`DownloadManager.swift`、`Makefile`、`project.pbxproj`、`libroothide.tbd` 等文件，预期产生文本冲突。
- 上游没有实现 fork 的源管理、屏蔽更新、RootHideCompat、Umbra Patcher 优先等能力；这些功能整体保留。

## Goals / Non-Goals

**Goals:**
- 把 4 个上游提交完整合入 fork，保持 `upstream/main` 为祖先关系（使用 merge，而非 rebase/cherry-pick）。
- 合并后 fork 既有功能保持可用：源管理、屏蔽更新、Patcher 优先、iPad 搜索状态、giveMeRoot/postinst 路径修复。
- 构建链只保留一套实现：采用上游 `patch-deps`，删除 fork 的脚本与内联步骤。
- 以实际构建结果验证合并，而不是只依赖文本冲突清零。

**Non-Goals:**
- 不新增 fork 功能，不重构源管理/屏蔽更新的现有实现。
- 不引入自动同步 CI 或版本发布流程改造。
- 不处理与本次上游提交无关的历史遗留问题（例如 `RepoManager.swift` 中恒真的 bootstrap 判断）。

## Decisions

1. **合并方式：`git merge upstream/main`**
   - 理由：保留上游作为祖先，后续同步可持续使用同一 merge-base；fork 的 20 个提交不改写历史。
   - 替代方案：cherry-pick 4 个提交 —— 会丢失祖先关系，下次合并需重新计算差异；rebase fork 提交 —— 改写已推送历史，风险高。

2. **构建链采用上游实现**
   - 使用 `patches/alderis-ios26-tab.patch` 与 `Makefile` 的 `patch-deps` 目标（`stage: patch-deps all`，并在 xcodebuild 时 `-disableAutomaticPackageResolution`）。
   - 删除 `Scripts/patch-alderis-checkout.sh` 及 fork 在 Makefile 中的内联解析、补丁调用。
   - 保留 fork 的 `RUN_CLANG_STATIC_ANALYZER=NO` 与 `SILEO_APP_INSTALL_PATH` / postinst 路径替换，因为它们解决的是不同问题（本机静态分析、roothide 安装路径）。
   - 替代方案：保留 fork 脚本 —— 与上游行为重复，后续每次同步都要再处理冲突。

3. **`.tbd` 架构声明采用上游 `[arm64, arm64e]`**
   - 理由：上游版本同样移除了模拟器架构，并额外保留 arm64e；属于规范版本，减少后续冲突。
   - 替代方案：保留 fork 的仅 `arm64` —— 效果基本等价但持续冲突。

4. **源格式校验：移植上游检查并放宽 suite/components 限制**
   - 将上游 `hasCompatibleSourceFormat` 的 URL/scheme/host 校验应用到 `importRepos(fromURL:)`、`presentAddClipBoardPrompt`、`handleSourceAdd`。
   - 去掉上游“suite 必须为 `./` 且 components 必须为空”的限制，保留 fork 的自定义 suite/components 能力。
   - 理由：用户已确认“适配保留两者”；直接照搬会削弱 fork 的源管理功能。

5. **Jailbreak 重构整体采用上游**
   - 采用上游简化后的枚举与新增 `Relaxin` 分支，同步更新 fork 代码中的引用点。
   - 枚举未在本 fork 中通过 Codable 持久化；`rawValue` 仅用于展示，`UIDevice+Private.swift` 的解析取空格前首段，重命名后仍可工作。
   - 替代方案：保留旧枚举并手工补 Relaxin —— 与上游差异扩大，后续同步成本更高。

6. **冲突解决原则**
   - fork 独有功能文件：以 fork 行为为准，合入上游与之无关的修复。
   - 上游共享基础设施（Jailbreak/Bootstrap、DownloadManager、DatabaseManager、APTWrapper、ControlFileParserFast、Depiction*、SileoNavigationController、Info.plist）：以上游为准。
   - 双方都做过的防护性改动（NewsViewController、PackageListViewController 的安全索引/并发）：取并集，优先复用 fork 已抽出的辅助方法，避免重复逻辑。
   - `PackageListManager`：保留 fork 的屏蔽更新过滤逻辑，同时采用上游的排序比较器修正。
   - `DownloadManager`：保留 fork 的 Patcher 候选优先级，采用上游的损坏包处理与 `IncompatibleRepo` 重构。
   - `project.pbxproj`：采用上游 `MARKETING_VERSION=2.5.1-14`，保留 fork 新增文件引用（UpdateBlockManager、BlockedUpdatesViewController、RootHideCompat、测试）。

7. **版本号**
   - 采用上游 `2.5.1-14`；父工作区未提交的 `2.5.1-13` 提升不进入 change 分支。

## Risks / Trade-offs

- [大面积文本冲突导致 fork 功能被覆盖] → 按文件逐个解决，冲突解决后运行构建；对源管理、屏蔽更新、Patcher 交接相关文件做定向 diff 复核。
- [上游 `patch-deps` 依赖 SPM checkout 是 git 仓库，若本机 checkout 非 git 目录会失败] → 先运行 `make stage` 验证；若失败，检查 checkout 目录并报告，不擅自回退到 fork 脚本（该回退属于范围变化，需用户确认）。
- [上游 `Jailbreak` 重命名导致 fork 代码编译错误] → 合并后编译并修正引用；不做持久化迁移，因为当前无 Codable 持久化。
- [合并后无法在模拟器/真机实际运行，UI 行为无法完整验证] → 以 `xcodebuild` 构建成功 + 现有单元测试（UpdateBlockManagerTests）作为可执行验证，并在交付说明中明确未做设备级验证。
- [上游 `UIDesignRequiresCompatibility` 改变 iOS 26 外观] → 属于上游有意行为，保留；不在本次调整。
- [父工作区的未提交 `2.5.1-13` 与上游版本号产生混淆] → 本次只在 worktree 分支操作，父工作区改动保持原样，归档时明确说明。

```

## docs/openspec/changes/sync-upstream-2-5-1-14/tasks.md

- Source: docs/openspec/changes/sync-upstream-2-5-1-14/tasks.md
- Lines: 1-22
- SHA256: 82dd02ec82cdb85f1f3ac70ae29792663a0ba9a19becfe44a8d3531790d93ea1

```md
# Tasks

## 1. 合并上游提交

- [ ] 1.1 在 `comet/sync-upstream-2-5-1-14` 分支执行 `git merge upstream/main`，记录冲突文件清单并与预期重叠面（Makefile、project.pbxproj、SourcesViewController、PackageListViewController、NewsViewController、PackageQueueButton、DownloadManager、PackageListManager、RepoManager、AppDelegate、dpkgversion.h、tbd 文件等）核对；验证：`git status --short` 的冲突清单只包含预期文件，无意外目录或生成物 <!-- comet-task:7b674ce5-aa9c-4839-a531-f75fc24be95f -->
- [ ] 1.2 解决构建链冲突：采用上游 `patch-deps` 与 `patches/alderis-ios26-tab.patch`，删除 `Scripts/patch-alderis-checkout.sh` 与 Makefile 内联解析/补丁调用，保留 `RUN_CLANG_STATIC_ANALYZER=NO`、`SILEO_APP_INSTALL_PATH` 与 postinst 路径替换，`.tbd` 采用 `arm64, arm64e`；验证：`grep -R "patch-alderis-checkout"` 无残留引用，`make -n stage` 显示 `patch-deps` 依赖，三个 tbd 的 archs 行均为 `[ arm64, arm64e ]` <!-- comet-task:8c73a543-4da5-4910-b5fb-5d8e20c4797e -->
- [ ] 1.3 解决 Backend 冲突：采用上游 Jailbreak/Bootstrap 重构（含 Relaxin）并修正 fork 引用，合并 DownloadManager 的损坏包处理与 fork Patcher 优先级，PackageListManager 保留屏蔽更新过滤并采用上游排序修正，同步 DatabaseManager、APTWrapper、ControlFileParserFast、Maintainer、dpkgversion.h；验证：相关文件无冲突标记，关键 fork 符号（`patcherBundleIDs`、`UpdateBlockManager` 过滤调用）仍在 <!-- comet-task:5274bda2-b534-49f3-a3d0-021bae67a553 -->
- [ ] 1.4 解决 UI 冲突：SourcesViewController 合并上游校验并适配 suite/components，PackageListViewController/NewsViewController 取双方安全索引与搜索状态修复的并集，合并 PackageQueueButton、CategoryViewController、Depiction*、SileoNavigationController、AppDelegate、Info.plist；验证：冲突标记清零，`searchController` 状态保持与 `package(at:)`/`packages(in:)` 辅助方法仍在 <!-- comet-task:37b24629-8867-443c-99fc-9901ac6aa710 -->
- [ ] 1.5 解决工程与打包冲突：project.pbxproj 采用 `MARKETING_VERSION=2.5.1-14` 并保留 fork 新增文件引用，合并 Makefile、postinst、giveMeRoot、libroothide.tbd、Deps tbd、本地化与 README；验证：`plutil -lint Sileo/Info.plist` 通过，`git diff --check` 无空白错误，pbxproj 中 fork 新增文件仍被目标引用 <!-- comet-task:c525d63a-63e5-4ac4-885f-adaded85d72c -->
- [ ] 1.6 按 spec `source-entry-validation` 适配源格式校验：在 `importRepos(fromURL:)`、`presentAddClipBoardPrompt`、`handleSourceAdd` 应用 URL/scheme/host 校验，同时保留自定义 suite/components；验证：代码审查三处调用点均先校验后处理，带 suite/components 的输入不会被过滤 <!-- comet-task:97953360-fec1-4811-89ad-27b966e1e7a8 -->

## 2. 验证合并结果

- [ ] 2.1 运行 iOS 设备构建（`xcodebuild` 或 `make stage` 等价命令，`CODE_SIGNING_ALLOWED=NO`），确认 Swift 与 C/ObjC 全部编译通过；验证：记录实际命令与成功输出，任何编译错误必须修复后重跑 <!-- comet-task:83b9cad4-0c91-4da0-8f81-6e959c7915a4 -->
- [ ] 2.2 运行现有测试（`Sileo Backend Tests` 中的 `UpdateBlockManagerTests`）；验证：记录测试命令与结果；若环境无法运行测试，记录具体原因与已做的替代验证 <!-- comet-task:ff2de694-6c19-4c69-898a-0fff1b57dbaf -->
- [ ] 2.3 核对 fork 功能完整性：确认源管理、屏蔽更新、RootHideCompat、Umbra Patcher 优先、iPad 搜索状态修复、postinst/giveMeRoot 路径修复的代码均保留；验证：对关键符号与文件做 grep 清单检查并记录结果 <!-- comet-task:da85bf00-0641-4454-882d-0e7d217ef702 -->
- [ ] 2.4 确认合并关系与工作区状态：`git merge-base --is-ancestor upstream/main HEAD` 成功，冲突标记与意外文件为零；验证：命令退出码为 0，`git status` 仅包含本 change 的预期文件 <!-- comet-task:6c451cd0-551f-47fc-a220-b59f3c2eec3c -->

## Workflow follow-up

- 归档前完成一次覆盖最终实现的集成审查。
- 归档 change，并按用户确认的交付方式处理分支合并与推送。

```

## docs/openspec/changes/sync-upstream-2-5-1-14/.openspec.yaml

- Source: docs/openspec/changes/sync-upstream-2-5-1-14/.openspec.yaml
- Lines: 1-2
- SHA256: 9e0a467e3934b14a2d9c9175305310e9359d34e2484a458af3d182c2956b9e2d

```md
schema: spec-driven
created: 2026-10-28

```

## docs/openspec/changes/sync-upstream-2-5-1-14/specs/source-entry-validation/spec.md

- Source: docs/openspec/changes/sync-upstream-2-5-1-14/specs/source-entry-validation/spec.md
- Lines: 1-31
- SHA256: 860ea6b06a009ba5ad391bb5924267a09a146529fe75104ff27aea5fe565f96b

```md
# Spec Delta

## Purpose

规范用户在 Sileo 中添加或导入软件源时的条目校验行为，确保非法条目被拒绝，同时保留自定义 suite 与 components 的源配置能力。

## ADDED Requirements

### Requirement: 源条目的 URL 合法性校验

系统在添加或导入软件源时，必须校验每个条目是否为可解析的 `http`/`https` URL 且包含主机名；不满足条件的条目不得被添加，也不得阻止同一批次中其他合法条目继续处理。

#### Scenario: 合法 URL 添加成功
- **WHEN** 用户输入或粘贴 `https://repo.example.com/`
- **THEN** 系统将其识别为合法条目并正常添加该软件源

#### Scenario: 非法条目被拒绝
- **WHEN** 用户输入 `ftp://repo.example.com/`、缺少主机名的 URL，或无法解析为 URL 的文本
- **THEN** 系统跳过该条目，不创建软件源，其他合法条目不受影响

### Requirement: 自定义 suite 与 components 支持

系统必须继续接受带自定义 suite 或 components 的合法源条目，并按其配置添加为 dist 源；校验不得因 suite 不是 `./` 或 components 非空而丢弃条目。

#### Scenario: 带 suite 与 components 的源
- **WHEN** 用户输入 `https://repo.example.com/ stable main`
- **THEN** 系统按 suite `stable`、components `main` 添加 dist 源

#### Scenario: 导入列表中的多条目源
- **WHEN** 用户从 sources 列表导入包含默认源与带 suite/components 源的文本
- **THEN** 系统逐条校验，合法条目全部导入，非法条目被跳过并给出既有失败反馈

```
