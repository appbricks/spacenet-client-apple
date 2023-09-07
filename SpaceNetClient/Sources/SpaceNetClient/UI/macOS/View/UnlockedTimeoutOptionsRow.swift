// SPDX-License-Identifier: MIT
// Copyright © 2023 AppBricks, Inc. All Rights Reserved.

import Cocoa

class UnlockedTimeoutOptionsRow: NSView {
    let keyLabel: NSTextField = {
        let keyLabel = NSTextField()
        keyLabel.stringValue = tr("macFieldUnlockedTimeout")
        keyLabel.isEditable = false
        keyLabel.isSelectable = false
        keyLabel.isBordered = false
        keyLabel.alignment = .right
        keyLabel.maximumNumberOfLines = 1
        keyLabel.lineBreakMode = .byTruncatingTail
        keyLabel.backgroundColor = .clear
        return keyLabel
    }()

    var key: String {
        get { return keyLabel.stringValue }
        set(value) { keyLabel.stringValue = value }
    }

    let unlockedTimeoutOptionsPopup = NSPopUpButton()

    private var onChange: ((_: SettingsViewModel.UnlockedTimeoutOption) -> Void)?

    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: unlockedTimeoutOptionsPopup.intrinsicContentSize.height)
    }

    init() {
        super.init(frame: CGRect.zero)

        unlockedTimeoutOptionsPopup.addItems(withTitles: SettingsViewModel.unlockedTimeoutOptions.map { $0.localizedUIString })

        addSubview(keyLabel)
        addSubview(unlockedTimeoutOptionsPopup)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        unlockedTimeoutOptionsPopup.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            keyLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            keyLabel.firstBaselineAnchor.constraint(equalTo: unlockedTimeoutOptionsPopup.firstBaselineAnchor),
            self.leadingAnchor.constraint(equalTo: keyLabel.leadingAnchor),
            unlockedTimeoutOptionsPopup.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            unlockedTimeoutOptionsPopup.leadingAnchor.constraint(equalTo: keyLabel.trailingAnchor, constant: CGFloat(5))
        ])

        keyLabel.setContentCompressionResistancePriority(.defaultHigh + 2, for: .horizontal)
        keyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        unlockedTimeoutOptionsPopup.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let widthConstraint = keyLabel.widthAnchor.constraint(equalToConstant: 150)
        widthConstraint.priority = .defaultHigh + 1
        widthConstraint.isActive = true
    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func handleOptionChange(onChange: @escaping (_: SettingsViewModel.UnlockedTimeoutOption) -> Void) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(optionDidChange(_:)),
            name: NSMenu.didSendActionNotification,
            object: self.unlockedTimeoutOptionsPopup.menu
        )
        self.onChange = onChange
    }

//    override func viewWillMove(toSuperview newSuperview: NSView?) {
//        super.viewWillMove(toSuperview: newSuperview)
//        print("blah1")
//    }
//
//    override func viewDidHide() {
//        super.viewDidHide()
//        print("blah2")
//    }

    @objc func optionDidChange(_ notification: Notification) {

        if let onChange = self.onChange {
            onChange(SettingsViewModel.unlockedTimeoutOptions[self.unlockedTimeoutOptionsPopup.indexOfSelectedItem])
        }
    }
}
