# Tasks

## 1. 合并上游提交

- [x] 1.1 在 `comet/sync-upstream-2-5-1-14` 分支执行 `git merge upstream/main`，记录冲突文件清单并与预期重叠面（Makefile、project.pbxproj、SourcesViewController、PackageListViewController、NewsViewController、PackageQueueButton、DownloadManager、PackageListManager、RepoManager、AppDelegate、dpkgversion.h、tbd 文件等）核对；验证：`git status --short` 的冲突清单只包含预期文件，无意外目录或生成物 <!-- comet-task:7b674ce5-aa9c-4839-a531-f75fc24be95f -->
- [x] 1.2 解决构建链冲突：采用上游 `patch-deps` 与 `patches/alderis-ios26-tab.patch`，删除 `Scripts/patch-alderis-checkout.sh` 与 Makefile 内联解析/补丁调用，保留 `RUN_CLANG_STATIC_ANALYZER=NO`、`SILEO_APP_INSTALL_PATH` 与 postinst 路径替换，`.tbd` 采用 `arm64, arm64e`；验证：`grep -R "patch-alderis-checkout"` 无残留引用，`make -n stage` 显示 `patch-deps` 依赖，三个 tbd 的 archs 行均为 `[ arm64, arm64e ]` <!-- comet-task:8c73a543-4da5-4910-b5fb-5d8e20c4797e -->
- [x] 1.3 解决 Backend 冲突：采用上游 Jailbreak/Bootstrap 重构（含 Relaxin）并修正 fork 引用，合并 DownloadManager 的损坏包处理与 fork Patcher 优先级，PackageListManager 保留屏蔽更新过滤并采用上游排序修正，同步 DatabaseManager、APTWrapper、ControlFileParserFast、Maintainer、dpkgversion.h；验证：相关文件无冲突标记，关键 fork 符号（`patcherBundleIDs`、`UpdateBlockManager` 过滤调用）仍在 <!-- comet-task:5274bda2-b534-49f3-a3d0-021bae67a553 -->
- [x] 1.4 解决 UI 冲突：SourcesViewController 合并上游校验并适配 suite/components，PackageListViewController/NewsViewController 取双方安全索引与搜索状态修复的并集，合并 PackageQueueButton、CategoryViewController、Depiction*、SileoNavigationController、AppDelegate、Info.plist；验证：冲突标记清零，`searchController` 状态保持与 `package(at:)`/`packages(in:)` 辅助方法仍在 <!-- comet-task:37b24629-8867-443c-99fc-9901ac6aa710 -->
- [x] 1.5 解决工程与打包冲突：project.pbxproj 采用 `MARKETING_VERSION=2.5.1-14` 并保留 fork 新增文件引用，合并 Makefile、postinst、giveMeRoot、libroothide.tbd、Deps tbd、本地化与 README；验证：`plutil -lint Sileo/Info.plist` 通过，`git diff --check` 无空白错误，pbxproj 中 fork 新增文件仍被目标引用 <!-- comet-task:c525d63a-63e5-4ac4-885f-adaded85d72c -->
- [x] 1.6 按 spec `source-entry-validation` 适配源格式校验：在 `importRepos(fromURL:)`、`presentAddClipBoardPrompt`、`handleSourceAdd` 应用 URL/scheme/host 校验，同时保留自定义 suite/components；验证：代码审查三处调用点均先校验后处理，带 suite/components 的输入不会被过滤 <!-- comet-task:97953360-fec1-4811-89ad-27b966e1e7a8 -->

## 2. 验证合并结果

- [x] 2.1 运行 iOS 设备构建（`xcodebuild` 或 `make stage` 等价命令，`CODE_SIGNING_ALLOWED=NO`），确认 Swift 与 C/ObjC 全部编译通过；验证：记录实际命令与成功输出，任何编译错误必须修复后重跑 <!-- comet-task:83b9cad4-0c91-4da0-8f81-6e959c7915a4 -->
- [x] 2.2 运行现有测试（`Sileo Backend Tests` 中的 `UpdateBlockManagerTests`）；验证：记录测试命令与结果；若环境无法运行测试，记录具体原因与已做的替代验证 <!-- comet-task:ff2de694-6c19-4c69-898a-0fff1b57dbaf -->
- [x] 2.3 核对 fork 功能完整性：确认源管理、屏蔽更新、RootHideCompat、Umbra Patcher 优先、iPad 搜索状态修复、postinst/giveMeRoot 路径修复的代码均保留；验证：对关键符号与文件做 grep 清单检查并记录结果 <!-- comet-task:da85bf00-0641-4454-882d-0e7d217ef702 -->
- [x] 2.4 确认合并关系与工作区状态：`git merge-base --is-ancestor upstream/main HEAD` 成功，冲突标记与意外文件为零；验证：命令退出码为 0，`git status` 仅包含本 change 的预期文件 <!-- comet-task:6c451cd0-551f-47fc-a220-b59f3c2eec3c -->

## Workflow follow-up

- 归档前完成一次覆盖最终实现的集成审查。
- 归档 change，并按用户确认的交付方式处理分支合并与推送。
