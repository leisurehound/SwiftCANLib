//
//  ThreadSafeDictionary.swift
//  
//
//  Created by Timothy Wise on 8/24/21.
//

import Foundation

// http://basememara.com/creating-thread-safe-arrays-in-swift/
internal class ThreadSafeDictionary<Key: Hashable, Value> {
  //implementing only the aspects required for this problem, not a generalized threadsafe dictionary
  private var dictionary: [Key:Value]
  private var queue: DispatchQueue = DispatchQueue(label: "com.leisurehoundsports.swiftcanlib.threadsafedictionary", attributes: .concurrent)
  
  public init() {
    dictionary = [:]
  }
  
  public subscript(key: Key) -> Value? {
    get {
      queue.sync {
        return dictionary[key]
      }
    }
    set {
      queue.async(flags: .barrier) {
        self.dictionary[key] = newValue
      }
    }
  }
  
}
