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
