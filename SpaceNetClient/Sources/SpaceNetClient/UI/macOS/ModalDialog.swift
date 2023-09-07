// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa
import Down
import DSFSecureTextField

// swiftlint:disable:next function_parameter_count
func showSimpleDialog(
    window: NSWindow,
    dialogType: UInt8,
    title: String,
    msg: String,
    accessoryType: UInt8,
    accessoryText: String = "",
    onDone: @escaping (_: Bool, _: String) -> Void
) -> NSAlert? {

    let alertDialog = NSAlert()
    alertDialog.messageText = title
    alertDialog.informativeText = msg

    let defResponseHandler: (_: NSApplication.ModalResponse) -> Void = { modalResponse in
        if modalResponse == .alertFirstButtonReturn {
            onDone(true, "")
        } else {
            onDone(false, "")
        }
    }

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

    switch accessoryType {
    case SN_DIALOG_ACCESSORY_TEXT_INPUT:
        let textInput = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textInput.stringValue = accessoryText
        alertDialog.accessoryView = textInput

        alertDialog.addButton(withTitle: "OK")
        alertDialog.addButton(withTitle: "Cancel")
        alertDialog.beginSheetModal(for: window) { modalResponse in
            if modalResponse == .alertFirstButtonReturn {
                onDone(true, textInput.stringValue)
            } else {
                onDone(false, "")
            }
        }

    case SN_DIALOG_ACCESSORY_PASSWORD_INPUT:
        let passwd = DSFSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        passwd.placeholderString = "password"
        passwd.allowPasswordInPlainText = true
        let accView = NSStackView(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        accView.setViews([passwd], in: .top)
        accView.orientation = .vertical
        alertDialog.accessoryView = accView

        alertDialog.addButton(withTitle: "OK")
        alertDialog.addButton(withTitle: "Cancel")

        alertDialog.buttons[0].isEnabled = false
        let observer = TextFieldObserver(textField: passwd)
        observer.subscribeToTextDidChangeNotification { textField in
            alertDialog.buttons[0].isEnabled = !textField.stringValue.isEmpty
        }

        alertDialog.beginSheetModal(for: window) { modalResponse in
            if modalResponse == .alertFirstButtonReturn {
                onDone(true, passwd.stringValue)
            } else {
                onDone(false, "")
            }
            observer.unsuscribeFromTextDidChangeNotification()
        }

    case SN_DIALOG_ACCESSORY_PASSWORD_INPUT_WITH_VERIFY:
        let passwd = DSFSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        passwd.placeholderString = "password"
        passwd.allowPasswordInPlainText = true
        let verify = DSFSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        verify.placeholderString = "verify password"
        verify.allowPasswordInPlainText = true

        let accView = NSStackView(frame: NSRect(x: 0, y: 0, width: 200, height: 58))
        accView.setViews([passwd, verify], in: .top)
        accView.orientation = .vertical
        accView.spacing = CGFloat(10)
        alertDialog.accessoryView = accView

        alertDialog.addButton(withTitle: "OK")
        alertDialog.addButton(withTitle: "Cancel")

        alertDialog.buttons[0].isEnabled = false
        let observer = TextFieldObserver(textField: verify)
        observer.subscribeToTextDidChangeNotification { _ in
            alertDialog.buttons[0].isEnabled = !passwd.stringValue.isEmpty && passwd.stringValue == verify.stringValue
        }

        alertDialog.beginSheetModal(for: window) { modalResponse in
            if modalResponse == .alertFirstButtonReturn {
                onDone(true, passwd.stringValue)
            } else {
                onDone(false, "")
            }
            observer.unsuscribeFromTextDidChangeNotification()
        }

    case SN_DIALOG_ACCESSORY_FILE_OPEN:
        let openPanel = NSOpenPanel()
        openPanel.prompt = title
        openPanel.message = msg
        openPanel.allowsMultipleSelection = false

        if !accessoryText.isEmpty {
            let openDelegate = OpenDelegate(accessoryText)
            openPanel.delegate = openDelegate
        }

        openPanel.beginSheetModal(for: window) { response in
            if response == .OK {
                onDone(true, String(openPanel.urls[0].absoluteString.dropFirst("file://".count)))
            } else {
                onDone(false, "")
            }
        }

        return nil

    case SN_DIALOG_ACCESSORY_SPINNER:
        let spinnerImage = NSImage(data: NSDataAsset(name: "SpinningGlobe")!.data)
        let spinnerView = NSImageView(image: spinnerImage!)
        spinnerView.imageScaling = .scaleProportionallyDown
        spinnerView.animates = true
        let textView = NSTextField()
        textView.isEditable = false
        textView.isSelectable = false
        textView.isBordered = false
        textView.alignment = .center
        textView.lineBreakMode = .byWordWrapping
        textView.backgroundColor = .clear
        textView.stringValue = accessoryText
        let accView = NSStackView(frame: NSRect(x: 0, y: 0, width: 200, height: 150))
        accView.setViews([spinnerView, textView], in: .top)
        accView.distribution = .fill
        accView.orientation = .vertical
        alertDialog.accessoryView = accView

        alertDialog.addButton(withTitle: "Dismiss")
        alertDialog.beginSheetModal(for: window) { modalResponse in
            defResponseHandler(modalResponse)
        }

    default:
        if !accessoryText.isEmpty {
            let textView = NSTextView()
            textView.isEditable = false
            if let rect = textView.layoutManager?.usedRect(for: textView.textContainer!) {
                textView.layoutManager?.ensureLayout(for: textView.textContainer!)
                textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
                textView.frame = NSRect(x: 0, y: 0, width: 300, height: rect.height)
            }
            let down = Down(markdownString: accessoryText)
            if let attributedString = try? down.toAttributedString(DownOptions(rawValue: 1 << 2)) {
                textView.textStorage?.setAttributedString(attributedString)
                textView.usesAdaptiveColorMappingForDarkAppearance = true
                alertDialog.accessoryView = textView
            }
        }

        switch accessoryType {
        case SN_DIALOG_ACCESSORY_YES_NO:
            alertDialog.addButton(withTitle: "Yes")
            alertDialog.addButton(withTitle: "No")
        case SN_DIALOG_ACCESSORY_OK_CANCEL:
            alertDialog.addButton(withTitle: "OK")
            alertDialog.addButton(withTitle: "Cancel")
        default:
            alertDialog.addButton(withTitle: "Dismiss")
        }
        alertDialog.beginSheetModal(for: window) { modalResponse in
            defResponseHandler(modalResponse)
        }
    }

    return alertDialog
}

func setDialogHandlers(target: NSViewController) {
    let context = Unmanaged.passUnretained(target).toOpaque()
    snRegisterShowDialogFunc(context) { context, dialogType, title, msg, accessoryType, accessoryText, dispatchToMain, inputContext in
        guard
            let context = context,
            let title = title,
            let msg = msg,
            let accessoryText = accessoryText
        else { return nil }

        let inTitle = String(cString: title)
        let inMsg = String(cString: msg)
        let inAccessoryText = String(cString: accessoryText)

        let unretainedSelf = Unmanaged<NSViewController>.fromOpaque(context).takeUnretainedValue()
        if dispatchToMain == 0 {

            if let window = unretainedSelf.view.window {
                let alertDialog = showSimpleDialog(
                    window: window,
                    dialogType: dialogType,
                    title: inTitle,
                    msg: inMsg,
                    accessoryType: accessoryType,
                    accessoryText: inAccessoryText
                ) { ok, result in
                    snHandleDialogInput(inputContext, ok ? 1 : 0, (result as NSString).utf8String)
                }
                if let alertDialog = alertDialog {
                    return Unmanaged.passUnretained(alertDialog).toOpaque()
                }
            }

        } else {
            DispatchQueue.main.async {
                if let window = unretainedSelf.view.window {
                    let alertDialog = showSimpleDialog(
                        window: window,
                        dialogType: dialogType,
                        title: inTitle,
                        msg: inMsg,
                        accessoryType: accessoryType,
                        accessoryText: inAccessoryText
                    ) { ok, result in
                        snHandleDialogInput(inputContext, ok ? 1 : 0, (result as NSString).utf8String)
                    }
                    if let alertDialog = alertDialog {
                        snAssociateDialogInputToHandle(inputContext, Unmanaged.passUnretained(alertDialog).toOpaque())
                    }
                }
            }
        }

        return nil
    }
    snSetDialogDismissHandler(context) {context, handle in
        guard
            let context = context,
            let handle = handle
        else { return }

        let unretainedSelf = Unmanaged<NSViewController>.fromOpaque(context).takeUnretainedValue()
        let unretainedAlertDialog = Unmanaged<NSAlert>.fromOpaque(handle).takeUnretainedValue()
        DispatchQueue.main.async { [weak unretainedSelf, weak unretainedAlertDialog] in
            guard
                let unretainedAlertDialog = unretainedAlertDialog,
                let unretainedSelf = unretainedSelf
            else { return }

            if let window = unretainedSelf.view.window {
                window.endSheet(unretainedAlertDialog.window)
            }
        }
    }
}

func resetDialogHandlers(target: NSViewController) {
    snUnregisterShowDialogFunc(Unmanaged.passUnretained(target).toOpaque())
}

class OpenDelegate: NSObject, NSOpenSavePanelDelegate {
    private var allowedTypes: [String] = []

    init(_ types: String) {
        self.allowedTypes = types.components(separatedBy: ",")
    }
    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        if url.isFileURL && !url.hasDirectoryPath {
            return allowedTypes.contains(url.pathExtension)
        }
        return false
    }
}
