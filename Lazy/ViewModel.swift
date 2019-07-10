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
    
    static func from(result: LazyResult<ColorEmoji>?) -> DefaultCellItem {
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
        static let maxContentSize = 50
    }
    
    let backend = Backend()

    private let currentItemsAccess = DispatchQueue(label: "CurrentItemsAccessQueue")

    private var currentItems: [DefaultCellItem]? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.callback?(oldValue, self.currentItems)
            }
        }
    }
    
    var callback: (([DefaultCellItem]?, [DefaultCellItem]?) -> ())? = nil

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
                    log.error("loading item AT index: \(index) failed with error: \(error)")
                    onError(error)
                    return
                }

                log.debug("loading item AT index: \(index) finished successfully")
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
                    log.error("loading item AFTER index: \(index) failed with error: \(error)")
                    onError(error)
                    return
                }

                log.debug("loading item AT index: \(index) finished successfully (pageSize: \(result?.count), requestedSize: \(pageSize)")
                onSuccess(result)
            })
    },
        onChanged: { [weak self] in
            log.debug("ZEFIX - calling update()")
            self?.update()
    })
    
    init() {
        self.currentItems = nil
    }
    
    func item(at index: Int) -> DefaultCellItem {
        return DefaultCellItem.from(result: cache[index])
    }
    
    func prefetch(index: Int) {
        cache.prefetch(index: index)
    }

    func reload() {
        cache.clear()
    }

    private func update() {
        currentItemsAccess.async {
            self.currentItems = self.cache.items().map { DefaultCellItem.from(result: $0) }

            let placeholders = self.currentItems?.enumerated()
                .filter { $0.element == nil }
                .map { $0.offset }
        }
    }
}
