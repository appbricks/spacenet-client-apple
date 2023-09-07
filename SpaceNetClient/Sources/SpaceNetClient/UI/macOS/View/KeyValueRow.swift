// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class EditableKeyValueRow: NSView {
    let keyLabel: NSTextField = {
        let keyLabel = NSTextField()
        keyLabel.isEditable = false
        keyLabel.isSelectable = false
        keyLabel.isBordered = false
        keyLabel.alignment = .right
        keyLabel.maximumNumberOfLines = 1
        keyLabel.lineBreakMode = .byTruncatingTail
        keyLabel.backgroundColor = .clear
        return keyLabel
    }()

    let valueLabel: NSTextField
    let valueImageView: NSImageView?

    var key: String {
        get { return keyLabel.stringValue }
        set(value) { keyLabel.stringValue = value }
    }
    var value: String {
        get { return valueLabel.stringValue }
        set(value) { valueLabel.stringValue = value }
    }
    var isKeyInBold: Bool {
        get { return keyLabel.font == NSFont.boldSystemFont(ofSize: 0) }
        set(value) {
            if value {
                keyLabel.font = NSFont.boldSystemFont(ofSize: 0)
            } else {
                keyLabel.font = NSFont.systemFont(ofSize: 0)
            }
        }
    }
    var valueImage: NSImage? {
        get { return valueImageView?.image }
        set(value) { valueImageView?.image = value }
    }

    var statusObservationToken: AnyObject?
    var isOnDemandEnabledObservationToken: AnyObject?
    var hasOnDemandRulesObservationToken: AnyObject?

    var valueObserver: TextFieldObserver?

    override var intrinsicContentSize: NSSize {
        let height = max(keyLabel.intrinsicContentSize.height, valueLabel.intrinsicContentSize.height)
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    convenience init() {
        self.init(hasValueImage: false, isSecure: false)
    }

    fileprivate init(hasValueImage: Bool, isSecure: Bool) {

        valueLabel = isSecure ? NSSecureTextField() : NSTextField()
        valueLabel.isSelectable = true
        valueLabel.maximumNumberOfLines = 1
        valueLabel.lineBreakMode = .byTruncatingTail
        valueImageView = hasValueImage ? NSImageView() : nil

        super.init(frame: CGRect.zero)

        addSubview(keyLabel)
        addSubview(valueLabel)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            keyLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            keyLabel.firstBaselineAnchor.constraint(equalTo: valueLabel.firstBaselineAnchor),
            self.leadingAnchor.constraint(equalTo: keyLabel.leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        ])

        let spacing: CGFloat = 5
        if let valueImageView = valueImageView {
            addSubview(valueImageView)
            valueImageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                valueImageView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
                valueImageView.leadingAnchor.constraint(equalTo: keyLabel.trailingAnchor, constant: spacing),
                valueLabel.leadingAnchor.constraint(equalTo: valueImageView.trailingAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                valueLabel.leadingAnchor.constraint(equalTo: keyLabel.trailingAnchor, constant: spacing)
            ])
        }

        keyLabel.setContentCompressionResistancePriority(.defaultHigh + 2, for: .horizontal)
        keyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let widthConstraint = keyLabel.widthAnchor.constraint(equalToConstant: 150)
        widthConstraint.priority = .defaultHigh + 1
        widthConstraint.isActive = true
    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        key = ""
        value = ""
        isKeyInBold = false
        statusObservationToken = nil
        isOnDemandEnabledObservationToken = nil
        hasOnDemandRulesObservationToken = nil

        if let valueObserver = self.valueObserver {
            valueObserver.unsuscribeFromTextDidChangeNotification()
        }
    }

    func handleValueChange(onChange: @escaping (_: String) -> Void) {
        self.valueObserver = TextFieldObserver(textField: self.valueLabel)
        self.valueObserver!.subscribeToTextDidChangeNotification { textField in
            onChange(textField.stringValue)
        }
    }
}

class KeyValueRow: EditableKeyValueRow {
    init() {
        super.init(hasValueImage: false, isSecure: false)
        valueLabel.isEditable = false
        valueLabel.isBordered = false
        valueLabel.backgroundColor = .clear
    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class KeyValueImageRow: EditableKeyValueRow {
    init() {
        super.init(hasValueImage: true, isSecure: false)
        valueLabel.isEditable = false
        valueLabel.isBordered = false
        valueLabel.backgroundColor = .clear
    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SecureKeyValueRow: EditableKeyValueRow {
    init() {
        super.init(hasValueImage: false, isSecure: true)
    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
