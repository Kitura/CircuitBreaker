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

internal class Bulkhead {
  private let serialQueue: DispatchQueue
  private let concurrentQueue: DispatchQueue
  private let semaphore: DispatchSemaphore

  init(limit: Int) {
    serialQueue = DispatchQueue(label: "bulkheadSerialQueue")
    concurrentQueue = DispatchQueue(label: "bulkheadConcurrentQueue", attributes: .concurrent)
    semaphore = DispatchSemaphore(value: limit)
  }

  func enqueue(task: @escaping () -> Void ) {
    serialQueue.async { [weak self] in
      self?.semaphore.wait()
      self?.concurrentQueue.async {
        task()
        self?.semaphore.signal()
      }
    }
  }
}
