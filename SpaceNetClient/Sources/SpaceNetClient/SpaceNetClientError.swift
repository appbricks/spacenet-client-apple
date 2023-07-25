// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

protocol SpaceNetClientError: Error {
    typealias AlertText = (title: String, message: String)

    var alertText: AlertText { get }
}
