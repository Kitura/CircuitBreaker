/**
* Copyright IBM Corporation 2017
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
**/

import Dispatch
import Foundation

public class Collection<T> {

  internal let semaphoreQueue = DispatchSemaphore(value: 1)
  internal var list: [T]
  private let size: Int

  public var isEmpty: Bool {
    semaphoreQueue.wait()
    let empty = list.isEmpty
    semaphoreQueue.signal()
    return empty
  }

  public var count: Int {
    semaphoreQueue.wait()
    let count = list.count
    semaphoreQueue.signal()
    return count
  }

  public init(size: Int) {
    self.size = size
    self.list = [T]()
  }

  public func add(_ element: T) {
    semaphoreQueue.wait()
    list.append(element)
    if list.count > size {
      let _ = list.removeFirst()
    }
    semaphoreQueue.signal()
  }

  public func removeFirst() -> T? {
    semaphoreQueue.wait()
    let element: T? = list.removeFirst()
    semaphoreQueue.signal()
    return element
  }

  public func removeLast() -> T? {
    semaphoreQueue.wait()
    let element: T? = list.removeLast()
    semaphoreQueue.signal()
    return element
  }

  public func peekFirst() -> T? {
    semaphoreQueue.wait()
    let element: T? = list.first
    semaphoreQueue.signal()
    return element
  }

  public func peekLast() -> T? {
    semaphoreQueue.wait()
    let element: T? = list.last
    semaphoreQueue.signal()
    return element
  }

  public func clear() {
    semaphoreQueue.wait()
    list.removeAll()
    semaphoreQueue.signal()
  }
}

public class FailureQueue: Collection<UInt64> {

  public var currentTimeWindow: UInt64? {
    semaphoreQueue.wait()
    // Get time difference
    let timeWindow: UInt64?
    if let firstFailureTs = list.first, let lastFailureTs = list.last {
      timeWindow = lastFailureTs - firstFailureTs
    } else {
      timeWindow = nil
    }
    semaphoreQueue.signal()
    return timeWindow
  }
}

extension Date {
  public static func currentTimeMillis() -> UInt64 {
    let timeInMillis = UInt64(NSDate().timeIntervalSince1970 * 1000.0)
    return timeInMillis
  }
}
