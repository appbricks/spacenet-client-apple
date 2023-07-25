// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

enum SpaceNetClientResult<T> {
    case success(_ value: T)
    case failure(_ error: SpaceNetClientError)

    var value: T? {
        switch self {
        case .success(let value): return value
        case .failure: return nil
        }
    }

    var error: SpaceNetClientError? {
        switch self {
        case .success: return nil
        case .failure(let error): return error
        }
    }

    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
}
