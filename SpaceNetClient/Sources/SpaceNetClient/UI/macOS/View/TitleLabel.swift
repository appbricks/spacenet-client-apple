// SPDX-License-Identifier: MIT
// Copyright © 2023 AppBricks, Inc. All Rights Reserved.

import Cocoa

class TitleLabel: NSTextField {

    var text: String = "" {
        didSet { super.stringValue = text }
    }

    init() {
        super.init(frame: .zero)

        self.isBezeled = false
        self.drawsBackground = false
        self.isEditable = false
        self.isSelectable = false
        self.alignment = .center

        self.font = NSFont.boldSystemFont(ofSize: 18)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
