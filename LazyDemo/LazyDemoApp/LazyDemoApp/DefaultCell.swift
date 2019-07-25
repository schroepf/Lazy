//
//  DefaultCell.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

import DeepDiff
import Smile
import UIKit

struct DefaultCellItem: Hashable {
    let color: UIColor
    let emoji: String?
    let text: String
}

class DefaultCell: UICollectionViewCell {
    @IBOutlet var emojiView: UILabel!
    @IBOutlet var label: UILabel!

    func bind(to item: DefaultCellItem) {
        emojiView.text = item.emoji
        emojiView.backgroundColor = item.color
        label.text = item.text
        backgroundColor = item.color.withAlphaComponent(0.3)
    }
}

extension DefaultCellItem: DiffAware {
    public var diffId: Int {
        return hashValue
    }

    public static func compareContent(_ one: DefaultCellItem, _ other: DefaultCellItem) -> Bool {
        return one == other
    }
}
