// SPDX-License-Identifier: MIT
// Copyright © 2023 AppBricks Inc. All Rights Reserved.

import Cocoa

#if SWIFT_PACKAGE
import SpaceNetKitGo
#endif

class SettingsViewController: NSViewController, SettingsViewModelBinding {

    let deviceUser: EditableKeyValueRow = {
        let deviceUser = EditableKeyValueRow()
        deviceUser.key = tr(format: "macFieldKey (%@)", SettingsViewModel.InterfaceField.deviceUser.localizedUIString)
        deviceUser.valueLabel.isEditable = false
        return deviceUser
    }()

    let resetDeviceOwnerButton: ButtonRow = {
        let loginDeviceUser = ButtonRow()
        loginDeviceUser.buttonTitle = tr("macButtonLoginDeviceUser")
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
            openDeviceUserKeyFileButtons.buttons[0].isEnabled = false
            openDeviceUserKeyFileButtons.buttons[1].title = tr("macButtonCreateKeyFile")
            openDeviceUserKeyFileButtons.buttons[1].isEnabled = false
            return openDeviceUserKeyFileButtons
        } else {
            assert(false)
        }
    }()

    let deviceName: EditableKeyValueRow = {
        let deviceName = EditableKeyValueRow()
        deviceName.key = tr(format: "macFieldKey (%@)", SettingsViewModel.InterfaceField.deviceName.localizedUIString)
        deviceName.valueLabel.isEditable = false
        return deviceName
    }()

    let devicePassphrase: SecureKeyValueRow = {
        let devicePassphrase = SecureKeyValueRow()
        devicePassphrase.key = tr(format: "macFieldKey (%@)", SettingsViewModel.InterfaceField.deviceLockPassphrase.localizedUIString)
        devicePassphrase.valueLabel.isEditable = false
        return devicePassphrase
    }()

    let setDevicePassphraseButton: ButtonRow = {
        let setDevicePassphrase = ButtonRow()
        setDevicePassphrase.buttonTitle = tr("macButtonSetPassphrase")
        setDevicePassphrase.buttons[0].isEnabled = false
        return setDevicePassphrase
    }()

    let unlockedTimeoutOptions: UnlockedTimeoutOptionsRow = {
        let unlockedTimeoutOptions = UnlockedTimeoutOptionsRow()
        unlockedTimeoutOptions.key = tr(format: "macFieldKey (%@)", SettingsViewModel.InterfaceField.unlockedTimeout.localizedUIString)
        unlockedTimeoutOptions.unlockedTimeoutOptionsPopup.isEnabled = false
        return unlockedTimeoutOptions
    }()

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

    var settingsViewModel: SettingsViewModel?
    var configLoadError = false

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        snSettingsInit(Unmanaged.passUnretained(self).toOpaque()) { context, ok, initialized, deviceUser, deviceName, deviceLockPassphrase, unlockedTimeout in
            guard
                let context = context,
                let deviceUser = deviceUser,
                let deviceName = deviceName,
                let deviceLockPassphrase = deviceLockPassphrase
            else { return }

            let unretainedSelf = Unmanaged<SettingsViewController>.fromOpaque(context).takeUnretainedValue()

            unretainedSelf.configLoadError = (ok == 0)
            if !unretainedSelf.configLoadError {
                unretainedSelf.settingsViewModel = SettingsViewModel(
                    unretainedSelf,
                    initialized: initialized == 1,
                    deviceUser: String(cString: deviceUser),
                    deviceName: String(cString: deviceName),
                    deviceLockPassphrase: String(cString: deviceLockPassphrase),
                    unlockedTimeout: unlockedTimeout
                )
            }
        }

        populateFields()

        saveButton.target = self
        saveButton.action = #selector(handleSaveAction)

        discardButton.target = self
        discardButton.action = #selector(handleDiscardAction)

        resetDeviceOwnerButton.onButtonClicked = handleResetDeviceOwner
        openDeviceUserKeyFileButtons.onButtonClicked = handleOpenDeviceUserKeyFile
        setDevicePassphraseButton.onButtonClicked = handleSetDevicePassphrase

        deviceName.handleValueChange { [weak self] deviceName in
            guard
                let self = self,
                let settingsViewModel = self.settingsViewModel
            else { return }

            settingsViewModel.deviceName = deviceName
            self.populateFields()
        }

        unlockedTimeoutOptions.handleOptionChange { unlockedTimeout in
            guard let settingsViewModel = self.settingsViewModel else { return }
            settingsViewModel.unlockedTimeout = unlockedTimeout
        }

        let margin: CGFloat = 20
        let internalSpacing: CGFloat = 5

        let editorStackView = NSStackView(views: [
            deviceUser, resetDeviceOwnerButton,
            deviceUserKey, openDeviceUserKeyFileButtons,
            deviceName,
            devicePassphrase, setDevicePassphraseButton,
            unlockedTimeoutOptions
        ])
        editorStackView.orientation = .vertical
        editorStackView.setHuggingPriority(.defaultHigh, for: .horizontal)
        editorStackView.spacing = internalSpacing
        editorStackView.setCustomSpacing(15, after: resetDeviceOwnerButton)
        editorStackView.setCustomSpacing(15, after: openDeviceUserKeyFileButtons)
        editorStackView.setCustomSpacing(15, after: deviceName)
        editorStackView.setCustomSpacing(15, after: setDevicePassphraseButton)
        editorStackView.edgeInsets.bottom = CGFloat(10)

        let buttonRowStackView = NSStackView()
        buttonRowStackView.setViews([
            discardButton,
            saveButton
        ], in: .trailing)
        buttonRowStackView.orientation = .horizontal
        buttonRowStackView.spacing = internalSpacing
        buttonRowStackView.edgeInsets.top = CGFloat(10)

        let title = TitleLabel()
        title.stringValue = "Settings"
        let lineSeparator1 = NSBox()
        lineSeparator1.boxType = .separator
        let lineSeparator2 = NSBox()
        lineSeparator2.boxType = .separator

        let containerView = NSStackView(views: [
            title,
            lineSeparator1,
            editorStackView,
            lineSeparator2,
            buttonRowStackView
        ])
        containerView.orientation = .vertical
        containerView.edgeInsets = NSEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
        containerView.setHuggingPriority(.defaultHigh, for: .horizontal)
        containerView.spacing = internalSpacing
        containerView.setCustomSpacing(15, after: title)
        containerView.setCustomSpacing(15, after: lineSeparator1)
        containerView.setCustomSpacing(15, after: lineSeparator2)

        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 240)
        ])
        containerView.frame = NSRect(x: 0, y: 0, width: 600, height: 0)

        self.view = containerView

        // **** UI TESTS
//        testInputButton.target = self
//        testInputButton.action = #selector(handleTestInputAction)
//        testNotifyButton.target = self
//        testNotifyButton.action = #selector(handleTestNotifyAction)
//        buttonRowStackView.addView(testInputButton, in: .trailing)
//        buttonRowStackView.addView(testNotifyButton, in: .trailing)
        // ****
    }

    override func viewWillAppear() {
        setDialogHandlers(target: self)
    }

    override func viewDidLoad() {

        if self.configLoadError {
            DispatchQueue.main.async { [weak self ] in
                guard
                    let self = self
                else { return }

                if let window = self.view.window {
                    _ = showSimpleDialog(
                        window: window,
                        dialogType: SN_DIALOG_ERROR,
                        title: "Error",
                        msg: "Unable to create device config initializer.",
                        accessoryType: SN_DIALOG_ACCESSORY_NONE
                    ) { _, _ in
                        self.presentingViewController?.dismiss(self)
                    }
                }
            }

        } else if snEULAAccepted() == 0 {
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
        guard let settingsViewModel = self.settingsViewModel else { return }

        self.deviceUser.value = settingsViewModel.deviceUser
        self.deviceUserKey.value = settingsViewModel.deviceUserKey

        if settingsViewModel.initialized {
            self.resetDeviceOwnerButton.buttonTitle = tr("macButtonResetDeviceUser")
        } else {
            self.resetDeviceOwnerButton.buttonTitle = tr("macButtonLoginDeviceUser")
        }

        if settingsViewModel.needsNewKey {
            openDeviceUserKeyFileButtons.buttons[0].title = tr("macButtonOpenKeyFile")
            openDeviceUserKeyFileButtons.buttons[1].title = tr("macButtonCreateKeyFile")
        } else {
            openDeviceUserKeyFileButtons.buttons[0].title = tr("macButtonOpenKeyFile")
            openDeviceUserKeyFileButtons.buttons[1].title = tr("macButtonUpdateKeyFile")
        }
        if settingsViewModel.deviceUser.isEmpty {
            openDeviceUserKeyFileButtons.buttons[0].isEnabled = false
            openDeviceUserKeyFileButtons.buttons[1].isEnabled = false
        } else if settingsViewModel.needsNewKey {
            openDeviceUserKeyFileButtons.buttons[0].isEnabled = true
            openDeviceUserKeyFileButtons.buttons[1].isEnabled = true
        } else {
            openDeviceUserKeyFileButtons.buttons[0].isEnabled = !settingsViewModel.initialized
            openDeviceUserKeyFileButtons.buttons[1].isEnabled = !settingsViewModel.deviceUserKey.isEmpty
        }

        self.deviceName.value = settingsViewModel.deviceName
        self.deviceName.valueLabel.isEditable =
            !settingsViewModel.initialized &&
            !settingsViewModel.deviceUser.isEmpty &&
            !settingsViewModel.deviceUserKey.isEmpty

        self.devicePassphrase.value = settingsViewModel.deviceLockPassphrase
        self.setDevicePassphraseButton.buttons[0].isEnabled =
            !settingsViewModel.deviceUser.isEmpty &&
            !settingsViewModel.deviceUserKey.isEmpty &&
            !settingsViewModel.deviceName.isEmpty

        if self.unlockedTimeoutOptions.unlockedTimeoutOptionsPopup.indexOfSelectedItem != settingsViewModel.unlockedTimeout.index {
            self.unlockedTimeoutOptions.unlockedTimeoutOptionsPopup.selectItem(at: settingsViewModel.unlockedTimeout.index)
        }
        self.unlockedTimeoutOptions.unlockedTimeoutOptionsPopup.isEnabled = !settingsViewModel.deviceLockPassphrase.isEmpty
        self.saveButton.isEnabled = !settingsViewModel.deviceLockPassphrase.isEmpty
    }

    func handleResetDeviceOwner(_: Int) {
        snSettingsResetDeviceOwner(Unmanaged.passUnretained(self).toOpaque()) { context, username, devicename, needsKey in
            guard
                let context = context,
                let username = username,
                let devicename = devicename
            else { return }

            let deviceUser = String(cString: username)
            let deviceName = String(cString: devicename)

            let unretainedSelf = Unmanaged<SettingsViewController>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { [weak unretainedSelf ] in
                guard
                    let unretainedSelf = unretainedSelf
                else { return }

                unretainedSelf.settingsViewModel!.reset(
                    deviceUser: deviceUser,
                    deviceName: deviceName,
                    needsNewKey: (needsKey == 1)
                )
            }
        }
    }

    func handleOpenDeviceUserKeyFile(i: Int) {
        guard
            let window = self.view.window,
            let settingsViewModel = self.settingsViewModel
        else { return }

        let context = Unmanaged.passUnretained(self).toOpaque()
        if i == 0 {
            let openPanel = NSOpenPanel()
            openPanel.prompt = tr("macButtonOpenKeyFile")
            openPanel.allowedFileTypes = ["pem"]
            openPanel.allowsMultipleSelection = false
            openPanel.beginSheetModal(for: window) { response in
                guard response == .OK else { return }
                snSettingsLoadUserKey(context, openPanel.urls[0].absoluteString, FALSE) { context, ok, fileName in
                    guard
                        let context = context,
                        let fileName = fileName
                    else { return }

                    if ok == 1 {
                        let unretainedSelf = Unmanaged<SettingsViewController>.fromOpaque(context).takeUnretainedValue()
                        unretainedSelf.setKeyFileName(withValue: String(cString: fileName))
                    }
                }
            }

        } else {
            let savePanel = NSSavePanel()
            if settingsViewModel.needsNewKey {
                savePanel.prompt = tr("macButtonCreateKeyFile")
            } else {
                savePanel.prompt = tr("macButtonUpdateKeyFile")
            }
            savePanel.nameFieldStringValue = "key.pem"
            savePanel.isExtensionHidden = false
            savePanel.beginSheetModal(for: window) { response in
                guard response == .OK else { return }
                snSettingsLoadUserKey(context, savePanel.url?.absoluteString, TRUE) { context, ok, fileName in
                    guard
                        let context = context,
                        let fileName = fileName
                    else { return }

                    if ok == 1 {
                        let unretainedSelf = Unmanaged<SettingsViewController>.fromOpaque(context).takeUnretainedValue()
                        unretainedSelf.setKeyFileName(withValue: String(cString: fileName))
                    }
                }
            }
        }
    }

    func setKeyFileName(withValue: String) {
        DispatchQueue.main.async { [weak self] in
            guard
                let self = self
            else { return }

            self.settingsViewModel!.deviceUserKey = withValue
            self.populateFields()
        }
    }

    func handleSetDevicePassphrase(i: Int) {

        if let window = self.view.window {
            _ = showSimpleDialog(
                window: window,
                dialogType: SN_DIALOG_ALERT,
                title: "Device Lock Passphrase",
                msg: "Please enter a passphrase to unlock the device",
                accessoryType: SN_DIALOG_ACCESSORY_PASSWORD_INPUT_WITH_VERIFY
            ) { [weak self] ok, passphrase in
                if let self = self, ok {
                    self.settingsViewModel!.deviceLockPassphrase = passphrase
                    self.populateFields()
                }
            }
        }
    }

    @objc func handleSaveAction() {
        if let model = self.settingsViewModel {
            self.discardButton.isEnabled = false
            self.saveButton.isEnabled = false

            snSettingsSave(Unmanaged.passUnretained(self).toOpaque(), model.deviceName, model.deviceLockPassphrase, model.unlockedTimeout.value) { context, ok in
                guard
                    let context = context
                else { return }

                let unretainedSelf = Unmanaged<SettingsViewController>.fromOpaque(context).takeUnretainedValue()
                if ok == 1 {
                    DispatchQueue.main.async { [weak unretainedSelf ] in
                        guard
                            let unretainedSelf = unretainedSelf
                        else { return }

                        unretainedSelf.presentingViewController?.dismiss(unretainedSelf)
                    }
                    snInitializeContext(unretainedSelf.settingsViewModel!.deviceLockPassphrase)

                } else {
                    unretainedSelf.discardButton.isEnabled = true
                    unretainedSelf.saveButton.isEnabled = true
                }
            }
        } else {
            self.presentingViewController?.dismiss(self)
        }
    }

    @objc func handleDiscardAction() {
        self.presentingViewController?.dismiss(self)
    }

    // **** UI TESTS
//    @objc func handleTestInputAction() {
//        let context = Unmanaged.passUnretained(self).toOpaque()
//        snTESTdialogInput(context) { context, dialogType, title, msg, defaultInput, inputContext, inputHandler in
//            guard
//                let context = context,
//                let title = title,
//                let msg = msg,
//                let defaultInput = defaultInput,
//                let inputHandler = inputHandler
//            else { return }
//
//            let unretainedSelf = Unmanaged<SettingsViewController>.fromOpaque(context).takeUnretainedValue()
//            if let window = unretainedSelf.view.window {
//
//                let inTitle = String(cString: title)
//                let inMsg = String(cString: msg)
//                let inDefaultInput = String(cString: defaultInput)
//
//                _ = showSimpleDialog(
//                    window: window,
//                    dialogType: dialogType,
//                    title: inTitle,
//                    msg: inMsg,
//                    accessoryType: SN_DIALOG_ACCESSORY_TEXT_INPUT,
//                    accessoryText: inDefaultInput
//                ) { ok, result in
//                    inputHandler(inputContext, ok ? 1 : 0, (result as NSString).utf8String)
//                }
//            }
//        }
//    }
//    @objc func handleTestNotifyAction() {
//        snTESTdialogNotifyAndInput(Unmanaged.passUnretained(self).toOpaque())
//    }
    // ****
}
