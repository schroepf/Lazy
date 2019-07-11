//
//  PagedListItemCache.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

// TODOs:
// - allow cancellation of requests
// - refactor size() to count property
// - add API to specify cache size for LazyList (and PagedLazyList)
import Foundation

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

typealias Index = Int

// pass 'nil' as argument to this callback for items which don't exist (i.e. "out of bounds") - to signal that there is no item ...
typealias SuccessCallback<Result> = (Result?) -> Void
typealias ErrorCallback = (Error) -> Void
typealias LoadItemHandler<Result> = (Index, @escaping SuccessCallback<Result>, @escaping ErrorCallback) -> Void

private struct LazyRequest<Element> {
    // while result is "nil" the request is considered as ongoing...
    let result: LazyResult<Element>?

    func hasResult() -> Bool {
        return result != nil
    }

    func isLoading() -> Bool {
        return result == nil
    }

    static func from(item: Element?) -> LazyRequest? {
        return item == nil ? nil : LazyRequest(result: LazyResult(value: item, error: nil))
    }

    static func wrap(value: Element? = nil, error: Error? = nil) -> LazyRequest {
        return LazyRequest(result: LazyResult(value: value, error: error))
    }
}

class LazyList<Element> {
    // A helper class to manage and synchronize access to the requests array...
    private class RequestsAccess<Element> {
        private let accessQueue = DispatchQueue(label: "LazyList.RequestsAccess")
        private let onChanged: (() -> Void)

        init(onChanged: @escaping (() -> Void)) {
            self.onChanged = onChanged
        }

        private var requests: [LazyRequest<Element>?] = [nil] {
            didSet {
                onChanged()
            }
        }

        fileprivate subscript(index: Index) -> LazyRequest<Element>? {
            get {
                return accessQueue.sync { requests[index] }
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

    private lazy var requests = RequestsAccess<Element>(onChanged: {
        guard let onChanged = self.onChanged else {
            return
        }

        self.callbackQueue.async {
            onChanged()
        }
    })

    // TODO: Add documentation!
    init(onLoadBefore: @escaping LoadItemHandler<[Element]>,
         onLoadItem: @escaping LoadItemHandler<Element>,
         onLoadAfter: @escaping LoadItemHandler<[Element]>,
         onChanged: (() -> Void)? = nil) {
        self.onLoadBefore = onLoadBefore
        self.onLoadItem = onLoadItem
        self.onLoadAfter = onLoadAfter
        self.onChanged = onChanged
    }

    // TODO: Add documentation
    subscript(index: Index) -> LazyResult<Element>? {
        prefetch(index: index)
        return requests[index]?.result
    }

    // TODO: Add documentation
    func prefetch(index: Index) {
        guard requests[index] == nil else {
            // a request is already started...
            return
        }

        requests.update { (requests) -> ([LazyRequest<Element>?]) in
            var result = requests
            result[index] = LazyRequest(result: nil) // FIXME: This triggers an unnecessary onChanged() call

            if index == 0, requests.count > 1 {
                triggerLoadBefore(index: index + 1)
            } else if index == requests.count - 1 {
                triggerLoadAfter(index: index - 1)
            } else {
                triggerLoadItem(index: index)
            }

            return result
        }
    }

    // TODO: Add documentation
    // nil values in the result array are considered as "loading" items...
    func items() -> [LazyResult<Element>?] {
        let requests = self.requests.readAll()

        guard requests.count > 0 else {
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

        // if the last item is not an error or not empty (i.e. if it has a value add a placeholder to the bottom:
        if let _ = requests.last??.result?.value {
            results.append(nil)
        }

        return results
    }

    func update(_ item: Element?, at index: Index) {
        requests.update { (requests) -> ([LazyRequest<Element>?]) in
            var result = requests
            result[index] = LazyRequest.from(item: item)
            return result
        }
    }

    func insert(_ item: Element?, at index: Index) {
        requests.update { (requests) -> ([LazyRequest<Element>?]) in
            var result = requests
            result.insert(LazyRequest.from(item: item), at: index)
            return result
        }
    }

    func insert(contentsOf items: [Element?], at index: Index) {
        let requestsToAdd = items.map { LazyRequest.from(item: $0) }

        requests.update { (requests) -> ([LazyRequest<Element>?]) in
            var result = requests
            result.insert(contentsOf: requestsToAdd, at: index)
            return result
        }
    }

    func append(_ item: Element?) {
        insert(item, at: requests.readAll().count)
    }

    func append(contentsOf items: [Element?]) {
        insert(contentsOf: items, at: requests.readAll().count)
    }

    func remove(at index: Index) {
        requests.update { (requests) -> ([LazyRequest<Element>?]) in
            var result = requests
            result.remove(at: index)
            return result
        }
    }

    func clear() {
        requests.update { (_) -> ([LazyRequest<Element>?]) in
            [nil]
        }
    }

    private func triggerLoadBefore(index: Index) {
        callbackQueue.async { [weak self] in
            guard let self = self else {
                return
            }

            self.onLoadBefore(
                index,
                { [weak self] result in
                    guard let self = self else {
                        return
                    }

                    self.requests.updateAsync({ (requests) -> ([LazyRequest<Element>?]) in
                        var updatedRequests = requests
                        updatedRequests.remove(at: 0)

                        if let result = result, !result.isEmpty {
                            updatedRequests.insert(contentsOf: result.map { LazyRequest.wrap(value: $0) }, at: 0)
                            updatedRequests.insert(nil, at: 0)
                        } else {
                            updatedRequests.append(LazyRequest.wrap(value: nil, error: nil))
                        }

                        return updatedRequests
                    })
                },
                { [weak self] error in
                    self?.requests[index - 1] = LazyRequest.wrap(error: error)
                }
            )
        }
    }

    private func triggerLoadAfter(index: Index) {
        callbackQueue.async { [weak self] in
            guard let self = self else {
                return
            }

            self.onLoadAfter(
                index,
                { [weak self] result in
                    guard let self = self else {
                        return
                    }

                    self.requests.updateAsync({ (requests) -> ([LazyRequest<Element>?]) in
                        var updatedRequests = requests
                        updatedRequests.remove(at: updatedRequests.count - 1)

                        if let result = result, !result.isEmpty {
                            updatedRequests.insert(contentsOf: result.map { LazyRequest.wrap(value: $0) }, at: updatedRequests.count)
                            updatedRequests.append(nil)
                        } else {
                            updatedRequests.append(LazyRequest.wrap(value: nil, error: nil))
                        }

                        return updatedRequests
                    })
                },
                { [weak self] error in
                    self?.requests[index + 1] = LazyRequest.wrap(error: error)
                }
            )
        }
    }

    private func triggerLoadItem(index: Index) {
        callbackQueue.async { [weak self] in
            guard let self = self else {
                return
            }

            self.onLoadItem(
                index,
                { [weak self] result in
                    self?.requests[index] = LazyRequest.wrap(value: result)
                },
                { [weak self] error in
                    self?.requests[index] = LazyRequest.wrap(error: error)
                }
            )
        }
    }
}
