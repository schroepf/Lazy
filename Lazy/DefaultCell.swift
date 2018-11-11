//
//  DefaultCell.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

import UIKit
import Smile

typealias Emoji = (key: String, value: String)

struct DefaultCellItem {
    let color: UIColor
    let emoji: Emoji
}

class DefaultCell: UICollectionViewCell {
    @IBOutlet weak var emojiView: UILabel!
    @IBOutlet weak var label: UILabel!
    
    func bind(to data: LazyResult<DefaultCellItem>?) {
        if let error = data?.error {
            let errorColor = UIColor(hexString: "c62828") ?? UIColor.red
            emojiView.text = emojiList["no_entry"]
            emojiView.backgroundColor = errorColor
            
            if let error = error as? LoadingError {
                label.text = error.description
            } else {
                label.text = "Unknown"
            }
            
            backgroundColor = errorColor.withAlphaComponent(0.3)
            return
        }
        
        if let item = data?.value {
            label.text = item.emoji.key
            emojiView.text = item.emoji.value
            emojiView.backgroundColor = UIColor.white.withAlphaComponent(0.6)
            
            backgroundColor = item.color.withAlphaComponent(0.3)
            return
        }
        
        let placeholderColor = UIColor(hexString: "9e9e9e") ?? UIColor.black
        let emoji = emojiList["sleeping"]
        emojiView.text = emoji
        emojiView.backgroundColor = placeholderColor
        label.text = "loading..."
        backgroundColor = placeholderColor.withAlphaComponent(0.3)    }
}
