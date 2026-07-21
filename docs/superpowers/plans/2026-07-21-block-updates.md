# Block Updates (屏蔽更新) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Sileo-roothide 中实现 App 层「永久屏蔽」与「屏蔽到此版本（上限）」更新过滤，使被屏蔽包装不出现在更新列表 / 角标 / 全部更新中，同时不拦截手动安装、不写入 dpkg hold。

**Architecture:** 新增 `UpdateBlockManager`（对齐 `WishListManager`）用 `UserDefaults` 持久化一包一条规则；在 `PackageListManager.availableUpdates()` 单点过滤；列表 Context Menu 与详情「更多」菜单共用同一套写规则 API；设置页提供已屏蔽列表管理。版本比较强制走 `DpkgWrapper.isVersion(_:greaterThan:)`（可注入 comparator 以便单测）。

**Tech Stack:** Swift / UIKit / UserDefaults / XCTest / 现有 `DpkgWrapper` / `CSActionItem` / `BaseSettingsViewController`

**Spec:** `docs/superpowers/specs/2026-07-21-block-updates-design.md`

## Global Constraints

- 纯 App 层屏蔽，**禁止**调用 `DpkgWrapper.ignoreUpdates` / apt-mark hold
- 版本比较**禁止**字符串比较；必须用 dpkg 序（默认 `DpkgWrapper.isVersion`）
- 上限语义：候选 `≤ V` 屏蔽；严格 `> V` 才重新出现
- 一包一条规则；后写覆盖前写
- 手动安装 / 更新 / 降级 / 队列加入 **不拦截**
- 被屏蔽包装在更新页**完全消失**（不进 Ignored Updates 分区）
- 首期本地化仅 **Base + zh-Hans**
- 改动保持最小；不重构无关代码
- 每次 Task 结束必须 commit

## File Structure

| 路径 | 职责 |
|------|------|
| `Sileo/Backend/Update Block Manager/UpdateBlockManager.swift` | 规则模型、CRUD、判定、持久化、通知 |
| `Sileo Backend Tests/UpdateBlockManagerTests.swift` | Manager 单测（permanent / maxVersion / 覆盖 / fail-open） |
| `Sileo/Backend/Package Manager/PackageListManager.swift` | `availableUpdates()` 接入过滤 |
| `Sileo/UI/PackageViewController/PackageButton/PackageQueueButton.swift` | Context Menu：屏蔽 / 取消屏蔽 `CSActionItem` |
| `Sileo/UI/PackageViewController/PackageViewController.swift` | 详情「更多」：屏蔽更新… / 取消 |
| `Sileo/UI/SettingsViewController/Root/SettingsViewController.swift` | 设置入口行 + `BlockedUpdatesViewController`（可同文件底部或紧邻新文件） |
| `Sileo/UI/SettingsViewController/Root/BlockedUpdatesViewController.swift` | 已屏蔽列表管理页（推荐独立文件） |
| `Sileo/Sileo/Base.lproj/Localizable.strings` | 英文文案 |
| `Sileo/Sileo/zh-Hans.lproj/Localizable.strings` | 简体中文文案 |
| `Sileo.xcodeproj/project.pbxproj` | 新文件加入 Sileo / Backend Tests target |

```text
UI (Context Menu / Detail sheet / Settings)
        │
        ▼
UpdateBlockManager ──UserDefaults──► UpdateBlockRules
        ▲
        │ isUpdateBlocked(id, candidateVersion)
PackageListManager.availableUpdates()
        │
        ├─► 更新列表 / 角标
        └─► upgradeAll
```

---

### Task 1: UpdateBlockManager + 单元测试

**Files:**
- Create: `Sileo/Backend/Update Block Manager/UpdateBlockManager.swift`
- Create: `Sileo Backend Tests/UpdateBlockManagerTests.swift`
- Modify: `Sileo.xcodeproj/project.pbxproj`（加入上述文件到对应 target）

**Interfaces:**
- Produces:
  - `enum UpdateBlockMode: String, Codable { case permanent, maxVersion }`
  - `struct UpdateBlockRule: Codable, Equatable { packageID, mode, maxVersion?, createdAt }`
  - `final class UpdateBlockManager`
    - `static let shared`
    - `static let didChangeNotification: Notification.Name`（`"SileoUpdateBlockDidChange"`）
    - `private(set) var rulesByID: [String: UpdateBlockRule]`
    - `var versionIsGreater: (String, String) -> Bool`（默认 `DpkgWrapper.isVersion`；测试可注入）
    - `func rule(for packageID: String) -> UpdateBlockRule?`
    - `func isUpdateBlocked(packageID: String, candidateVersion: String) -> Bool`
    - `func blockPermanently(packageID: String)`
    - `func blockMaxVersion(packageID: String, version: String)`
    - `func unblock(packageID: String)`
    - `func clearAll()`
    - `func allRulesSorted() -> [UpdateBlockRule]`
  - UserDefaults key: `"UpdateBlockRules"`

- [ ] **Step 1: 在 pbxproj 注册新文件（先建空壳也可，但需能编译进 test target）**

参照现有 `WishListManager.swift` 条目模式新增：

- `PBXFileReference` for `UpdateBlockManager.swift`
- `PBXGroup` `"Update Block Manager"`（与 `"Wish List Manager"` 同级，挂在 Backend 的 children 里；Backend 引用点已有 `F1E287B22225DE1000603B3E /* Wish List Manager */`，在其附近插入新 group）
- `PBXBuildFile` 加入与 WishList 相同的 **所有** Sileo app targets 的 Sources（WishList 出现在至少 3 个 Sources 列表：`E12818CC`、`F139D0FF`、`F102D1E3` 附近）
- `UpdateBlockManagerTests.swift`：`PBXFileReference` + 加入 `Sileo Backend Tests` Sources（与 `DPKGParserTests.swift` 同组 `E1281995`）

生成唯一 24 位十六进制 ID（勿与现有冲突）。若对 pbxproj 不熟，可用 Xcode 打开工程手动 Add Files，再继续；但 commit 时必须包含 pbxproj 变更。

- [ ] **Step 2: 写失败的单元测试**

创建 `Sileo Backend Tests/UpdateBlockManagerTests.swift`：

```swift
//
//  UpdateBlockManagerTests.swift
//  Sileo Backend Tests
//

import XCTest
@testable import Sileo

final class UpdateBlockManagerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var manager: UpdateBlockManager!

    override func setUpWithError() throws {
        suiteName = "UpdateBlockManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        manager = UpdateBlockManager(defaults: defaults)
        // Deterministic dpkg-like order for tests (not production comparator):
        // higher index in this list = greater. Unknown strings: fail-open path covered separately.
        let order = [
            "1.1.3-4~beta1",
            "1.1.3-4~beta2",
            "1.1.3-4",
            "1.1.3-5"
        ]
        manager.versionIsGreater = { a, b in
            guard let ia = order.firstIndex(of: a), let ib = order.firstIndex(of: b) else {
                return false // treat unknown as not greater → will block under ≤ semantics when equal missing; see fail-open test
            }
            return ia > ib
        }
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        manager = nil
        defaults = nil
    }

    func testPermanentAlwaysBlocks() {
        manager.blockPermanently(packageID: "com.example.tweak")
        XCTAssertTrue(manager.isUpdateBlocked(packageID: "com.example.tweak", candidateVersion: "1.1.3-5"))
        XCTAssertTrue(manager.isUpdateBlocked(packageID: "com.example.tweak", candidateVersion: "9.9.9"))
    }

    func testMaxVersionBlocksEqualAndLower() {
        manager.blockMaxVersion(packageID: "com.example.tweak", version: "1.1.3-4~beta2")
        XCTAssertTrue(manager.isUpdateBlocked(packageID: "com.example.tweak", candidateVersion: "1.1.3-4~beta2"))
        XCTAssertTrue(manager.isUpdateBlocked(packageID: "com.example.tweak", candidateVersion: "1.1.3-4~beta1"))
        XCTAssertFalse(manager.isUpdateBlocked(packageID: "com.example.tweak", candidateVersion: "1.1.3-4"))
        XCTAssertFalse(manager.isUpdateBlocked(packageID: "com.example.tweak", candidateVersion: "1.1.3-5"))
    }

    func testOverwriteRule() {
        manager.blockMaxVersion(packageID: "com.example.tweak", version: "1.1.3-4~beta2")
        manager.blockPermanently(packageID: "com.example.tweak")
        XCTAssertEqual(manager.rule(for: "com.example.tweak")?.mode, .permanent)
        manager.blockMaxVersion(packageID: "com.example.tweak", version: "1.1.3-4")
        XCTAssertEqual(manager.rule(for: "com.example.tweak")?.mode, .maxVersion)
        XCTAssertEqual(manager.rule(for: "com.example.tweak")?.maxVersion, "1.1.3-4")
    }

    func testUnblockAndClear() {
        manager.blockPermanently(packageID: "a")
        manager.blockPermanently(packageID: "b")
        manager.unblock(packageID: "a")
        XCTAssertNil(manager.rule(for: "a"))
        XCTAssertNotNil(manager.rule(for: "b"))
        manager.clearAll()
        XCTAssertTrue(manager.allRulesSorted().isEmpty)
    }

    func testEmptyPackageIDRejected() {
        manager.blockPermanently(packageID: "  ")
        manager.blockMaxVersion(packageID: "", version: "1.0")
        XCTAssertTrue(manager.allRulesSorted().isEmpty)
    }

    func testPersistenceRoundTrip() {
        manager.blockMaxVersion(packageID: "com.example.tweak", version: "1.1.3-4~beta2")
        let reloaded = UpdateBlockManager(defaults: defaults)
        reloaded.versionIsGreater = manager.versionIsGreater
        XCTAssertTrue(reloaded.isUpdateBlocked(packageID: "com.example.tweak", candidateVersion: "1.1.3-4~beta2"))
        XCTAssertFalse(reloaded.isUpdateBlocked(packageID: "com.example.tweak", candidateVersion: "1.1.3-4"))
    }

    func testInvalidMaxVersionRuleDoesNotBlock() throws {
        let bad = UpdateBlockRule(packageID: "com.bad", mode: .maxVersion, maxVersion: nil, createdAt: Date())
        let data = try JSONEncoder().encode([bad])
        defaults.set(data, forKey: "UpdateBlockRules")
        let reloaded = UpdateBlockManager(defaults: defaults)
        XCTAssertFalse(reloaded.isUpdateBlocked(packageID: "com.bad", candidateVersion: "9.0"))
        XCTAssertNil(reloaded.rule(for: "com.bad"))
    }
}
```

实现 `UpdateBlockManager` 时：`isUpdateBlocked` 若 `mode == .maxVersion` 且 `maxVersion` 为空，返回 `false`；`reloadFromDefaults` 时剔除无效规则。

- [ ] **Step 3: 运行测试，确认失败（类型不存在）**

```bash
xcodebuild test -project Sileo.xcodeproj -scheme "Sileo Backend Tests" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:"Sileo Backend Tests/UpdateBlockManagerTests" 2>&1 | tail -40
```

若 scheme 名不同，先 `xcodebuild -list -project Sileo.xcodeproj` 确认。  
Expected: compile error `UpdateBlockManager` not found，或 test target 未包含文件。

- [ ] **Step 4: 实现 `UpdateBlockManager.swift`**

```swift
//
//  UpdateBlockManager.swift
//  Sileo
//

import Foundation

enum UpdateBlockMode: String, Codable {
    case permanent
    case maxVersion
}

struct UpdateBlockRule: Codable, Equatable {
    var packageID: String
    var mode: UpdateBlockMode
    var maxVersion: String?
    var createdAt: Date
}

final class UpdateBlockManager {
    static let shared = UpdateBlockManager()
    static let didChangeNotification = Notification.Name("SileoUpdateBlockDidChange")

    private static let storageKey = "UpdateBlockRules"
    private let defaults: UserDefaults
    private let lock = NSLock()

    private(set) var rulesByID: [String: UpdateBlockRule] = [:]

    /// Returns true when lhs is strictly greater than rhs (dpkg order).
    var versionIsGreater: (String, String) -> Bool = { lhs, rhs in
        DpkgWrapper.isVersion(lhs, greaterThan: rhs)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reloadFromDefaults()
    }

    func rule(for packageID: String) -> UpdateBlockRule? {
        let id = normalize(packageID)
        lock.lock(); defer { lock.unlock() }
        return rulesByID[id]
    }

    func isUpdateBlocked(packageID: String, candidateVersion: String) -> Bool {
        let id = normalize(packageID)
        guard !id.isEmpty else { return false }
        lock.lock()
        let rule = rulesByID[id]
        lock.unlock()
        guard let rule else { return false }
        switch rule.mode {
        case .permanent:
            return true
        case .maxVersion:
            guard let max = rule.maxVersion, !max.isEmpty else { return false }
            // Block when candidate is NOT strictly greater than max ⇒ candidate ≤ max
            return !versionIsGreater(candidateVersion, max)
        }
    }

    func blockPermanently(packageID: String) {
        let id = normalize(packageID)
        guard !id.isEmpty else { return }
        let rule = UpdateBlockRule(packageID: id, mode: .permanent, maxVersion: nil, createdAt: Date())
        setRule(rule)
    }

    func blockMaxVersion(packageID: String, version: String) {
        let id = normalize(packageID)
        let ver = version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !ver.isEmpty else { return }
        let rule = UpdateBlockRule(packageID: id, mode: .maxVersion, maxVersion: ver, createdAt: Date())
        setRule(rule)
    }

    func unblock(packageID: String) {
        let id = normalize(packageID)
        guard !id.isEmpty else { return }
        lock.lock()
        rulesByID.removeValue(forKey: id)
        persistLocked()
        lock.unlock()
        notify()
    }

    func clearAll() {
        lock.lock()
        rulesByID.removeAll()
        persistLocked()
        lock.unlock()
        notify()
    }

    func allRulesSorted() -> [UpdateBlockRule] {
        lock.lock()
        let values = Array(rulesByID.values)
        lock.unlock()
        return values.sorted { $0.packageID.localizedCaseInsensitiveCompare($1.packageID) == .orderedAscending }
    }

    // MARK: - Private

    private func normalize(_ packageID: String) -> String {
        packageID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func setRule(_ rule: UpdateBlockRule) {
        lock.lock()
        rulesByID[rule.packageID] = rule
        persistLocked()
        lock.unlock()
        notify()
    }

    private func reloadFromDefaults() {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: Self.storageKey) else {
            rulesByID = [:]
            return
        }
        guard let decoded = try? JSONDecoder().decode([UpdateBlockRule].self, from: data) else {
            rulesByID = [:]
            return
        }
        var map: [String: UpdateBlockRule] = [:]
        for var rule in decoded {
            rule.packageID = normalize(rule.packageID)
            if rule.packageID.isEmpty { continue }
            if rule.mode == .maxVersion {
                let v = rule.maxVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if v.isEmpty { continue }
                rule.maxVersion = v
            }
            map[rule.packageID] = rule
        }
        rulesByID = map
    }

    private func persistLocked() {
        let array = Array(rulesByID.values)
        if let data = try? JSONEncoder().encode(array) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    private func notify() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }
}
```

注意：`shared` 使用 `.standard`；测试用 `init(defaults:)`。`packageID` 规范化为 trim + lowercased（与 deb 包名惯例一致）。

- [ ] **Step 5: 跑通单元测试**

Run:

```bash
xcodebuild test -project Sileo.xcodeproj -scheme "Sileo Backend Tests" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:"Sileo Backend Tests/UpdateBlockManagerTests" 2>&1 | tail -50
```

Expected: **TEST SUCCEEDED**（若 simulator 名称不同则替换 destination）。

- [ ] **Step 6: Commit**

```bash
git add "Sileo/Backend/Update Block Manager/UpdateBlockManager.swift" \
  "Sileo Backend Tests/UpdateBlockManagerTests.swift" \
  Sileo.xcodeproj/project.pbxproj
git commit -m "feat: add UpdateBlockManager with permanent and max-version rules"
```

---

### Task 2: 在 availableUpdates 接入过滤 + 刷新通知

**Files:**
- Modify: `Sileo/Backend/Package Manager/PackageListManager.swift`（`availableUpdates()` 约 132–150 行）
- Modify: `Sileo/UI/PackageListViewController/PackageListViewController.swift`（在已有 `prefsNotification` 观察处增加对 `UpdateBlockManager.didChangeNotification` 的观察）

**Interfaces:**
- Consumes: `UpdateBlockManager.shared.isUpdateBlocked(packageID:candidateVersion:)`
- Produces: `availableUpdates()` 返回值不再包含被屏蔽包（角标与 `upgradeAll` 自动正确）

- [ ] **Step 1: 修改 `availableUpdates()`**

在版本判定成功、`append` 之前插入过滤：

```swift
public func availableUpdates() -> [(Package, Package?)] {
    var updatesAvailable: [(Package, Package?)] = []
    for package in installedPackages.values {
        guard let latestPackage = self.newestPackage(identifier: package.package, repoContext: nil) else {
            continue
        }

        if !checkRootHide(latestPackage) {
            continue
        }

        if latestPackage.version != package.version {
            if DpkgWrapper.isVersion(latestPackage.version, greaterThan: package.version) {
                if UpdateBlockManager.shared.isUpdateBlocked(
                    packageID: package.package,
                    candidateVersion: latestPackage.version
                ) {
                    continue
                }
                updatesAvailable.append((latestPackage, package))
            }
        }
    }
    return updatesAvailable.sorted { $0.0.name < $1.0.name }
}
```

- [ ] **Step 2: 列表监听屏蔽变更**

在 `PackageListViewController` 已有 `prefsNotification` 注册附近（约 197 行）增加：

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(self.reloadDataWithUpdates),
    name: UpdateBlockManager.didChangeNotification,
    object: nil
)
```

确认 `deinit` / 移除观察若项目对其他通知成对 `removeObserver`，则同样处理；若仅依赖对象释放 + `addObserver(self, selector:)` 旧 API，保持一致即可。

- [ ] **Step 3: 静态检查**

确认 `upgradeAll` 仍只调用 `availableUpdates()`，**不要**再单独过滤。

```bash
rg -n "availableUpdates\(|upgradeAll|UpdateBlockManager" "Sileo/Backend/Package Manager/PackageListManager.swift"
```

- [ ] **Step 4: 编译**

```bash
xcodebuild build -project Sileo.xcodeproj -scheme Sileo -destination 'generic/platform=iOS' 2>&1 | tail -30
```

（scheme 名以 `xcodebuild -list` 为准；失败则用工程内常用 scheme。）

- [ ] **Step 5: Commit**

```bash
git add "Sileo/Backend/Package Manager/PackageListManager.swift" \
  "Sileo/UI/PackageListViewController/PackageListViewController.swift"
git commit -m "feat: filter blocked packages from availableUpdates"
```

---

### Task 3: 本地化文案（Base + zh-Hans）

**Files:**
- Modify: `Sileo/Sileo/Base.lproj/Localizable.strings`
- Modify: `Sileo/Sileo/zh-Hans.lproj/Localizable.strings`

- [ ] **Step 1: 在 Base 中、靠近 `Package_Hold_*` / `Package_Wishlist_*` 处追加**

```
"Package_Block_Update_Action" = "Block Updates…";
"Package_Block_Update_Permanent" = "Block Permanently";
"Package_Block_Update_This_Version" = "Block This Version (%@)";
"Package_Block_Update_Unblock" = "Unblock Updates";
"Package_Block_Update_Permanent_Only" = "Block Updates Permanently";
"Blocked_Updates_Title" = "Blocked Updates";
"Blocked_Updates_Empty" = "No Blocked Updates";
"Blocked_Updates_Clear_All" = "Clear All";
"Blocked_Updates_Clear_Confirm" = "Remove all update blocks? This cannot be undone.";
"Blocked_Updates_Rule_Permanent" = "Permanent";
"Blocked_Updates_Rule_Max_Version" = "Up to %@";
"Blocked_Updates_Settings_Footer" = "Blocked packages are hidden from the Updates list and Upgrade All. Manual install is still allowed. This is separate from Ignore Future Updates (dpkg hold).";
```

- [ ] **Step 2: zh-Hans**

```
"Package_Block_Update_Action" = "屏蔽更新…";
"Package_Block_Update_Permanent" = "永久屏蔽";
"Package_Block_Update_This_Version" = "屏蔽此版本（%@）";
"Package_Block_Update_Unblock" = "取消屏蔽更新";
"Package_Block_Update_Permanent_Only" = "永久屏蔽更新";
"Blocked_Updates_Title" = "已屏蔽更新";
"Blocked_Updates_Empty" = "暂无屏蔽的更新";
"Blocked_Updates_Clear_All" = "清空全部";
"Blocked_Updates_Clear_Confirm" = "确定移除全部更新屏蔽？此操作无法撤销。";
"Blocked_Updates_Rule_Permanent" = "永久";
"Blocked_Updates_Rule_Max_Version" = "上限 %@";
"Blocked_Updates_Settings_Footer" = "被屏蔽的软件包不会出现在更新列表与“全部更新”中，仍可手动安装。此功能独立于“忽略未来的更新”（系统 Hold）。";
```

- [ ] **Step 3: Commit**

```bash
git add Sileo/Sileo/Base.lproj/Localizable.strings Sileo/Sileo/zh-Hans.lproj/Localizable.strings
git commit -m "i18n: add block updates strings (en, zh-Hans)"
```

---

### Task 4: Context Menu（列表长按）— PackageQueueButton.actionItems

**Files:**
- Modify: `Sileo/UI/PackageViewController/PackageButton/PackageQueueButton.swift`（`actionItems()` 约 187–263 行）

**说明：** `PackageListViewController` 的 context menu 调用 `pvc.actions()` → `downloadButton.actionItems()`。必须在这里加入屏蔽项，列表长按才会出现。

**Interfaces:**
- Consumes: `UpdateBlockManager.shared.rule/blockPermanently/blockMaxVersion/unblock`
- 候选版本：对已安装包用 `PackageListManager.shared.newestPackage(identifier:)` 且 `DpkgWrapper.isVersion(newest, greaterThan: installed)` 时，newest.version 作为上限锚点

- [ ] **Step 1: 在 `actionItems()` 末尾、`return actionItems` 前插入屏蔽相关项**

仅当包**已安装**时展示（与规格：已安装 / 更新列表）：

```swift
// App-layer update block (not dpkg hold)
if PackageListManager.shared.installedPackage(identifier: package.package) != nil {
    if UpdateBlockManager.shared.rule(for: package.package) != nil {
        let unblock = CSActionItem(
            title: String(localizationKey: "Package_Block_Update_Unblock"),
            image: UIImage(systemNameOrNil: "hand.raised.slash"),
            style: .default
        ) {
            UpdateBlockManager.shared.unblock(packageID: package.package)
            NotificationCenter.default.post(name: PackageListManager.prefsNotification, object: nil)
        }
        actionItems.append(unblock)
    } else {
        let permanent = CSActionItem(
            title: String(localizationKey: "Package_Block_Update_Permanent_Only"),
            image: UIImage(systemNameOrNil: "hand.raised"),
            style: .default
        ) {
            UpdateBlockManager.shared.blockPermanently(packageID: package.package)
            NotificationCenter.default.post(name: PackageListManager.prefsNotification, object: nil)
        }
        actionItems.append(permanent)

        if let newest = PackageListManager.shared.newestPackage(identifier: package.package),
           let installed = PackageListManager.shared.installedPackage(identifier: package.package),
           DpkgWrapper.isVersion(newest.version, greaterThan: installed.version) {
            let title = String(format: String(localizationKey: "Package_Block_Update_This_Version"), newest.version)
            let maxBlock = CSActionItem(
                title: title,
                image: UIImage(systemNameOrNil: "hand.raised.fill"),
                style: .default
            ) {
                UpdateBlockManager.shared.blockMaxVersion(packageID: package.package, version: newest.version)
                NotificationCenter.default.post(name: PackageListManager.prefsNotification, object: nil)
            }
            actionItems.append(maxBlock)
        }
    }
}
```

说明：Context Menu 的 `UIAction` 不支持嵌套 submenu（`CSActionItem` → 单层 `UIAction`）。用**两条平铺动作**（永久 / 此版本）代替「屏蔽更新…」二级菜单，符合 iOS 长按菜单习惯，且覆盖规格两种模式。详情页 sheet 再用真正的二级 action sheet。

- [ ] **Step 2: 编译**

```bash
xcodebuild build -project Sileo.xcodeproj -scheme Sileo -destination 'generic/platform=iOS' 2>&1 | tail -20
```

- [ ] **Step 3: Commit**

```bash
git add "Sileo/UI/PackageViewController/PackageButton/PackageQueueButton.swift"
git commit -m "feat: add block-update actions to package context menu"
```

---

### Task 5: 详情页「更多」菜单（sharePackage）

**Files:**
- Modify: `Sileo/UI/PackageViewController/PackageViewController.swift`（`sharePackage` 约 669–770 行，Hold 与 Wishlist 之间）

- [ ] **Step 1: 在 Hold 动作之后、Wishlist 之前插入 App 屏蔽**

```swift
// App-layer block updates (separate from dpkg hold above)
if installedPackage != nil {
    if UpdateBlockManager.shared.rule(for: package.package) != nil {
        let unblockApp = UIAlertAction(title: String(localizationKey: "Package_Block_Update_Unblock"), style: .default) { _ in
            UpdateBlockManager.shared.unblock(packageID: package.package)
            NotificationCenter.default.post(name: PackageListManager.prefsNotification, object: nil)
        }
        sharePopup.addAction(unblockApp)
    } else {
        var candidateVersion: String?
        if let newest = PackageListManager.shared.newestPackage(identifier: package.package),
           DpkgWrapper.isVersion(newest.version, greaterThan: installedPackage.version) {
            candidateVersion = newest.version
        }
        if let candidateVersion {
            let blockMenu = UIAlertAction(title: String(localizationKey: "Package_Block_Update_Action"), style: .default) { _ in
                let sheet = UIAlertController(title: String(localizationKey: "Package_Block_Update_Action"),
                                              message: nil,
                                              preferredStyle: .actionSheet)
                sheet.addAction(UIAlertAction(title: String(localizationKey: "Package_Block_Update_Permanent"), style: .default) { _ in
                    UpdateBlockManager.shared.blockPermanently(packageID: package.package)
                    NotificationCenter.default.post(name: PackageListManager.prefsNotification, object: nil)
                })
                let verTitle = String(format: String(localizationKey: "Package_Block_Update_This_Version"), candidateVersion)
                sheet.addAction(UIAlertAction(title: verTitle, style: .default) { _ in
                    UpdateBlockManager.shared.blockMaxVersion(packageID: package.package, version: candidateVersion)
                    NotificationCenter.default.post(name: PackageListManager.prefsNotification, object: nil)
                })
                sheet.addAction(UIAlertAction(title: String(localizationKey: "Cancel"), style: .cancel))
                if UIDevice.current.userInterfaceIdiom == .pad {
                    sheet.popoverPresentationController?.sourceView = shareButton
                }
                self.present(sheet, animated: true)
            }
            sharePopup.addAction(blockMenu)
        } else {
            let permanentOnly = UIAlertAction(title: String(localizationKey: "Package_Block_Update_Permanent_Only"), style: .default) { _ in
                UpdateBlockManager.shared.blockPermanently(packageID: package.package)
                NotificationCenter.default.post(name: PackageListManager.prefsNotification, object: nil)
            }
            sharePopup.addAction(permanentOnly)
        }
    }
}
```

保持现有 Hold 文案与逻辑不动。

- [ ] **Step 2: 编译**

```bash
xcodebuild build -project Sileo.xcodeproj -scheme Sileo -destination 'generic/platform=iOS' 2>&1 | tail -20
```

- [ ] **Step 3: Commit**

```bash
git add "Sileo/UI/PackageViewController/PackageViewController.swift"
git commit -m "feat: add block updates to package detail more menu"
```

---

### Task 6: 设置入口 + BlockedUpdatesViewController

**Files:**
- Create: `Sileo/UI/SettingsViewController/Root/BlockedUpdatesViewController.swift`
- Modify: `Sileo/UI/SettingsViewController/Root/SettingsViewController.swift`
- Modify: `Sileo.xcodeproj/project.pbxproj`

**Settings section 2 现状：** rows 0–10 为开关，row 11 为「软件源管理」。  
将 `numberOfRowsInSection` case 2 从 `12` 改为 `13`；row 12 为「已屏蔽更新」。

- [ ] **Step 1: 实现 `BlockedUpdatesViewController`**

```swift
//
//  BlockedUpdatesViewController.swift
//  Sileo
//

import UIKit

final class BlockedUpdatesViewController: BaseSettingsViewController {
    private var rules: [UpdateBlockRule] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String(localizationKey: "Blocked_Updates_Title")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: String(localizationKey: "Blocked_Updates_Clear_All"),
            style: .plain,
            target: self,
            action: #selector(clearAll)
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reload),
            name: UpdateBlockManager.didChangeNotification,
            object: nil
        )
        reload()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func reload() {
        rules = UpdateBlockManager.shared.allRulesSorted()
        navigationItem.rightBarButtonItem?.isEnabled = !rules.isEmpty
        tableView.reloadData()
    }

    @objc private func clearAll() {
        let alert = UIAlertController(
            title: String(localizationKey: "Blocked_Updates_Clear_All"),
            message: String(localizationKey: "Blocked_Updates_Clear_Confirm"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localizationKey: "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: String(localizationKey: "OK"), style: .destructive) { _ in
            UpdateBlockManager.shared.clearAll()
            NotificationCenter.default.post(name: PackageListManager.prefsNotification, object: nil)
        })
        present(alert, animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(rules.count, 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if rules.isEmpty {
            let cell = reusableCell(withStyle: .default, reuseIdentifier: "BlockedEmpty")
            cell.textLabel?.text = String(localizationKey: "Blocked_Updates_Empty")
            cell.textLabel?.textColor = .secondaryLabel
            cell.selectionStyle = .none
            cell.accessoryType = .none
            return cell
        }
        let rule = rules[indexPath.row]
        let cell = reusableCell(withStyle: .subtitle, reuseIdentifier: "BlockedRule")
        let installed = PackageListManager.shared.installedPackage(identifier: rule.packageID)
        let newest = PackageListManager.shared.newestPackage(identifier: rule.packageID)
        cell.textLabel?.text = installed?.name ?? newest?.name ?? rule.packageID
        let detail: String
        switch rule.mode {
        case .permanent:
            detail = "\(rule.packageID) · \(String(localizationKey: "Blocked_Updates_Rule_Permanent"))"
        case .maxVersion:
            let ver = rule.maxVersion ?? "?"
            detail = "\(rule.packageID) · \(String(format: String(localizationKey: "Blocked_Updates_Rule_Max_Version"), ver))"
        }
        cell.detailTextLabel?.text = detail
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !rules.isEmpty else { return }
        let rule = rules[indexPath.row]
        let pkg = PackageListManager.shared.newestPackage(identifier: rule.packageID)
            ?? PackageListManager.shared.installedPackage(identifier: rule.packageID)
        guard let pkg else { return }
        let vc = NativePackageViewController.viewController(for: pkg)
        navigationController?.pushViewController(vc, animated: true)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !rules.isEmpty else { return nil }
        let rule = rules[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: String(localizationKey: "Package_Block_Update_Unblock")) { _, _, done in
            UpdateBlockManager.shared.unblock(packageID: rule.packageID)
            NotificationCenter.default.post(name: PackageListManager.prefsNotification, object: nil)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        String(localizationKey: "Blocked_Updates_Settings_Footer")
    }
}
```

实现时注意：

- `String(localizationKey: "Confirm"…)` 若不存在，清空确认按钮用项目已有 `"OK"` 或中文确认键；可 `rg "\"Confirm\"" Sileo/Sileo/Base.lproj` 选用。
- `BaseSettingsViewController.reusableCell` API 与 `SettingsViewController` 保持一致。

- [ ] **Step 2: 修改 SettingsViewController**

1. `numberOfRowsInSection` case 2: `return 13`
2. `cellForRow` case 2：在 `indexPath.row == 11` 软件源管理分支旁增加 `row == 12`：

```swift
if indexPath.row == 12 {
    let cell = self.reusableCell(withStyle: .value1, reuseIdentifier: "BlockedUpdatesCell")
    cell.textLabel?.text = String(localizationKey: "Blocked_Updates_Title")
    cell.detailTextLabel?.text = "\(UpdateBlockManager.shared.allRulesSorted().count)"
    cell.accessoryType = .disclosureIndicator
    return cell
}
if indexPath.row == 11 {
    // existing Source Management cell
    ...
}
```

3. `didSelectRowAt` case 2：

```swift
case 2:
    if indexPath.row == 11 {
        let sourceManagementVC = SourceManagementSettingsViewController(style: .grouped)
        self.navigationController?.pushViewController(sourceManagementVC, animated: true)
    } else if indexPath.row == 12 {
        let vc = BlockedUpdatesViewController(style: .grouped)
        self.navigationController?.pushViewController(vc, animated: true)
    }
```

4. `viewWillAppear` 已 `reloadData()`，返回设置页时数量会更新。

- [ ] **Step 3: pbxproj 加入 `BlockedUpdatesViewController.swift`**

放入 Settings Root group（与 `SettingsViewController.swift` 同组），加入与 Settings 文件相同的 app target Sources。

- [ ] **Step 4: 编译**

```bash
xcodebuild build -project Sileo.xcodeproj -scheme Sileo -destination 'generic/platform=iOS' 2>&1 | tail -30
```

- [ ] **Step 5: Commit**

```bash
git add "Sileo/UI/SettingsViewController/Root/BlockedUpdatesViewController.swift" \
  "Sileo/UI/SettingsViewController/Root/SettingsViewController.swift" \
  Sileo.xcodeproj/project.pbxproj
git commit -m "feat: add blocked updates settings management UI"
```

---

### Task 7: 真机 / 模拟器集成验收（清单）

**Files:** 无新代码（除非发现 bug 再修）

- [ ] **Step 1: 跑单元测试**

```bash
xcodebuild test -project Sileo.xcodeproj -scheme "Sileo Backend Tests" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:"Sileo Backend Tests/UpdateBlockManagerTests" 2>&1 | tail -40
```

Expected: SUCCEEDED

- [ ] **Step 2: 按规格 §9 手工验收（设备或 roothide 环境）**

| # | 步骤 | 期望 |
|---|------|------|
| 1 | 更新列表长按有更新的包 → 永久屏蔽 | 立即消失，角标 -1 |
| 2 | 另一包 → 屏蔽此版本 `V` | 消失；若仅装回同版本候选仍隐藏 |
| 3 | 模拟/等待源出现 `> V` 候选（或改规则测） | 重新出现 |
| 4 | 详情更多 → 屏蔽 / 取消 | 与列表一致 |
| 5 | 已安装无更新 → 仅永久项 | 可写规则；设置页可见 |
| 6 | 设置 → 已屏蔽更新 → 滑动取消 / 清空 | 规则移除，更新可再出现 |
| 7 | 屏蔽后详情点更新/安装 | **仍可**排队 |
| 8 | Hold 与 App 屏蔽文案并存 | Hold 行为不变 |
| 9 | 全部更新 | 不含被屏蔽包 |
| 10 | 版本 `1.1.3-4~beta2` 上限 vs `1.1.3-4` | dpkg 序：正式版应大于 beta 并复活 |

- [ ] **Step 3: 若有 bugfix，修完后追加 commit**

```bash
git commit -m "fix: block updates edge case from QA"
```

- [ ] **Step 4: 最终状态**

```bash
git status -sb
git log --oneline -10
```

---

## Spec Coverage Checklist

| Spec 要求 | Task |
|-----------|------|
| permanent / maxVersion 数据模型 + UserDefaults | Task 1 |
| `isUpdateBlocked` + dpkg 序 + fail-open 无效规则 | Task 1 |
| `availableUpdates` 单点过滤 | Task 2 |
| 角标 / upgradeAll 自动跟随 | Task 2（间接） |
| 更新页彻底消失 | Task 2 |
| 不写 dpkg hold | 全局约束 + Task 4/5 不调用 hold |
| 手动安装不拦截 | 全局（无 DownloadManager 改动） |
| 列表 Context Menu | Task 4 |
| 详情更多菜单二级选择 | Task 5 |
| 已安装可永久屏蔽 | Task 4/5 |
| 设置管理页 + 清空 | Task 6 |
| Base + zh-Hans | Task 3 |
| 版本验收用例 | Task 1 单测 + Task 7 |
| 与 Hold 并存区分文案 | Task 3 footer + Task 5 位置 |

## Self-Review Notes

- 无 TBD/TODO 占位步骤
- Context Menu 使用**平铺两项**（永久 / 此版本），详情用**二级 sheet**——已在 Task 4 说明原因，与规格「双模式」等价
- `versionIsGreater` 可注入，避免单测依赖 C `compareVersion` 链接
- `packageID` lowercased 规范化：与 deb 包名大小写不敏感惯例一致
- 清空确认按钮使用现有 `"OK"` / `"Cancel"` 键

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-21-block-updates.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — 每个 Task 新开 subagent，Task 间 review，迭代快  
2. **Inline Execution** — 本会话用 executing-plans 按 Task 批量执行并设检查点  

**Which approach?**
