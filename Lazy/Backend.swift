//
//  Backend.swift
//  Lazy
//
//  Created by Tobias Schröpf on 14.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

import Foundation
import Smile

struct ColorEmoji {
    let color: UIColor
    let emoji: String
    let emojiName: String
    
    fileprivate static func random() -> ColorEmoji {
        let emoji = emojiList.randomElement()!
        return ColorEmoji(color: UIColor.random(), emoji: emoji.value, emojiName: emoji.key)
    }
}

class Backend {
    struct Constants {
        static let simulatedDatasetSize = 20
    }
    
    private let dispatchQueue = DispatchQueue(label: "Backend worker queue")
    
    func loadEmojis(skip: Int, top: Int, callback: @escaping ([ColorEmoji]?, Error?) -> Void) {
        
        dispatchQueue.asyncAfter(deadline: .now() + 0.3) {
            if !(0 ..< Constants.simulatedDatasetSize).contains(skip) {
//                callback(nil, LoadingError.internalError(message: "error loading items from index \(index)"))
                callback(nil, nil)
                return
            }
            
            var result = [ColorEmoji]()
            
            for _ in skip ..< min(skip + top, Constants.simulatedDatasetSize) {
                result.append(ColorEmoji.random())
            }
            
            callback(result, nil)
        }
    }
}
