// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class ButtonRow: NSView {
    var buttons: [NSButton] = []

    var buttonTitle: String {
        get { return buttons[0].title }
        set(value) { buttons[0].title = value }
    }

    var isButtonEnabled: Bool {
        get { return buttons[0].isEnabled }
        set(value) { buttons[0].isEnabled = value }
    }

    var buttonToolTip: String {
        get { return buttons[0].toolTip ?? "" }
        set(value) { buttons[0].toolTip = value }
    }

    var onButtonClicked: ((_: Int) -> Void)?
    var statusObservationToken: AnyObject?
    var isOnDemandEnabledObservationToken: AnyObject?
    var hasOnDemandRulesObservationToken: AnyObject?

    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: buttons[0].intrinsicContentSize.height)
    }

    init() {
        super.init(frame: CGRect.zero)
        initButtonList(numButtons: 1)
    }

    required init?(numButtons: Int) {
        super.init(frame: CGRect.zero)
        initButtonList(numButtons: numButtons)
    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func initButtonList(numButtons: Int) {
        assert(numButtons > 0)

        for _ in 0...numButtons-1 {
            let button = NSButton()
            button.title = ""
            button.setButtonType(.momentaryPushIn)
            button.bezelStyle = .rounded
            button.target = self
            button.action = #selector(buttonClicked)

            buttons.append(button)
        }

        if numButtons > 1 {
            let internalSpacing: CGFloat = 10

            let buttonRowStackView = NSStackView()
            buttonRowStackView.setViews(buttons, in: .trailing)
            buttonRowStackView.orientation = .horizontal
            buttonRowStackView.spacing = internalSpacing

            addSubview(buttonRowStackView)
            buttonRowStackView.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                buttonRowStackView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
                buttonRowStackView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 155),
                buttonRowStackView.widthAnchor.constraint(greaterThanOrEqualToConstant: 100)
            ])

        } else {
            addSubview(buttons[0])
            buttons[0].translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                buttons[0].centerYAnchor.constraint(equalTo: self.centerYAnchor),
                buttons[0].leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 155),
                buttons[0].widthAnchor.constraint(greaterThanOrEqualToConstant: 100)
            ])
        }
    }

    @objc func buttonClicked(button: NSButton) {
        for i in 0...buttons.count-1 where buttons[i] === button {
            onButtonClicked?(i)
            break
        }
    }

    override func prepareForReuse() {
        buttonTitle = ""
        buttonToolTip = ""
        onButtonClicked = nil
        statusObservationToken = nil
        isOnDemandEnabledObservationToken = nil
        hasOnDemandRulesObservationToken = nil
    }
}
