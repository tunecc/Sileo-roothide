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
