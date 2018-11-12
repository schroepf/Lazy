//
//  ViewController.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

import UIKit
import Smile

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
    
    fileprivate lazy var _cache = LazyList<DefaultCellItem>(onLoadItem: { (index, onSuccess, onError) in
        print("fetching item at index: \(index)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            if index == 20 {
                onSuccess(nil)
                return
            }
            
            if index % 7 == 0 {
                onError(LoadingError.internalError(message: "Loading item \(index) failed..."))
                return
            }
            
            onSuccess(DefaultCellItem(color: UIColor.random(), emoji: emojiList.randomElement() ?? (key: "", value: "")))
        })
    }, onChanged: { [weak self] in
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadData()
        }
    })
    
    private static let pageSize = 3
    fileprivate lazy var cache = PagedLazyList<DefaultCellItem>(pageSize: ViewController.pageSize, onLoadPage: { (pageIndex, onSuccess, onError) in
        print("fetching page at index: \(pageIndex)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            if pageIndex == 6 {
                let result = [
                    DefaultCellItem(color: UIColor.random(), emoji: emojiList.randomElement() ?? (key: "", value: "")),
                    DefaultCellItem(color: UIColor.random(), emoji: emojiList.randomElement() ?? (key: "", value: ""))
                ]

                onSuccess(Page(index: pageIndex, items: result))
                return
            }

            if pageIndex == 20 {
                // paging should stop at page 7 -> return nil
                onSuccess(nil)
                return
            }
            
            if pageIndex % 5 == 0 {
                onError(LoadingError.internalError(message: "error loading page \(pageIndex)"))
                return
            }
            
            var result = [DefaultCellItem]()
            for i in 0 ..< ViewController.pageSize {
                result.append(DefaultCellItem(color: UIColor.random(), emoji: emojiList.randomElement() ?? (key: "", value: "")))
            }
            
            onSuccess(Page(index: pageIndex, items: result))
        })
    }, onChanged: { [weak self] in
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadData()
        }
    })
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
    }
}


extension ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cache.flattenedItems().count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ViewController.reuseIdentifier,
                                                      for: indexPath) as! DefaultCell
        cell.bind(to: cache[indexPath.row])
        
        return cell
    }
}

extension ViewController: UICollectionViewDelegate {
    
}

extension ViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        indexPaths.forEach { (indexPath) in
            // assume we only have one sction:
            cache.prefetch(index: indexPath.row)
        }
    }
}
