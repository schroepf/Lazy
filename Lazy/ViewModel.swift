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
        static let simulatedDatasetSize = 50
        static let simulatedDelay = 0.002
    }

    let backend = Backend(simulatedDatasetSize: Constants.simulatedDatasetSize, simulatedDelay: Constants.simulatedDelay)

    private let currentItemsAccess = DispatchQueue(label: "CurrentItemsAccessQueue")

    var callback: (([DefaultCellItem]?, [DefaultCellItem]?, [Int]) -> Void)?

    var currentItems = [LazyResult<ColorEmoji>?]()
    private lazy var cache = LazyList<ColorEmoji>(
        onLoadBefore: { index, onSuccess, onError in
            log.debug("fetching items BEFORE index: \(index)")

            // randomize the size of the generated page - but don't return an empty list!
            let pageSize: Int = Int.random(in: 0 ... Constants.maxPageSize)
            self.backend.loadEmojis(skip: index - 1 - pageSize, top: pageSize, callback: { result, error in
                if let error = error {
                    onError(error)
                    return
                }

                onSuccess(result)
            })
        },
        onLoadItem: { index, onSuccess, onError in
            log.debug("fetching item AT index: \(index)")

            self.backend.loadEmojis(skip: index, top: 1, callback: { result, error in
                if let error = error {
                    log.error("loading item AT index: \(index) failed with error: \(error)")
                    onError(error)
                    return
                }

                log.debug("loading item AT index: \(index) finished successfully")
                onSuccess(result?.first)
            })
        },
        onLoadAfter: { index, onSuccess, onError in
            log.debug("fetching items AFTER index: \(index)")
            let pageSize = Int.random(in: 1 ... Constants.maxPageSize)
            self.backend.loadEmojis(skip: index + 1, top: pageSize, callback: { result, error in
                if let error = error {
                    log.error("loading item AFTER index: \(index) failed with error: \(error)")
                    onError(error)
                    return
                }

                log.debug("loading item AT index: \(index) finished successfully (pageSize: \(result?.count ?? 0), requestedSize: \(pageSize)")
                onSuccess(result)
            })
        },
        onChanged: { [weak self] in
            log.debug("ZEFIX - calling update()")
            self?.update()
        }
    )

    init() {}

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
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                let previousItems = self.currentItems
                self.currentItems = self.cache.items()
                self.callback?(previousItems.map { DefaultCellItem.from(result: $0) },
                               self.currentItems.map { DefaultCellItem.from(result: $0) },
                               self.currentItems.enumerated()
                                   .filter { $0.element == nil }
                                   .map { $0.offset })
            }
        }
    }
}
