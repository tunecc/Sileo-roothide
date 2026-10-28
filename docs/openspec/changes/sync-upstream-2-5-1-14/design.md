---
comet_change: sync-upstream-2-5-1-14
role: technical-design
canonical_spec: openspec
---

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

## Testing Strategy

- 合并后构建：`make stage` 或 `xcodebuild` 成功。
- 运行 `UpdateBlockManagerTests`；无法运行时记录原因与替代验证。
- grep 校验 fork 功能符号仍存在：`UpdateBlockManager`、`RepoManagementPolicy`、`RootHideCompat`、`patcherBundleIDs`。
- `git merge-base --is-ancestor upstream/main HEAD` 验证祖先关系；`git diff --check` 与 `plutil -lint` 检查格式。

## Spec Patch

无。Open 阶段已写入 `specs/source-entry-validation/spec.md`（URL 合法性校验 + suite/components 支持），设计阶段不新增或改写行为规格。

## Risks / Trade-offs

- [大面积文本冲突导致 fork 功能被覆盖] → 按文件逐个解决，冲突解决后运行构建；对源管理、屏蔽更新、Patcher 交接相关文件做定向 diff 复核。
- [上游 `patch-deps` 依赖 SPM checkout 是 git 仓库，若本机 checkout 非 git 目录会失败] → 先运行 `make stage` 验证；若失败，检查 checkout 目录并报告，不擅自回退到 fork 脚本（该回退属于范围变化，需用户确认）。
- [上游 `Jailbreak` 重命名导致 fork 代码编译错误] → 合并后编译并修正引用；不做持久化迁移，因为当前无 Codable 持久化。
- [合并后无法在模拟器/真机实际运行，UI 行为无法完整验证] → 以 `xcodebuild` 构建成功 + 现有单元测试（UpdateBlockManagerTests）作为可执行验证，并在交付说明中明确未做设备级验证。
- [上游 `UIDesignRequiresCompatibility` 改变 iOS 26 外观] → 属于上游有意行为，保留；不在本次调整。
- [父工作区的未提交 `2.5.1-13` 与上游版本号产生混淆] → 本次只在 worktree 分支操作，父工作区改动保持原样，归档时明确说明。
