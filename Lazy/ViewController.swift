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
    
    @IBOutlet weak var collectionView: UICollectionView!
    private lazy var refreshControl = UIRefreshControl()
    
    private var viewModel = ViewModel()
    private var dataSource = DefaultDataSource(items: [])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self.dataSource
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
        viewModel.callback = { [weak self] oldItems, newItems in
            guard let self = self, let newItems = newItems else { return }

            guard let changes = self.dataSource.diff(against: newItems) else {
                self.collectionView.reloadData()
                return
            }

            log.debug("updating dataSource")
            self.dataSource.items = newItems

            log.debug("will reload with changes: \(changes)")
            self.collectionView.reload(changes: changes, section: 0, completion: { _ in
                log.debug("did reload with changes: \(changes)")
            })
        }

//        refresh()
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
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        log.debug("UICollectionViewDataSource - willDisplay: \(indexPath)")
        viewModel.prefetch(index: indexPath.row)
    }
}

extension ViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        log.debug("UICollectionViewDataSource - prefetchItemsAt: \(indexPaths)")
        indexPaths.forEach { (indexPath) in
            // assume we only have one sction:
            viewModel.prefetch(index: indexPath.row)
        }
    }
}

class DataSource<ItemType>: NSObject, UICollectionViewDataSource {
    let reuseIdentifier: String
    var items: [ItemType]
    let cellBinder: (ItemType, UICollectionViewCell) -> ()

    init(reuseIdentifier: String,
         items: [ItemType],
         cellBinder: @escaping (ItemType, UICollectionViewCell) -> ()) {
        self.reuseIdentifier = reuseIdentifier
        self.items = items
        self.cellBinder = cellBinder
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        log.debug("DataSource - count: \(items.count)")
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        log.debug("DataSource - cellForItemAt: \(indexPath)")
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
