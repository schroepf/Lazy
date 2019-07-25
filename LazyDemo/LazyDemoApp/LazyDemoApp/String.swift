//
//  String.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

import Foundation

extension String {
    var hex: Int? {
        return Int(self, radix: 16)
    }
}
