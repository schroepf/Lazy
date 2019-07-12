//
//  ViewController.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

import DeepDiff
import Differ
import Smile
import UIKit

enum LoadingError: Error {
    case internalError(message: String)
}

extension LoadingError {
    var description: String {
        switch self {
        case let .internalError(message):
            return message
        }
    }
}

class ViewController: UIViewController {
    fileprivate static let reuseIdentifier = "DefaultCell"

    @IBOutlet var collectionView: UICollectionView!
    private lazy var refreshControl = UIRefreshControl()

    private var viewModel = ViewModel()
    private var dataSource = DefaultDataSource(items: [])

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = dataSource
        collectionView.delegate = self
        collectionView.prefetchDataSource = self

        let title = NSLocalizedString("PullToRefresh", comment: "Pull to refresh")
        refreshControl.attributedTitle = NSAttributedString(string: title)
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl

        viewModel = ViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.callback = { [weak self] _, newItems, placeholders in
            self?.refreshControl.endRefreshing()
            guard let self = self, let newItems = newItems else { return }

            guard let changes = self.dataSource.diff(against: newItems) else {
                self.collectionView.reloadData()
                return
            }

            log.debug("will reload with changes: \(changes)")
            self.collectionView.reload(changes: changes, section: 0, updateData: {
                log.debug("updating dataSource")
                self.dataSource.items = newItems
            }, completion: { _ in
                log.debug("did reload with changes: \(changes)")

                let placeholderPaths = placeholders.map { IndexPath(row: $0, section: 0) }
                self.collectionView.reloadItems(at: placeholderPaths)
            })
        }

        refresh()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        log.debug("ZEFIX")
        viewModel.callback = nil
    }

    @objc private func refresh() {
        log.debug("refreshing...")
        viewModel.reload()
    }
}

extension ViewController: UICollectionViewDelegate {
    func collectionView(_: UICollectionView, willDisplay _: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        viewModel.prefetch(index: indexPath.row)
    }
}

extension ViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        log.debug("UICollectionViewDataSource - prefetchItemsAt: \(indexPaths)")
        indexPaths.forEach { indexPath in
            // assume we only have one sction:
            viewModel.prefetch(index: indexPath.row)
        }
    }
}

class DataSource<ItemType>: NSObject, UICollectionViewDataSource {
    let reuseIdentifier: String
    var items: [ItemType]
    let cellBinder: (ItemType, UICollectionViewCell) -> Void

    init(reuseIdentifier: String,
         items: [ItemType],
         cellBinder: @escaping (ItemType, UICollectionViewCell) -> Void) {
        self.reuseIdentifier = reuseIdentifier
        self.items = items
        self.cellBinder = cellBinder
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)

        cellBinder(items[indexPath.row], cell)
        return cell
    }
}

class DefaultDataSource: DataSource<DefaultCellItem> {
    init(items: [DefaultCellItem]) {
        super.init(reuseIdentifier: ViewController.reuseIdentifier, items: items) { item, cell in
            if let cell = cell as? DefaultCell {
                cell.bind(to: item)
            }
        }
    }

    func diff(against newItems: [DefaultCellItem]) -> [Change<DefaultCellItem>]? {
        return DeepDiff.diff(old: items, new: newItems)
    }
}
