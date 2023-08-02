// SPDX-License-Identifier: MIT
// Copyright © 2023 AppBricks Inc. All Rights Reserved.

import Cocoa

#if SWIFT_PACKAGE
import SpaceNetKitGo
#endif

class SettingsViewController: NSViewController, NSTextFieldDelegate {

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

    let testNotifyButton: NSButton = {
        let button = NSButton()
        button.title = "Test Notify"
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

        loginDeviceUserButton.onButtonClicked = handleLoginDeviceUser
        openDeviceUserKeyFileButtons.onButtonClicked = handleOpenDeviceUserKeyFile

        let margin: CGFloat = 20
        let internalSpacing: CGFloat = 10

        let editorStackView = NSStackView(views: [deviceUser, loginDeviceUserButton, deviceUserKey, openDeviceUserKeyFileButtons, deviceName ])
        editorStackView.orientation = .vertical
        editorStackView.setHuggingPriority(.defaultHigh, for: .horizontal)
        editorStackView.spacing = internalSpacing

        let buttonRowStackView = NSStackView()
        buttonRowStackView.setViews([discardButton, saveButton], in: .trailing)
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

        // **** UI TESTS
        testInputButton.target = self
        testInputButton.action = #selector(handleTestInputAction)
        testNotifyButton.target = self
        testNotifyButton.action = #selector(handleTestNotifyAction)
        buttonRowStackView.addView(testInputButton, in: .trailing)
        buttonRowStackView.addView(testNotifyButton, in: .trailing)
        // ****
    }

    override func viewWillAppear() {
        setDialogHandlers(target: self)
    }

    override func viewDidLoad() {
        if snEULAAccepted() == 0 {
            DispatchQueue.main.async { [weak self ] in
                guard
                    let self = self
                else { return }

                if let window = self.view.window {
                    _ = showSimpleDialog(
                        window: window,
                        dialogType: SN_DIALOG_ALERT,
                        title: "Terms of Use",
                        msg: "",
                        accessoryType: SN_DIALOG_ACCESSORY_YES_NO,
                        accessoryText: "Before you can use the MyCS SpaceNet client you need to review and accept the [AppBricks, Inc. Software End User Agreement](https://appbricks.io/eula/).\n\nDo you agree to the terms?"
                    ) { ok, _ in
                        if ok {
                            snSetEULAAccepted()
                        } else {
                            self.presentingViewController?.dismiss(self)
                        }
                    }
                }
            }
        }
    }

    override func viewDidDisappear() {
        resetDialogHandlers(target: self)
    }

    func populateFields() {
    }

    func handleLoginDeviceUser(_: Int) {
        snAuthenticate(Unmanaged.passUnretained(self).toOpaque()) { context, username in
            guard
                let context = context,
                let username = username
            else { return }

            let unretainedSelf = Unmanaged<SettingsViewController>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { [weak unretainedSelf ] in
                guard
                    let unretainedSelf = unretainedSelf
                else { return }

                unretainedSelf.deviceUser.value = String(cString: username)
            }
        }
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

        if let window = self.view.window {
            _ = showSimpleDialog(
                window: window,
                dialogType: SN_DIALOG_ALERT,
                title: "SpaceNet Config Locked",
                msg: "Please enter the passphrase to unlock the configuration",
                accessoryType: SN_DIALOG_ACCESSORY_PASSWORD_INPUT_WITH_VERIFY
            ) { ok, passphrase in
                if ok {
                    print("passphrase: " + passphrase)
                } else {
                    print("canceled")
                }
            }
        }

//        self.presentingViewController?.dismiss(self)
    }

    @objc func handleDiscardAction() {
        self.presentingViewController?.dismiss(self)
    }

    // **** UI TESTS
    @objc func handleTestInputAction() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        snTESTdialogInput(context) { context, dialogType, title, msg, defaultInput, inputContext, inputHandler in
            guard
                let context = context,
                let title = title,
                let msg = msg,
                let defaultInput = defaultInput,
                let inputHandler = inputHandler
            else { return }

            let unretainedSelf = Unmanaged<SettingsViewController>.fromOpaque(context).takeUnretainedValue()
            if let window = unretainedSelf.view.window {

                let inTitle = String(cString: title)
                let inMsg = String(cString: msg)
                let inDefaultInput = String(cString: defaultInput)

                _ = showSimpleDialog(
                    window: window,
                    dialogType: dialogType,
                    title: inTitle,
                    msg: inMsg,
                    accessoryType: SN_DIALOG_ACCESSORY_TEXT_INPUT,
                    accessoryText: inDefaultInput
                ) { ok, result in
                    inputHandler(inputContext, ok ? 1 : 0, (result as NSString).utf8String)
                }
            }
        }
    }
    @objc func handleTestNotifyAction() {
        snTESTdialogNotifyAndInput(Unmanaged.passUnretained(self).toOpaque())
    }
    // ****
}
