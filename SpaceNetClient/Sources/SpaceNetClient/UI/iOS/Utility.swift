// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

func showNotification(window: NSWindow, title: String, msg: String, onDone: @escaping (_: Bool) -> Void) {

    let alertDialog = NSAlert()
    alertDialog.addButton(withTitle: "Dismiss")
    alertDialog.messageText = title
    alertDialog.informativeText = msg

    alertDialog.beginSheetModal(for: window) { modalResponse in
        if modalResponse == .alertFirstButtonReturn {
            onDone(true)
        } else {
            onDone(false)
        }
    }
}

func getInput(window: NSWindow, title: String, msg: String, defaultValue: String, onDone: @escaping (_: Bool, _: String) -> Void) {

    let alertDialog = NSAlert()
    alertDialog.addButton(withTitle: "OK")
    alertDialog.addButton(withTitle: "Cancel")
    alertDialog.messageText = title
    alertDialog.informativeText = msg

    let txt = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
    txt.stringValue = defaultValue
    alertDialog.accessoryView = txt

    alertDialog.beginSheetModal(for: window) { modalResponse in
        if modalResponse == .alertFirstButtonReturn {
            onDone(true, txt.stringValue)
        } else {
            onDone(false, "")
        }
    }
}
