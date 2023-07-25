// SPDX-License-Identifier: MIT
// Copyright © 2023 AppBricks Inc. All Rights Reserved.

import Cocoa

#if SWIFT_PACKAGE
import SpaceNetKitGo
#endif

class SettingsViewController: NSViewController {

    let deviceUser: EditableKeyValueRow = {
        let deviceUser = EditableKeyValueRow()
        deviceUser.key = tr(format: "macFieldKey (%@)", SettingsViewModel.InterfaceField.deviceUser.localizedUIString)
        deviceUser.valueLabel.isEditable = false
        return deviceUser
    }()

    let loginDeviceUserButton: ButtonRow = {
        let loginDeviceUser = ButtonRow()
        loginDeviceUser.buttonTitle = tr("macButtonLogin")
        return loginDeviceUser
    }()

    let deviceUserKey: EditableKeyValueRow = {
        let deviceUserKey = EditableKeyValueRow()
        deviceUserKey.key = tr(format: "macFieldKey (%@)", SettingsViewModel.InterfaceField.deviceUserKey.localizedUIString)
        deviceUserKey.valueLabel.isEditable = false
        return deviceUserKey
    }()

    let openDeviceUserKeyFileButtons: ButtonRow = {
        if let openDeviceUserKeyFileButtons = ButtonRow(numButtons: 2) {
            openDeviceUserKeyFileButtons.buttons[0].title = tr("macButtonOpenKeyFile")
            openDeviceUserKeyFileButtons.buttons[1].title = tr("macButtonCreateKeyFile")
            return openDeviceUserKeyFileButtons
        } else {
            assert(false)
        }
    }()

    let deviceName: EditableKeyValueRow = {
        let deviceName = EditableKeyValueRow()
        deviceName.key = tr(format: "macFieldKey (%@)", SettingsViewModel.InterfaceField.deviceName.localizedUIString)
        return deviceName
    }()

    let unlockTimeout = UnlockTimeoutControls()

    let discardButton: NSButton = {
        let button = NSButton()
        button.title = tr("macEditDiscard")
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .rounded
        return button
    }()

    let saveButton: NSButton = {
        let button = NSButton()
        button.title = tr("macEditSave")
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .rounded
        button.keyEquivalent = "s"
        button.keyEquivalentModifierMask = [.command]
        return button
    }()

    let testInputButton: NSButton = {
        let button = NSButton()
        button.title = "Test Input"
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .rounded
        return button
    }()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        populateFields()

        saveButton.target = self
        saveButton.action = #selector(handleSaveAction)

        discardButton.target = self
        discardButton.action = #selector(handleDiscardAction)

        testInputButton.target = self
        testInputButton.action = #selector(handleTestInputAction)

        loginDeviceUserButton.onButtonClicked = handleLoginDeviceUser
        openDeviceUserKeyFileButtons.onButtonClicked = handleOpenDeviceUserKeyFile

        let margin: CGFloat = 20
        let internalSpacing: CGFloat = 10

        let editorStackView = NSStackView(views: [deviceUser, loginDeviceUserButton, deviceUserKey, openDeviceUserKeyFileButtons, deviceName ])
        editorStackView.orientation = .vertical
        editorStackView.setHuggingPriority(.defaultHigh, for: .horizontal)
        editorStackView.spacing = internalSpacing

        let buttonRowStackView = NSStackView()
        buttonRowStackView.setViews([discardButton, saveButton, testInputButton], in: .trailing)
        buttonRowStackView.orientation = .horizontal
        buttonRowStackView.spacing = internalSpacing

        let containerView = NSStackView(views: [editorStackView, buttonRowStackView])
        containerView.orientation = .vertical
        containerView.edgeInsets = NSEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
        containerView.setHuggingPriority(.defaultHigh, for: .horizontal)
        containerView.spacing = internalSpacing

        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 240)
        ])
        containerView.frame = NSRect(x: 0, y: 0, width: 600, height: 480)

        self.view = containerView
    }

    func populateFields() {

    }

    func handleLoginDeviceUser(_: Int) {
//        guard let window = self.view.window else { return }
//        let alertDialog = NSAlert()
//        alertDialog.addButton(withTitle: "OK")
//        alertDialog.addButton(withTitle: "Cancel")
//        alertDialog.messageText = "a title"
//        alertDialog.informativeText = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
//        alertDialog.addButton(withTitle: "Cancel")

//        let txt = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
//        txt.stringValue = defaultValue
//        alertDialog.accessoryView = txt

//        Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { timer in
//            print("Timer fired!")
//            window.endSheet(alertDialog.window)
//            alertDialog.window.close()
//        }
//
//        alertDialog.beginSheetModal(for: window) { modalResponse in
//            if modalResponse == .alertFirstButtonReturn {
//                print("button clicked")
//            } else {
//                print("window closed")
//            }
//        }
    }

    func handleOpenDeviceUserKeyFile(i: Int) {
        guard let window = self.view.window else { return }
        if i == 0 {
            let openPanel = NSOpenPanel()
            openPanel.prompt = tr("macButtonOpenKeyFile")
            openPanel.allowedFileTypes = ["pem"]
            openPanel.allowsMultipleSelection = false
            openPanel.beginSheetModal(for: window) { response in
                guard response == .OK else { return }
                print(openPanel.urls)
            }

        } else {
            let savePanel = NSSavePanel()
            savePanel.prompt = tr("macButtonCreateKeyFile")
            savePanel.nameFieldStringValue = "key.pem"
            savePanel.isExtensionHidden = false
            savePanel.beginSheetModal(for: window) { response in
                guard response == .OK else { return }
                print(savePanel.url)
            }

        }
    }

    @objc func handleSaveAction() {
        self.presentingViewController?.dismiss(self)
    }

    @objc func handleDiscardAction() {
        self.presentingViewController?.dismiss(self)
    }

    @objc func handleTestInputAction() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        snTESTdialogInput(context) { context, _, title, msg, inputContext, inputHandler in
            guard
                let context = context,
                let title = title,
                let msg = msg,
                let inputHandler = inputHandler
            else { return }

            let unretainedSelf = Unmanaged<SettingsViewController>.fromOpaque(context).takeUnretainedValue()
            if let window = unretainedSelf.view.window {

                let inTitle = String(cString: title)
                let inMsg = String(cString: msg)

                getInput(window: window, title: inTitle, msg: inMsg, defaultValue: "") { (ok: Bool, result: String) in
                    inputHandler(inputContext, ok ? 1 : 0, (result as NSString).utf8String)
                }
            }
        }
    }
}
