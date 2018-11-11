//
//  ViewController.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

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
    
    fileprivate lazy var cache = LazyList<UIColor>(onLoadItem: { (index, onSuccess, onError) in
        print("fetching item at index: \(index)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
            if index == 20 {
                onSuccess(nil)
                return
            }
            
            if index % 2 == 0 {
                onError(LoadingError.internalError(message: "Loading item \(index) failed..."))
                return
            }
            
            onSuccess(UIColor.random())
        })
    }, onChanged: { [weak self] in
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadData()
        }
    })
    
    private static let pageSize = 20
    fileprivate lazy var _cache = PagedLazyList<UIColor>(pageSize: ViewController.pageSize, onLoadPage: { (pageIndex, onSuccess, onError) in
        print("fetching page at index: \(pageIndex)")
        
        if pageIndex == 20 {
            onSuccess(nil)
            return
        }
        
        if pageIndex % 2 == 0 {
            onError(LoadingError.internalError(message: "error loading page \(pageIndex)"))
        }

        var result = [UIColor]()
        for i in 0 ..< ViewController.pageSize {
            result.append(UIColor.random())
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: {
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
        return cache.size()
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ViewController.reuseIdentifier,
                                                      for: indexPath) as! DefaultCell
        
        print("cellForItemAt: \(indexPath.row)")
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
            print("prefetch item at: \(indexPath.row)")
            cache.prefetch(index: indexPath.row)
        }
    }
}
