//
//  PagedListItemCache.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//


// TODOs:
// - refactor size() to count property
// - add API to specify cache size for LazyList (and PagedLazyList)
// - fix Threading (make sure callbacks are executed on a background scheduler)
// - synchronize access to elementRequests
// - refactor LazyResult to LazyItem
// - is there a swiftier way to implement items() in PagedLazyList?
import Foundation

// TODO: (TS) this could become a "LazyItem" which has the capability to fetch items and LayzList could consist of LazyItems
struct LazyResult<Element> {
    let value: Element?
    let error: Error?
    
    func isEmpty() -> Bool {
        return value == nil && error == nil
    }
}

extension LazyResult: CustomDebugStringConvertible {
    var debugDescription: String {
        return "LazyResult(value: \(String(describing: value)), error: \(String(describing: error)))"
    }
}

class LazyList<Element> {
    
    struct ElementRequest {
        // while result is "nil" the request is considered as ongoing...
        let result: LazyResult<Element>?
        
        func hasResult() -> Bool {
            return result != nil
        }
        
        func isLoading() -> Bool {
            return result == nil
        }
    }
    
    typealias Index = Int
    
    // pass 'nil' as argument to this callback for items which don't exist (i.e. "out of bounds") - to signal that there is not item ...
    typealias SuccessCallback = (Element?) -> ()
    typealias ErrorCallback = (Error) -> ()
    typealias LoadItemHandler = (Index, @escaping SuccessCallback, @escaping ErrorCallback) -> ()

    private var elementRequests: [Index: ElementRequest] = [Index: ElementRequest]() {
        didSet {
            onChanged?()
        }
    }
    
    private let onLoadItem: LoadItemHandler
    private let onChanged: (() -> Void)?
    
    init(onLoadItem: @escaping LoadItemHandler, onChanged: (() -> Void)? = nil) {
        self.onLoadItem = onLoadItem
        self.onChanged = onChanged
    }
    
    public func prefetch(index: Index) {
        prefetch(item: index)
    }
    
    fileprivate func prefetch(item index: Index) {
        let sortedKeys = elementRequests.keys.sorted()
        
        if let first = sortedKeys.first, let last = sortedKeys.last {
            // elements has been checked for emptyness -> forced unwrapping of first and last key should be fine now...
            assert(index >= max(0, first - 1) && index <= last + 1, "Invalid index: \(index). Expected index range: [\(first)..\(last)]")
        }
        
        if sortedKeys.isEmpty                                            // initial call
            || (index == sortedKeys.first! - 1 && allowLoadBefore())     // allow access to page before current first page
            || (index == sortedKeys.last! + 1 && allowLoadAfter()) {     // allow access to page after current last page
            
            elementRequests[index] = ElementRequest(result: nil)
            onLoadItem(
                index,
                {
                    if $0 == nil {
                        // if the closure was called with a 'nil'  result make sure to clean up pending neighbour requests
                        if let previousRequest = self.elementRequests[index - 1], previousRequest.result == nil {
                            self.elementRequests.removeValue(forKey: index - 1)
                        }
                        
                        if let nextRequest = self.elementRequests[index + 1], nextRequest.result == nil {
                            self.elementRequests.removeValue(forKey: index + 1)
                        }
                    }
                    
                    self.elementRequests[index] = ElementRequest(result: LazyResult(value: $0, error: nil))
            },
                { self.elementRequests[index] = ElementRequest(result: LazyResult(value: nil, error: $0)) }
            )
        }
    }
    
    public subscript (index: Index) -> LazyResult<Element>? {
        prefetch(item: index)
        
        assert(elementRequests.keys.contains(index), "Request out of bounds")
        return elementRequests[index]!.result
    }
    
    public func items() -> [LazyResult<Element>?] {
        guard !elementRequests.isEmpty else {
            return [nil]
        }
        
        var result = elementRequests.keys.sorted()
            .map { elementRequests[$0]?.result }
            .filter { (result) -> Bool in
                guard let result = result else {
                    // if result is "nil" it's a placeholder item... -> keep it...
                    return true
                }
                
                // if the result is empty it's an item for which no data could be loaded (out of bounds item) -> don't keep it...
                return !result.isEmpty()
        }
        
        if allowLoadBefore() {
            result.insert(nil, at: 0)
        }
        
        if allowLoadAfter() {
            result.append(nil)
        }
        
        return result
    }
    
    private func allowLoadBefore() -> Bool {
        guard let first = elementRequests.keys.sorted().first, first > 0, let firstRequest = elementRequests[first] else {
            return false
        }
        
        if let result = firstRequest.result, result.isEmpty() {
            // loading of first item has finished but the result was "nil" => there is no more page before the current first page:
            return false
        }
        
        return !firstRequest.isLoading()
    }
    
    private func allowLoadAfter() -> Bool {
        guard let last = elementRequests.keys.sorted().last, let lastRequest = elementRequests[last] else {
            return false
        }
        
        if let result = lastRequest.result, result.isEmpty() {
            // loading of first item has finished but the result was "nil" => there is no more page before the current first page:
            return false
        }
        
        return !lastRequest.isLoading()
    }
}


typealias PageIndex = Int

struct Page<T> {
    let index: PageIndex
    let items: [T]
}

class PagedLazyList<Element>: LazyList<Page<Element>> {
    let pageSize: Int
    
    init(pageSize: Int, onLoadPage: @escaping LoadItemHandler, onChanged: (() -> Void)?) {
        self.pageSize = pageSize
        
        super.init(onLoadItem: onLoadPage, onChanged: onChanged)
    }
    
    public subscript (index: Index) -> LazyResult<Element>? {
        let translatedIndex = translate(index: index)
        
        guard let pageResult = super[translatedIndex.page] else {
            return nil
        }
        
        guard let page = pageResult.value else {
            return LazyResult(value: nil, error: super[translatedIndex.page]?.error)
        }
        
        return LazyResult(value: page.items[translatedIndex.item], error: nil)
    }
    
    func flattenedItems() -> [LazyResult<Element>?] {
        var items = [LazyResult<Element>?]()
        
        // TODO: (TS) maybe there is a swiftier way to do this...
        super.items().forEach { (result) in
            guard let result = result else {
                items.append(nil)
                return
            }
            
            guard let values = result.value?.items else {
                items.append(LazyResult(value: nil, error: result.error))
                return
            }
            
            items += values.map { (element) -> LazyResult<Element>? in
                return LazyResult(value: element, error: nil)
            }
        }
        
        return items
    }
    
    override func prefetch(index: LazyList<Element>.Index) {
        super.prefetch(item: translate(index: index).page)
    }
    
    private func translate(index: Index) -> (page: Int, item: Int) {
        let pages = super.items()
        
        var remaining = index
        var pageIndex = 0
        var indexInPage = 0
        
        while remaining > 0, pageIndex < pages.count {
            guard let result = pages[pageIndex], let page = result.value else {
                remaining -= 1
                pageIndex += 1
                continue
            }
            
            let items = page.items.count
            if remaining < items {
                indexInPage = remaining
            } else {
                pageIndex += 1
            }
            
            remaining -= items
        }
        
        return (page: pageIndex, item: indexInPage)
    }
}
