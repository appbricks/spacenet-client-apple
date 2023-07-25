// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation

class SettingsViewModel {

    enum InterfaceField: CaseIterable {
        case deviceUser
        case deviceUserKey
        case deviceName
        case passphrase
        case unlockTimeout

        var localizedUIString: String {
            switch self {
            case .deviceUser: return tr("initDeviceUser")
            case .deviceUserKey: return tr("initDeviceUserKey")
            case .deviceName: return tr("initDeviceName")
            case .passphrase: return tr("initPassphrase")
            case .unlockTimeout: return tr("initUnlockTimeout")
            }
        }
    }

}
