//
//  ViewController.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    fileprivate static let reuseIdentifier = "DefaultCell"
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    fileprivate let data: [UIColor?]
    
    required init?(coder aDecoder: NSCoder) {
        data = [
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            UIColor.random(),
            nil,
            nil,
            nil,
            nil,
            nil,
            nil,
            nil,
            nil
        ]
        super.init(coder: aDecoder)
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
        return data.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ViewController.reuseIdentifier,
                                                      for: indexPath) as! DefaultCell
        
        cell.bind(to: data[indexPath.row])
        
        return cell
    }
}

extension ViewController: UICollectionViewDelegate {
    
}
