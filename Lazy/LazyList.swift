//
//  PagedListItemCache.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

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
        let sortedKeys = elementRequests.keys.sorted()
        
        if let first = sortedKeys.first, let last = sortedKeys.last {
            // elements has been checked for emptyness -> forced unwrapping of first and last key should be fine now...
            assert(index >= max(0, first - 1) && index <= last + 1, "Invalid index: \(index). Expected index range: [\(first)..\(last)]")
        }
        
        if sortedKeys.isEmpty                                             // initial call
            || (index == sortedKeys.first! - 1 && allowLoadBefore())     // allow access to page before current first page
            || (index == sortedKeys.last! + 1 && allowLoadAfter()) {     // allow access to page after current last page
            
            print("prefetching: \(index)")
            
            elementRequests[index] = ElementRequest(result: nil)
            onLoadItem(
                index,
                { self.elementRequests[index] = ElementRequest(result: LazyResult(value: $0, error: nil)) },
                { self.elementRequests[index] = ElementRequest(result: LazyResult(value: nil, error: $0)) }
            )
        }
    }
    
    public subscript (index: Index) -> LazyResult<Element>? {
        prefetch(index: index)
        
        assert(elementRequests.keys.contains(index), "Request out of bounds")
        return elementRequests[index]!.result
    }
    
    // TODO: refactor to `count` property
    public func size() -> Int {
        if elementRequests.isEmpty {
            // while there are no elements yet return a placeholder
            return 1
        }
        
        var numberOfItems = elementRequests.filter { (_, request) -> Bool in
            guard let result = request.result else {
                // requests with no result are considered pending and should display a placeholder...
                return true
            }
            
            // "empty" requests (i.e. requests which returned a "nil" value) are considered as "out of bounds" and do not count to the list's size
            return !result.isEmpty()
        }
            .count
        
        if allowLoadBefore()  {
            // if the first element finished loading and has a value allow accessing
            numberOfItems += 1
        }
        
        if allowLoadAfter() {
            // if the last element finished loading and has a value allow accessing
            numberOfItems += 1
        }
        
        return numberOfItems
    }
    
    public func items() -> [LazyResult<Element>?] {
        guard !elementRequests.isEmpty else {
            return [nil]
        }
        
        var result = elementRequests.keys.sorted().map { elementRequests[$0]?.result }
        
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
        
        return !firstRequest.isLoading()
    }
    
    private func allowLoadAfter() -> Bool {
        guard let last = elementRequests.keys.sorted().last, let lastRequest = elementRequests[last] else {
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
        let pageIndex = index / pageSize
        let indexInPage = index % pageSize
        
        guard let pageResult = super[pageIndex] else {
            return nil
        }
        
        guard let page = pageResult.value else {
            return LazyResult(value: nil, error: super[pageIndex]?.error)
        }
        
        return LazyResult(value: page.items[indexInPage], error: nil)
    }
    
    public override func size() -> Int {
        var count = 0
        items().forEach { (pageResult) in
            guard let pageResult = pageResult else {
                // if the item is nil it means that the page is not loaded yet and a placholder should be displayed -> add +1 for the placholder item
                count += 1
                return
            }
            
            guard let page = pageResult.value else {
                // if there is a pageResult but it contains no value it must contain an error -> add +1 for the error item
                count += 1
                return
            }
            
            count += page.items.count
        }
        
        return count
    }
}

