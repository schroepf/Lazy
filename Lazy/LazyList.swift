//
//  PagedListItemCache.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

import Foundation


class LazyList<Element> {
    
    struct ElementRequest {
        let isLoading: Bool
        let result: Element?
        let error: Error?
        
        func isAvailable() -> Bool {
            return isLoading || hasValue()
        }
        
        func hasValue() -> Bool {
            return result != nil || error != nil
        }
        
        func isEmpty() -> Bool {
            return !isLoading && result == nil && error == nil
        }
    }

    // pass 'nil' for items which don't exist (i.e. "out of bounds")
    typealias Index = Int
    typealias SuccessCallback = (Element?) -> ()
    typealias ErrorCallback = (Error) -> ()
    typealias LoadItemHandler = (Index, @escaping SuccessCallback, @escaping ErrorCallback) -> ()

    private var elements: [Index: ElementRequest] = [Index: ElementRequest]() {
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
    
    public subscript (index: Index) -> Element? {
        
        let sortedKeys = elements.keys.sorted()
        
        if elements.isEmpty                                                         // initial call
            || (index + 1 == sortedKeys.first && allowLoadBefore())     // allow access to page before current first page
            || (index - 1 == sortedKeys.last && allowLoadAfter()) {     // allow access to page after current last page
            elements[index] = ElementRequest(isLoading: true, result: nil, error: nil)
            onLoadItem(
                index,
                { self.elements[index] = ElementRequest(isLoading: false, result: $0, error: nil) },
                { self.elements[index] = ElementRequest(isLoading: false, result: nil, error: $0)}
            )
            
            return elements[index]?.result
        }
        
        // elements has been checked for emptyness -> forced unwrapping of first and last key should be fine now...
        assert(index >= sortedKeys.first! && index <= sortedKeys.last!, "Invalid index")
        
        guard let element = elements[index] else {
            print("WTF?") // this should never happen, we don't allow to grow the list beyond emtpy items...
            return nil
        }
        
        guard element.error == nil else {
            // TODO: implement proper error handling - how can this be displayed by the UI?
            return nil
        }
        
        return element.result
    }
    
    // TODO: refactor to `count` property
    public func size() -> Int {
        if elements.isEmpty {
            return 1
        }
        
        var result = elements.filter({ (index, request) -> Bool in
            !request.isEmpty()  // ignore "empty" requests (i.e. requests which returned no valid value)
        }).count
        
        if allowLoadBefore()  {
            // if the first element finished loading and has a value allow accessing
            result += 1
        }
        
        if allowLoadAfter() {
            // if the last element finished loading and has a value allow accessing
            result += 1
        }
        
        return result
    }
    
    public func items() -> [Element?] {
        guard !elements.isEmpty else {
            return [nil]
        }
        
        var result = elements.keys.sorted().map { elements[$0]?.result }
        
        if allowLoadBefore() {
            result.insert(nil, at: 0)
        }
        
        if allowLoadAfter() {
            result.append(nil)
        }
        
        return result
    }
    
    private func allowLoadBefore() -> Bool {
        guard let first = elements.keys.sorted().first, first > 0, let firstElement = elements[first] else {
            return false
        }
        
        return firstElement.hasValue()
    }
    
    private func allowLoadAfter() -> Bool {
        guard let last = elements.keys.sorted().last, let lastElement = elements[last] else {
            return false
        }
        
        return lastElement.hasValue()
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
    
    public subscript (index: Index) -> Element? {
        let page = index / pageSize
        let indexInPage = index % pageSize
        return super[page]?.items[indexInPage]
    }
    
    public override func size() -> Int {
        var count = 0
        items().forEach { (page) in
            guard let page = page else {
                count += 1
                return
            }
            
            count += page.items.count
        }
        
        return count
    }
}

