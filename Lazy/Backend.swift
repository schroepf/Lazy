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
    let index: Int
    let color: UIColor
    let emoji: String
    let emojiName: String
    
    fileprivate static func create(index: Int) -> ColorEmoji {
        let emoji = emojiList.randomElement()!
        return ColorEmoji(index: index, color: UIColor.random(), emoji: emoji.value, emojiName: emoji.key)
    }
}

class Backend {
    struct Constants {
        static let simulatedDatasetSize = 2000
        static let simulatedDelay = 0.02
    }
    
    private let dispatchQueue = DispatchQueue(label: "Backend worker queue")
    
    func loadEmojis(skip: Int, top: Int, callback: @escaping ([ColorEmoji]?, Error?) -> Void) {
        
        dispatchQueue.asyncAfter(deadline: .now() + Constants.simulatedDelay) {
            guard (0 ..< Constants.simulatedDatasetSize).contains(skip) else {
//                callback(nil, LoadingError.internalError(message: "error loading items from index \(index)"))
                callback(nil, nil)
                return
            }
            
            var result = [ColorEmoji]()
            
            for i in skip ..< min(skip + top, Constants.simulatedDatasetSize) {
                result.append(ColorEmoji.create(index: i))
            }

            log.debug("loading emojis: \(result.map { $0.emoji })")
            callback(result, nil)
        }
    }
}
