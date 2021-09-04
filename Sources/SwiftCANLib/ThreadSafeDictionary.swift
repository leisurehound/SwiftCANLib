//  Copyright 2021 Google LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

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
