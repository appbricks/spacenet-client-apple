// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

func showSimpleDialog(window: NSWindow, dialogType: UInt8, title: String, msg: String, defaultValue: String = "", withTextInput: Bool, onDone: @escaping (_: Bool, _: String) -> Void) -> NSAlert {

    let alertDialog = NSAlert()
    alertDialog.messageText = title
    alertDialog.informativeText = msg

    switch dialogType {
    case SN_DIALOG_NOTIFY:
        alertDialog.icon = NSImage(named: "NotifyInfo")
    case SN_DIALOG_ALERT:
        alertDialog.icon = NSImage(named: "NotifyAlert")
    case SN_DIALOG_ERROR:
        alertDialog.icon = NSImage(named: "NotifyError")
    default:
        alertDialog.icon = nil
    }

    if withTextInput {
        alertDialog.addButton(withTitle: "OK")
        alertDialog.addButton(withTitle: "Cancel")

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

    } else {
        alertDialog.addButton(withTitle: "Dismiss")

        alertDialog.beginSheetModal(for: window) { modalResponse in
            if modalResponse == .alertFirstButtonReturn {
                onDone(true, "")
            } else {
                onDone(false, "")
            }
        }
    }

    return alertDialog
}

func setDialogHandlers(target: NSViewController) {
    let context = Unmanaged.passUnretained(target).toOpaque()
    snRegisterShowDialogFunc(context) { context, dialogType, title, msg, withTextInput, inputContext in
        assert(withTextInput == 0)
        guard
            let context = context,
            let title = title,
            let msg = msg
        else { return nil }

        let unretainedSelf = Unmanaged<NSViewController>.fromOpaque(context).takeUnretainedValue()
        if let window = unretainedSelf.view.window {

            let inTitle = String(cString: title)
            let inMsg = String(cString: msg)

            let alertDialog = showSimpleDialog(
                window: window,
                dialogType: dialogType,
                title: inTitle,
                msg: inMsg,
                withTextInput: withTextInput == 1
            ) { ok, result in
                snHandleDialogInput(inputContext, ok ? 1 : 0, (result as NSString).utf8String)
            }
            return Unmanaged.passUnretained(alertDialog).toOpaque()
        } else {
            return nil
        }
    }
    snSetDialogDismissHandler(context) {_, handle in
        guard
            let handle = handle
        else { return }

        let unretainedAlertDialog = Unmanaged<NSAlert>.fromOpaque(handle).takeUnretainedValue()
        DispatchQueue.main.async { [weak unretainedAlertDialog ] in
            guard
                let unretainedAlertDialog = unretainedAlertDialog
            else { return }

            // NOTE: do not need `window.endSheet(unretainedAlertDialog.window)`
            unretainedAlertDialog.window.close()
        }
    }
}

func resetDialogHandlers(target: NSViewController) {
    snUnregisterShowDialogFunc(Unmanaged.passUnretained(target).toOpaque())
}
