//
//  PagedListItemCache.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//
import Foundation

public struct LazyResult<Element> {
    public let value: Element?
    public let error: Error?

    func isEmpty() -> Bool {
        return value == nil && error == nil
    }

    static func empty() -> LazyResult<Element> {
        return LazyResult(value: nil, error: nil)
    }
}

extension LazyResult: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "LazyResult(value: \(String(describing: value)), error: \(String(describing: error)))"
    }
}

public typealias Index = Int

// pass 'nil' as argument to this callback for items which don't exist (i.e. "out of bounds") - to signal that there is no item ...
public typealias SuccessCallback<Result> = (Result?) -> Void
public typealias ErrorCallback = (Error) -> Void
public typealias LoadItemHandler<Result> = (Index, @escaping SuccessCallback<Result>, @escaping ErrorCallback) -> Void

private struct LazyRequest<Element> {
    // while result is "nil" the request is considered as ongoing...
    let result: LazyResult<Element>?

    func isLoading() -> Bool {
        return result == nil
    }

    static func from(error: Error) -> LazyRequest {
        return LazyRequest(result: LazyResult(value: nil, error: error))
    }

    static func from(item: Element) -> LazyRequest {
        return LazyRequest(result: LazyResult(value: item, error: nil))
    }

    static func emptyResult() -> LazyRequest {
        return LazyRequest(result: LazyResult.empty())
    }
}

/// DataStructure
/// The items of the LazyList are represented by LazyRequests, which in turn will hold a 'nil' value as long as the request is ongoing and an actual value of LazyResult once the
/// request has finished. The LazyResult in turn can hold a value (if the request returned an actual item), an error (if the request failed) or be empty (if the request retruned
/// no result - i.e. no item for the given index -> out of range)
///  - LazyList -> [ LazyRequest -> LazyResult? ]
public class LazyList<Element> {
    // A helper class to manage and synchronize access to the requests array...
    private class RequestsAccess<Element> {
        private let accessQueue = DispatchQueue(label: "LazyList.RequestsAccess")
        private let onChanged: (() -> Void)

        init(onChanged: @escaping (() -> Void)) {
            self.onChanged = onChanged
        }

        /// Represents the current state of the list, contains:
        /// - a LazyRequest representing the loading state of the item for the given index (which in turn can be "loading", "successful" or "errored")
        /// - nil if there is no item for the given index
        private var requests: [LazyRequest<Element>?] = [nil] {
            didSet {
                onChanged()
            }
        }

        fileprivate subscript(index: Index) -> LazyRequest<Element>? {
            get {
                return accessQueue.sync {
                    requests[index]
                }
            }

            set {
                accessQueue.async {
                    self.requests[index] = newValue
                }
            }
        }

        fileprivate func readAll() -> [LazyRequest<Element>?] {
            return accessQueue.sync { requests }
        }

        fileprivate func update(_ block: ([LazyRequest<Element>?]) -> ([LazyRequest<Element>?])) {
            accessQueue.sync {
                requests = block(requests)
            }
        }

        fileprivate func updateAsync(_ block: @escaping ([LazyRequest<Element>?]) -> ([LazyRequest<Element>?])) {
            accessQueue.async {
                self.requests = block(self.requests)
            }
        }

        fileprivate func sync(_ block: () -> Void) {
            accessQueue.sync {
                block()
            }
        }

        fileprivate func async(_ block: @escaping () -> Void) {
            accessQueue.async {
                block()
            }
        }
    }

    private let callbackQueue = DispatchQueue(label: "LazyList.Callbacks")

    private let onLoadBefore: LoadItemHandler<[Element]>
    private let onLoadItem: LoadItemHandler<Element>
    private let onLoadAfter: LoadItemHandler<[Element]>
    private let onChanged: (() -> Void)?

    private lazy var requestsAccess = RequestsAccess<Element>(onChanged: {
        guard let onChanged = self.onChanged else {
            return
        }

        self.callbackQueue.async {
            onChanged()
        }
    })

    /// Initialize the lazy list with its callbacks.
    ///
    /// - Parameters:
    ///   - onLoadBefore: will be called when items smaller then a given index have to be loaded
    ///   - onLoadItem: will be called when a item with a specific index needs to be loaded
    ///   - onLoadAfter: will be called when items bigger then a given index have to be loaded
    ///   - onChanged: will be called when the list content has changed
    public init(onLoadBefore: @escaping LoadItemHandler<[Element]>,
                onLoadItem: @escaping LoadItemHandler<Element>,
                onLoadAfter: @escaping LoadItemHandler<[Element]>,
                onChanged: (() -> Void)? = nil) {
        self.onLoadBefore = onLoadBefore
        self.onLoadItem = onLoadItem
        self.onLoadAfter = onLoadAfter
        self.onChanged = onChanged
    }

    // TODO: Add documentation
    public subscript(index: Index) -> LazyResult<Element>? {
        prefetch(index: index)
        return requestsAccess[index]?.result
    }

    // TODO: Add documentation
    public func prefetch(index: Index) {
        // FIXME: shouldn't we instead test if the last index is empty (instead of checking for nil?)
        // - or probably both: is the request for the index nil (a request can be created and started) or empty (there is no item for the requested and all following indexes)?
        guard requestsAccess[index] == nil else {
            // a request is already started...
            return
        }

        requestsAccess.update { requests -> [LazyRequest<Element>?] in
            var updatedRequests = requests
            updatedRequests[index] = LazyRequest(result: nil)

            if index == 0, requests.count > 1 {
                triggerLoadBefore(index: index + 1)
            } else if index == requests.count - 1 {
                triggerLoadAfter(index: index - 1)
            } else {
                triggerLoadItem(index: index)
            }

            return updatedRequests
        }
    }

    // TODO: Add documentation
    // nil values in the result array are considered as "loading" items...
    public var items: [LazyResult<Element>?] {
        let requests = self.requestsAccess.readAll()

        guard !requests.isEmpty else {
            // if there are no requests yet just emit a placeholder...
            return [nil]
        }

        var results = requests
            .filter { request in
                guard let result = request?.result else {
                    return true
                }

                return !result.isEmpty()
            }
            .map { $0?.result }

        // if the last item is not an error or not empty (i.e. if it has a value) add a "loading" placeholder to the bottom:
        if requests.last??.result?.value != nil {
            results.append(nil)
        }

        return results
    }

    public func update(_ item: Element, at index: Index) {
        requestsAccess.update { (requests) -> ([LazyRequest<Element>?]) in
            var result = requests
            result[index] = LazyRequest.from(item: item)
            return result
        }
    }

    public func insert(_ item: Element, at index: Index) {
        requestsAccess.update { (requests) -> ([LazyRequest<Element>?]) in
            var result = requests
            result.insert(LazyRequest.from(item: item), at: index)
            return result
        }
    }

    public func insert(contentsOf items: [Element], at index: Index) {
        let requestsToAdd = items.map { LazyRequest.from(item: $0) }

        requestsAccess.update { (requests) -> ([LazyRequest<Element>?]) in
            var result = requests
            result.insert(contentsOf: requestsToAdd, at: index)
            return result
        }
    }

    public func append(_ item: Element) {
        insert(item, at: requestsAccess.readAll().count)
    }

    public func append(contentsOf items: [Element]) {
        insert(contentsOf: items, at: requestsAccess.readAll().count)
    }

    public func remove(at index: Index) {
        requestsAccess.update { (requests) -> ([LazyRequest<Element>?]) in
            var result = requests
            result.remove(at: index)
            return result
        }
    }

    public func clear() {
        requestsAccess.update { (_) -> ([LazyRequest<Element>?]) in
            [nil]
        }
    }

    private func isComplete() -> Bool {
        guard let result = requestsAccess.readAll().last??.result else { return false }
        return result.isEmpty()
    }

    private func triggerLoadBefore(index: Index) {
        callbackQueue.async { [weak self] in
            guard let self = self else { return }

            self.onLoadBefore(index, { [weak self] result in
                guard let self = self else { return }

                self.requestsAccess.updateAsync { (requests) -> ([LazyRequest<Element>?]) in
                    var updatedRequests = requests
                    updatedRequests.remove(at: 0)

                    guard let result = result, !result.isEmpty else {
                        // if Callback was called with a 'nil' result or an empty list we assume the list has been fully loaded
                        // add an emptyResult() as a marker that there are no more items from this index on
                        updatedRequests.insert(LazyRequest.emptyResult(), at: 0)
                        return updatedRequests
                    }

                    // when actual results were loaded insert them at the beginning (because we triggered a "load before" call)...
                    updatedRequests.insert(contentsOf: result.map { LazyRequest.from(item: $0) }, at: 0)
                    // ... and add a 'nil' value as a marker that there could potentially be even more items
                    updatedRequests.insert(nil, at: 0)

                    return updatedRequests
                }
            }, { [weak self] error in
                self?.requestsAccess[index - 1] = LazyRequest.from(error: error)
            })
        }
    }

    private func triggerLoadAfter(index: Index) {
        callbackQueue.async { [weak self] in
            guard let self = self else {
                return
            }

            self.onLoadAfter(index, { [weak self] result in
                guard let self = self else {
                    return
                }

                self.requestsAccess.updateAsync({ requests -> [LazyRequest<Element>?] in
                    var updatedRequests = requests
                    updatedRequests.remove(at: updatedRequests.count - 1)

                    guard let result = result, !result.isEmpty else {
                        // if Callback was called with a 'nil' result or an empty list we assume the list has been fully loaded
                        // add an emptyResult() as a marker that there are no more items from this index on
                        updatedRequests.append(LazyRequest.emptyResult())
                        return updatedRequests
                    }

                    // when actual results were loaded append them to the end (because we triggered a "load after" call)...
                    updatedRequests.insert(contentsOf: result.map { LazyRequest.from(item: $0) }, at: updatedRequests.count)
                    // ... and append a 'nil' value after them as a marker that there could potentially be even more items
                    updatedRequests.append(nil)

                    return updatedRequests
                })
            }, { [weak self] error in
                self?.requestsAccess[index + 1] = LazyRequest.from(error: error)
            })
        }
    }

    private func triggerLoadItem(index: Index) {
        callbackQueue.async { [weak self] in
            guard let self = self else {
                return
            }

            self.onLoadItem(index, { [weak self] result in
                guard let result = result else {
                    // if the result is 'nil' then there are no actual items for the requested index... -> represented by "emptyResult()"
                    self?.requestsAccess[index] = LazyRequest.emptyResult()
                    return
                }

                self?.requestsAccess[index] = LazyRequest.from(item: result)
            }, { [weak self] error in
                self?.requestsAccess[index] = LazyRequest.from(error: error)
            })
        }
    }
}
