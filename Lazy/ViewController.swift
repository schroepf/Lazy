//
//  ViewController.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    enum LoadingError: Error {
        case internalError(String)
    }
    
    fileprivate static let reuseIdentifier = "DefaultCell"
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    fileprivate let cache:ListItemCache<UIColor>
    
    required init?(coder aDecoder: NSCoder) {
        cache = ListItemCache<UIColor>(cacheMissHandler: { (index, onSuccess, onError)  in
            print("fetching item at index: \(index)")
            
            if index == 20 {
                onSuccess(nil)
                return
            }
            
            if index % 5 == 0 {
                onError(LoadingError.internalError("ERROR"))
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                onSuccess(UIColor.random())
            })
        })
        
        super.init(coder: aDecoder)
        
        cache.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        collectionView.dataSource = self
        collectionView.delegate = self
    }
}


extension ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cache.size()
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

extension ViewController: ListItemCacheDelegate {
    func didUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadData()
        }
    }
}
