//
//  DefaultCell.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

import UIKit

class DefaultCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    
    func bind(to data: LazyResult<UIColor>?) {
        if let error = data?.error {
            let errorColor = UIColor(hexString: "c62828") ?? UIColor.red
            imageView.backgroundColor = errorColor
            
            if let error = error as? LoadingError {
                label.text = error.description
            } else {
                label.text = "Unknown"
            }
            
            backgroundColor = errorColor.withAlphaComponent(0.3)
            return
        }
        
        if let color = data?.value {
            imageView.backgroundColor = color
            label.text = color.toHexString()
            
            backgroundColor = color.withAlphaComponent(0.3)
            return
        }
        
        let placeholderColor = UIColor(hexString: "9e9e9e") ?? UIColor.black
        imageView.backgroundColor = placeholderColor
        label.text = "loading..."
        backgroundColor = placeholderColor.withAlphaComponent(0.3)    }
}
