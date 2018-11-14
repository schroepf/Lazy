//
//  ViewModel.swift
//  Lazy
//
//  Created by Tobias Schröpf on 12.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

import DeepDiff
import Foundation
import Smile

extension DefaultCellItem {
    struct Constants {
        static let errorColor = UIColor(hexString: "c62828")!
        static let errorEmoji = emojiList["no_entry"]!
        
        static let loadingColor = UIColor(hexString: "9e9e9e")!
        static let loadingEmoji = emojiList["sleeping"]!
    }
    
    fileprivate static func from(result: LazyResult<ColorEmoji>?) -> DefaultCellItem {
        if let error = result?.error {
            let text = (error as? LoadingError)?.description ?? "unknown"
            return DefaultCellItem(color: Constants.errorColor, emoji: Constants.errorEmoji, text: text)
        }
        
        if let item = result?.value {
            return DefaultCellItem(color: item.color, emoji: item.emoji, text: item.emojiName)
        }
        
        return DefaultCellItem(color: Constants.loadingColor, emoji: Constants.loadingEmoji, text: "loading...")
    }
}

class ViewModel {
    
    struct Constants {
        static let maxPageSize = 7
    }
    
    let backend = Backend()
    
    var callback: (([DefaultCellItem]?, [DefaultCellItem]?, [Int]) -> ())? = nil
    
    var currentPlaceholders: [Int] = [Int]()
    var currentItems: [DefaultCellItem] = [DefaultCellItem]()

    private lazy var cache = LazyList<ColorEmoji>(
        onLoadBefore: { (index, onSuccess, onError) in
            print("fetching items BEFORE index: \(index)")
            
            // randomize the size of the generated page - but don't return an empty list!
            let pageSize: Int = Int.random(in: 0...Constants.maxPageSize)
            self.backend.loadEmojis(skip: index - 1 - pageSize, top: pageSize, callback: { (result, error) in
                if let error = error {
                    onError(error)
                    return
                }
                
                onSuccess(result)
            })
    },
        onLoadItem: { (index, onSuccess, onError) in
            print("fetching item AT index: \(index)")
            
            self.backend.loadEmojis(skip: index, top: 1, callback: { (result, error) in
                if let error = error {
                    onError(error)
                    return
                }
                
                onSuccess(result?.first)
            })
    },
        onLoadAfter: { (index, onSuccess, onError) in
            print("fetching items AFTER index: \(index)")
            
            let pageSize = Int.random(in: 0...Constants.maxPageSize)
            self.backend.loadEmojis(skip: index + 1, top: pageSize, callback: { (result, error) in
                if let error = error {
                    onError(error)
                    return
                }
                
                onSuccess(result)
            })
    },
        onChanged: { [weak self] in
            self?.update()
    })
    
    init() {
        update()
    }
    
    func item(at index: Int) -> DefaultCellItem {
        return DefaultCellItem.from(result: cache[index])
    }
    
    func prefetch(index: Int) {
        cache.prefetch(index: index)
    }
    
    private func update() {
        let items = cache.items()
        
        let oldItems = self.currentItems
        currentItems = items.map { DefaultCellItem.from(result: $0) }
        currentPlaceholders = items.enumerated().filter { $0.element == nil }.map { $0.offset }
        
        callback?(oldItems, currentItems, currentPlaceholders)
    }
}
