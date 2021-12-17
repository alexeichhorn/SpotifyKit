//
//  Clamped.swift
//  SpotifyKit
//
//  Created by Alexander Eichhorn on 17.12.21.
//

import Foundation

@propertyWrapper
struct Clamped<Value: Comparable> {
    
    var value: Value
    
    let min: Value?
    let max: Value?
    
    init(wrappedValue: Value, min: Value? = nil, max: Value? = nil) {
        self.value = wrappedValue
        self.min = min
        self.max = max
    }
    
    var wrappedValue: Value {
        set { value = newValue }
        get {
            var value = self.value
            if let min = min {
                value = Swift.max(value, min)
            }
            if let max = max {
                value = Swift.min(value, max)
            }
            return value
        }
    }
    
}
