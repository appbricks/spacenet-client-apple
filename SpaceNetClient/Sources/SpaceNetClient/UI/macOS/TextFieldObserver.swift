// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class TextFieldObserver {

    var textField: NSTextField

    var onChange: ((_: NSTextField) -> Void)?

    init(textField: NSTextField) {
        self.textField = textField
    }

    func subscribeToTextDidChangeNotification(onChange: @escaping (_: NSTextField) -> Void) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textFieldDidChange(_:)),
            name: NSControl.textDidChangeNotification,
            object: self.textField
        )
        self.onChange = onChange
    }

    func unsuscribeFromTextDidChangeNotification() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSControl.textDidChangeNotification,
            object: self.textField
        )
    }

    @objc func textFieldDidChange(_ notification: Notification) {
        if let onChange = self.onChange, let textField = notification.object as? NSTextField {
            onChange(textField)
        }
    }
}
