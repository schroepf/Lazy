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
            return DefaultCellItem(color: item.color, emoji: item.emoji, text: "\(item.index): \(item.emojiName)")
        }
        
        return DefaultCellItem(color: Constants.loadingColor, emoji: Constants.loadingEmoji, text: "loading...")
    }
}

class ViewModel {
    enum Constants {
        static let maxPageSize = 20
        static let maxContentSize = 250
    }
    
    let backend = Backend()
    
    private var currentPlaceholders: [Int] = [Int]()
    private var currentItems: [DefaultCellItem]? = [DefaultCellItem]()
    
    var callback: (([DefaultCellItem]?, [DefaultCellItem]?, [Int], [Change<DefaultCellItem>]?) -> ())? = nil {
        willSet {
            // reset currentPlaceholders and currentItems to make sure the next call to callback uses the correct values again...
//            currentPlaceholders = [Int]()
//            currentItems = [DefaultCellItem]()
//            cache.clear()
        }
        didSet {
//            // reset currentPlaceholders and currentItems to make sure the next call to callback uses the correct values again...
//            currentPlaceholders = [Int]()
//            currentItems = nil
//            cache.clear()
//            update()
        }
    }

    private lazy var cache = LazyList<ColorEmoji>(
        onLoadBefore: { (index, onSuccess, onError) in
            log.debug("fetching items BEFORE index: \(index)")
            
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
            log.debug("fetching item AT index: \(index)")
            
            self.backend.loadEmojis(skip: index, top: 1, callback: { (result, error) in
                if let error = error {
                    onError(error)
                    return
                }
                
                onSuccess(result?.first)
            })
    },
        onLoadAfter: { (index, onSuccess, onError) in
            log.debug("fetching items AFTER index: \(index)")
            if index + 1 >= Constants.maxContentSize {
                onSuccess(nil)
                return
            }
            let pageSize = min(Int.random(in: 1...Constants.maxPageSize), Constants.maxContentSize - (index + 1))
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
//        return currentItems![index]
    }
    
    func prefetch(index: Int) {
        cache.prefetch(index: index)
    }
    
    func count() -> Int {
        guard let currentItems = currentItems else {
            return 0
        }
        
        return currentItems.count
    }
    
    private func update() {
        DispatchQueue.main.async {
            let items = self.cache.items()
            let oldItems = self.currentItems
            log.info("will update currentItems from \(oldItems?.count ?? 0) to \(items.count)")
            self.currentItems = items.map { DefaultCellItem.from(result: $0) }
            log.debug("did update currentItems from \(oldItems?.count ?? 0) to \(items.count) [\(oldItems?.last?.emoji ?? "nil") -> \(self.currentItems?.last?.emoji ?? "nil")]")
            self.currentPlaceholders = items.enumerated().filter { $0.element == nil }.map { $0.offset }
            
            guard let old = oldItems, let new = self.currentItems else {
                self.callback?(oldItems, self.currentItems, self.currentPlaceholders, nil)
                return
            }
            
            let changes = diff(old: old, new: new)
            
            guard !changes.isEmpty else {
                self.callback?(oldItems, self.currentItems, self.currentPlaceholders, nil)
                return
            }
            
            self.callback?(oldItems, self.currentItems, self.currentPlaceholders, changes)
        }
    }
}
