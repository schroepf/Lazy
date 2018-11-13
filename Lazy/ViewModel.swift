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

struct ColorEmoji {
    let color: UIColor
    let emoji: String
    let emojiName: String
    
    fileprivate static func random() -> ColorEmoji {
        let emoji = emojiList.randomElement()!
        return ColorEmoji(color: UIColor.random(), emoji: emoji.value, emojiName: emoji.key)
    }
}

extension DefaultCellItem {
    fileprivate static func from(result: LazyResult<ColorEmoji>?) -> DefaultCellItem {
        if let error = result?.error {
            let text = (error as? LoadingError)?.description ?? "unknown"
            return DefaultCellItem(color: UIColor(hexString: "c62828")!, emoji: emojiList["no_entry"]!, text: text)
        }
        
        
        if let item = result?.value {
            return DefaultCellItem(color: item.color, emoji: item.emoji, text: item.emojiName)
        }
        
        return DefaultCellItem(color: UIColor(hexString: "9e9e9e")!, emoji: emojiList["sleeping"]!, text: "loading...")
    }
}

class ViewModel {
    private lazy var cache = PagedLazyList<ColorEmoji>(onLoadPage: { (pageIndex, onSuccess, onError) in
        print("fetching page at index: \(pageIndex)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            if pageIndex == 20 {
                // paging should stop at page 7 -> return nil
                onSuccess(nil)
                return
            }

            if pageIndex % 5 == 0 {
                onError(LoadingError.internalError(message: "error loading page \(pageIndex)"))
                return
            }

            var result = [ColorEmoji]()
            // randomize the size of the generated page - but don't return an empty list!
            for _ in 0 ..< Int.random(in: 1...30) {
                result.append(ColorEmoji.random())
            }

            onSuccess(Page(index: pageIndex, items: result))
        })
    }, onChanged: { [weak self] in
        self?.update()
    })
    
//    private lazy var cache = LazyItemList<ColorEmoji>(onLoadItem: { (index, onSuccess, onError) in
//        print("fetching item at index: \(index)")
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
//            if index == 20 {
//                onSuccess(nil)
//                return
//            }
//
//            if index % 7 == 0 {
//                onError(LoadingError.internalError(message: "Loading item \(index) failed..."))
//                return
//            }
//
//            onSuccess(ColorEmoji.random())
//        })
//    }, onChanged: { [weak self] in
//        self?.update()
//    })
    
    var callback: (([DefaultCellItem]?, [DefaultCellItem]?, [Int]) -> ())? = nil
    
    var currentPlaceholders: [Int] = [Int]()
    var currentItems: [DefaultCellItem] = [DefaultCellItem]()
    
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
