//
//  PagedListItemCache.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

import Foundation

protocol ListItemCacheDelegate {
    func didUpdate()
}

class ListItemCache<Element> {
    
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
    typealias SuccessCallback = (Element?) -> ()
    typealias ErrorCallback = (Error) -> ()
    typealias CacheMissHandler = (Int, @escaping SuccessCallback, @escaping ErrorCallback) -> ()

    private var elements: [Int: ElementRequest] = [Int: ElementRequest]() {
        didSet {
            delegate?.didUpdate()
        }
    }
    
    private let cacheMissHandler: CacheMissHandler
    
    var delegate: ListItemCacheDelegate?
    
    init(cacheMissHandler: @escaping CacheMissHandler) {
        self.cacheMissHandler = cacheMissHandler
    }
    
    public subscript (index: Int) -> Element? {
        
        if elements.count == 0                                                      // initial call
            || (index + 1 == elements.keys.sorted().first && allowLoadBefore())     // load page before current first page
            || (index - 1 == elements.keys.sorted().last && allowLoadAfter()) {     // load page after current last page
            elements[index] = ElementRequest(isLoading: true, result: nil, error: nil)
            cacheMissHandler(
                index,
                { self.elements[index] = ElementRequest(isLoading: false, result: $0, error: nil) },
                { self.elements[index] = ElementRequest(isLoading: false, result: nil, error: $0)}
            )
            
            return elements[index]?.result
        }
        
        guard let element = elements[index] else {
            return nil
        }
        
        guard element.error == nil else {
            // TODO: implement proper error handling
            return nil
        }
        
        return element.result
    }
    
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
