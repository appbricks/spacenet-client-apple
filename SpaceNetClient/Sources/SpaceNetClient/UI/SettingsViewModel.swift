// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation

protocol SettingsViewModelBinding: AnyObject {
    func populateFields()
}

class SettingsViewModel {

    enum InterfaceField: CaseIterable {
        case deviceUser
        case deviceUserKey
        case deviceName
        case deviceLockPassphrase
        case unlockedTimeout

        var localizedUIString: String {
            switch self {
            case .deviceUser: return tr("initDeviceUser")
            case .deviceUserKey: return tr("initDeviceUserKey")
            case .deviceName: return tr("initDeviceName")
            case .deviceLockPassphrase: return tr("initDevicePassphrase")
            case .unlockedTimeout: return tr("initUnlockedTimeout")
            }
        }
    }

    enum UnlockedTimeoutOption: Int {
        case to24h = 0
        case to12h
        case to1h
        case to30m
        case to15m

        var localizedUIString: String {
            switch self {
            case .to24h: return tr("timeout24h")
            case .to12h: return tr("timeout12h")
            case .to1h: return tr("timeout1h")
            case .to30m: return tr("timeout30m")
            case .to15m: return tr("timeout15m")
            }
        }

        var value: Int32 {
            switch self {
            case .to24h: return 1440
            case .to12h: return 720
            case .to1h: return 60
            case .to30m: return 30
            case .to15m: return 15
            }
        }

        var index: Int {
            return rawValue
        }
    }

    static let unlockedTimeoutOptions: [UnlockedTimeoutOption] = [.to24h, .to12h, .to1h, .to30m, .to15m]

    var binding: SettingsViewModelBinding

    var deviceUser: String = ""
    var deviceUserKey: String = ""
    var deviceName: String = ""
    var deviceLockPassphrase: String = ""
    var unlockedTimeout: UnlockedTimeoutOption = .to24h

    var needsNewKey = true
    var initialized = false

    init(_ binding: SettingsViewModelBinding,
         initialized: Bool,
         deviceUser: String,
         deviceName: String,
         deviceLockPassphrase: String,
         unlockedTimeout: Int32
    ) {
        self.binding = binding
        self.initialized = initialized

        if initialized {

            self.deviceUser = deviceUser
            self.deviceUserKey = "<uploaded>"
            self.deviceName = deviceName
            self.deviceLockPassphrase = deviceLockPassphrase
            self.needsNewKey = false

            switch unlockedTimeout {
            case 1440:
                self.unlockedTimeout = .to24h
            case 720:
                self.unlockedTimeout = .to12h
            case 60:
                self.unlockedTimeout = .to1h
            case 30:
                self.unlockedTimeout = .to30m
            case 15:
                self.unlockedTimeout = .to15m
            default:
                self.unlockedTimeout = .to24h
            }
        }
        binding.populateFields()
    }

    func reset(deviceUser: String,
               deviceName: String,
               needsNewKey: Bool
    ) {
        self.deviceUser = deviceUser
        self.deviceUserKey = ""
        self.deviceName = deviceName
        self.deviceLockPassphrase = ""
        self.unlockedTimeout = .to24h
        self.needsNewKey = needsNewKey
        self.initialized = false
        binding.populateFields()
    }
}
