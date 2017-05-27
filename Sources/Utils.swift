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

import Foundation
import Dispatch

// Invocation entity
public class Invocation<A, B, C> {
  
    public let commandArgs: A
    private(set) var timedOut: Bool = false
    private(set) var completed: Bool = false
    weak private var breaker: CircuitBreaker<A, B, C>?
    public init(breaker: CircuitBreaker<A, B, C>, commandArgs: A) {
        self.commandArgs = commandArgs
        self.breaker = breaker
    }

    public func setTimedOut() {
        self.timedOut = true
    }

    public func setCompleted() {
        self.completed = true
    }

    public func notifySuccess() {
        if !self.timedOut {
            self.setCompleted()
            breaker?.notifySuccess()
        }
    }

    public func notifyFailure() {
        if !self.timedOut {
            self.setCompleted()
            breaker?.notifyFailure()
        }
    }
}

public class Collection<T> {

  let semaphoreQueue = DispatchSemaphore(value: 1)
  private var list = [T]()

  var isEmpty: Bool {
    semaphoreQueue.wait()
    let empty = list.isEmpty
    semaphoreQueue.signal()
    return empty
  }

  var size: Int {
    semaphoreQueue.wait()
    let size = list.count
    semaphoreQueue.signal()
    return size
  }

  public func add(_ element: T) {
    semaphoreQueue.wait()
    list.append(element)
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

extension Date {
  public static func currentTimeMillis() -> UInt64 {
    let timeMillis = UInt64(NSDate().timeIntervalSince1970 * 1000.0)
    return timeMillis
  }
}
