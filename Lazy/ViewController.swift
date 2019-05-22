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
    
    private var viewModel = ViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        viewModel = ViewModel()
        collectionView.reloadData()
        viewModel.callback = { [weak self] (oldItems, newItems, placeholders, changes) in

            let placeholderPaths = placeholders.map { IndexPath(row: $0, section: 0) }
            
            // Use Differ
//            if let oldItems = oldItems, let newItems = newItems {
//                self?.collectionView.animateItemChanges(oldData: oldItems, newData: newItems, completion: { (_) in
//                    self?.collectionView.reloadItems(at: placeholderPaths)
//                })
//            } else {
//                self?.collectionView.reloadData()
//            }
            
            // Use DeepDiff
            if let changes = changes {
                log.debug("will reload with changes: \(changes)")

                self?.collectionView.reload(changes: changes, section: 0, completion: { (result) in
                    // re-trigger loading of visible placeholders to make sure data is actually fetched
                    
                    log.debug("did reload with changes: \(changes)")
                    self?.collectionView.reloadItems(at: placeholderPaths)
                })
            } else {
                self?.collectionView.reloadData()
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        viewModel.callback = nil
    }
}


extension ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.count()
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ViewController.reuseIdentifier,
                                                      for: indexPath) as! DefaultCell
        
        cell.bind(to: viewModel.item(at: indexPath.row))
        return cell
    }
}

extension ViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        viewModel.prefetch(index: indexPath.row)
    }
}

extension ViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        indexPaths.forEach { (indexPath) in
            // assume we only have one sction:
            viewModel.prefetch(index: indexPath.row)
        }
    }
}
