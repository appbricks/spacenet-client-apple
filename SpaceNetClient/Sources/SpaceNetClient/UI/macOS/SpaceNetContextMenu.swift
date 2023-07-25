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

        let settingsMenuItem = NSMenuItem(title: tr("macMenuInit"), action: #selector(settingsClicked), keyEquivalent: "")
        addTo.addItem(settingsMenuItem)
        self.settingsMenuItem = settingsMenuItem

        let loginMenuItem = NSMenuItem(title: tr("macMenuLogin"), action: nil, keyEquivalent: "")
        addTo.addItem(loginMenuItem)
        self.loginMenuItem = loginMenuItem

        self.settingsMenuItem.target = self
        self.loginMenuItem.target = self

        // snInitialize callback
        let context = Unmanaged.passUnretained(self).toOpaque()
        snRegisterStatusChangeHandler(context) { context, snCfgStatus in
            guard let context = context else { return }
            let unretainedSelf = Unmanaged<SpaceNetContextMenu>.fromOpaque(context).takeUnretainedValue()
            unretainedSelf.update(snCfgStatus: snCfgStatus)
        }
    }

    func update(snCfgStatus: UInt8) {

        self.settingsMenuItem.title = tr("macMenuSettings")
        self.loginMenuItem.title = tr("macMenuLogin")
        self.loginMenuItem.action = nil

        switch snCfgStatus {
        case SN_CFG_STATUS_NEEDS_INIT:
            self.settingsMenuItem.title = tr("macMenuInit")

        case SN_CFG_STATUS_NEEDS_LOGIN, SN_CFG_STATUS_LOGGED_OUT:
            self.loginMenuItem.title = tr("macMenuLogin")
            self.loginMenuItem.action = #selector(loginClicked)

        case SN_CFG_STATUS_LOGGED_IN:
            self.loginMenuItem.title = tr(format: "macMenuLogout (%@)", "userX")
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
        print("UNLOCK SN CFG!!")
    }

    @objc func loginClicked() {
        print("LOGIN TO SN!!")
    }

    @objc func logoutClicked() {
        print("LOGOUT FROM SN!!")
    }
}
