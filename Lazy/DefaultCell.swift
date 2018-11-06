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
    
    func bind(to data: UIColor) {
        imageView.backgroundColor = data
        label.text = data.toHexString()
        
        backgroundColor = data.withAlphaComponent(0.3)
    }
}
