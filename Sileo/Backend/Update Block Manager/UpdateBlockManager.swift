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
