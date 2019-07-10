//
//  DefaultCell.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

import UIKit
import Smile

struct DefaultCellItem: Hashable {
    let color: UIColor
    let emoji: String?
    let text: String
}

class DefaultCell: UICollectionViewCell {
    @IBOutlet weak var emojiView: UILabel!
    @IBOutlet weak var label: UILabel!
    
    func bind(to item: DefaultCellItem) {
        emojiView.text = item.emoji
        emojiView.backgroundColor = item.color
        label.text = item.text
        backgroundColor = item.color.withAlphaComponent(0.3)
    }
}
