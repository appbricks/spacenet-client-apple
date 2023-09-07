// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class SpaceNetContextMenu {

    var snCfgStatus: UInt8

    weak var windowDelegate: StatusMenuWindowDelegate?

    var settingsMenuItem: NSMenuItem
    var loginMenuItem: NSMenuItem

    init(addTo: NSMenu, windowDelegate: StatusMenuWindowDelegate) {

        self.windowDelegate = windowDelegate
        self.snCfgStatus = SN_CFG_STATUS_NEEDS_INIT

        let settingsMenuItem = NSMenuItem(title: tr("macMenuInit"), action: nil, keyEquivalent: "")
        addTo.addItem(settingsMenuItem)
        self.settingsMenuItem = settingsMenuItem

        let loginMenuItem = NSMenuItem(title: tr("macMenuLogin"), action: nil, keyEquivalent: "")
        addTo.addItem(loginMenuItem)
        self.loginMenuItem = loginMenuItem

        self.settingsMenuItem.target = self
        self.loginMenuItem.target = self

        // snInitialize callback
        snRegisterStatusChangeHandler(Unmanaged.passUnretained(self).toOpaque()) { context, snCfgStatus in
            guard let context = context else { return }
            let unretainedSelf = Unmanaged<SpaceNetContextMenu>.fromOpaque(context).takeUnretainedValue()
            unretainedSelf.update(snCfgStatus: snCfgStatus)
        }
    }

    func update(snCfgStatus: UInt8) {
        self.settingsMenuItem.title = tr("macMenuSettings")
        self.settingsMenuItem.action = nil
        self.loginMenuItem.title = tr("macMenuLogin")
        self.loginMenuItem.action = nil

        let isOwnerLoggedIn = (snIsLoggedInUserOwner() == 1)

        switch snCfgStatus {
        case SN_CFG_STATUS_NEEDS_INIT:
            self.settingsMenuItem.title = tr("macMenuInit")
            self.settingsMenuItem.action = #selector(settingsClicked)

        case SN_CFG_STATUS_NEEDS_LOGIN, SN_CFG_STATUS_LOGGED_OUT:
            self.loginMenuItem.title = tr("macMenuLogin")
            self.loginMenuItem.action = #selector(loginClicked)

        case SN_CFG_STATUS_LOGGED_IN:
            if isOwnerLoggedIn {
                self.settingsMenuItem.action = #selector(settingsClicked)
            }
            if let username = snLoggedInUser() {
                self.loginMenuItem.title = tr(format: "macMenuLogout (%@)", String(cString: username))
                free(UnsafeMutableRawPointer(mutating: username))
            } else {
                self.loginMenuItem.title = tr(format: "macMenuLogout (%@)", "??")
            }

            self.loginMenuItem.action = #selector(logoutClicked)

        case SN_CFG_STATUS_LOCKED:
            self.loginMenuItem.title = tr("macMenuUnlock")
            self.loginMenuItem.action = #selector(unlockClicked)

        default:
            assertionFailure("unknown spacenet config status code")
        }

        self.snCfgStatus = snCfgStatus
    }

    @objc func settingsClicked() {
        guard let windowDelegate = self.windowDelegate else { return }
        windowDelegate.showManageTunnelsWindow { manageTunnelsWindow in
            guard let manageTunnelsWindow = manageTunnelsWindow else { return }

            let settingsVC = SettingsViewController()
            manageTunnelsWindow.contentViewController?.presentAsSheet(settingsVC)
        }
    }

    @objc func unlockClicked() {
        self.loginMenuItem.action = nil

        guard let windowDelegate = self.windowDelegate else { return }
        windowDelegate.showManageTunnelsWindow { [weak self] manageTunnelsWindow in
            guard
                let self = self,
                let manageTunnelsWindow = manageTunnelsWindow
            else { return }

            _ = showSimpleDialog(
                window: manageTunnelsWindow,
                dialogType: SN_DIALOG_ALERT,
                title: "Device Lock Passphrase",
                msg: "Please enter a passphrase to unlock the device",
                accessoryType: SN_DIALOG_ACCESSORY_PASSWORD_INPUT
            ) { [weak self] ok, passphrase in
                guard
                    let self = self
                else { return }

                if ok {
                    if snInitializeContext(passphrase) == 0 {
                        _ = showSimpleDialog(
                            window: manageTunnelsWindow,
                            dialogType: SN_DIALOG_ERROR,
                            title: "Error",
                            msg: "Failed to unlock device.",
                            accessoryType: SN_DIALOG_ACCESSORY_NONE
                        ) { _, _ in }
                    }
                } else {
                    self.update(snCfgStatus: self.snCfgStatus)
                }
            }
        }
    }

    @objc func loginClicked() {
        self.loginMenuItem.action = nil

        guard let windowDelegate = self.windowDelegate else { return }
        windowDelegate.showManageTunnelsWindow { manageTunnelsWindow in
            guard let manageTunnelsWindow = manageTunnelsWindow else { return }

            snLogin(Unmanaged.passUnretained(manageTunnelsWindow.contentViewController!).toOpaque()) { context, ok in
                if ok == 0 {
                    guard let context = context else { return }
                    let settingsVC = Unmanaged<SettingsViewController>.fromOpaque(context).takeUnretainedValue()

                    DispatchQueue.main.async { [weak settingsVC] in
                        guard let settingsVC = settingsVC else { return }

                        _ = showSimpleDialog(
                            window: settingsVC.view.window!,
                            dialogType: SN_DIALOG_ERROR,
                            title: "Error",
                            msg: "Login failed.",
                            accessoryType: SN_DIALOG_ACCESSORY_NONE
                        ) { _, _ in }
                    }
                }
            }
        }
    }

    @objc func logoutClicked() {
        if snLogout() == 0 {
            DispatchQueue.main.async { [weak self ] in
                guard
                    let self = self
                else { return }

                if let windowDelegate = self.windowDelegate {
                    windowDelegate.showManageTunnelsWindow { manageTunnelsWindow in
                        guard let manageTunnelsWindow = manageTunnelsWindow else { return }

                        _ = showSimpleDialog(
                            window: manageTunnelsWindow,
                            dialogType: SN_DIALOG_ERROR,
                            title: "Error",
                            msg: "Logout failed",
                            accessoryType: SN_DIALOG_ACCESSORY_NONE
                        ) { _, _ in
                        }
                    }
                }
            }
        }
    }
}
