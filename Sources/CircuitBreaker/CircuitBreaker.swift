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
import LoggerAPI

/// CircuitBreaker class
///
/// - A: Parameter types used in the arguments for the command closure.
/// - C: Parameter type used as the second argument for the fallback closure.
public class CircuitBreaker<A, B> {

  // MARK: Closure Aliases

  public typealias AnyFunction<A> = (A) -> ()
  public typealias AnyContextFunction<A> = (Invocation<A, B>) -> ()
  public typealias AnyFallback<C> = (BreakerError, B) -> Void
  
  // MARK: Public Fields

  /// Execution timeout for command contect (Default: 1000 ms)
  public let timeout: Int
  
  /// Timeout to reset circuit (Default: 6000 ms)
  public let resetTimeout: Int
  
  /// Maximum number of failures allowed before opening circuit (Default: 5)
  public let maxFailures: Int
  
  /// (Default: 10000 ms)
  public let rollingWindow: Int
  
  /// Instance of Circuit Breaker Stats
  public let breakerStats = Stats()

  /// The Breaker's Current State
  public private(set) var breakerState: State {
    get {
      return state
    }
    set {
      state = newValue
    }
  }

  private(set) var state = State.closed
  private let failures: FailureQueue
  private let command: AnyFunction<A>?
  private let fallback: AnyFallback<B>
  private let contextCommand: AnyContextFunction<A>?
  private let bulkhead: Bulkhead?

  /// Dispatch
  private var resetTimer: DispatchSourceTimer?
  private let semaphoreCompleted = DispatchSemaphore(value: 1)
  private let semaphoreCircuit = DispatchSemaphore(value: 1)

  private let queue = DispatchQueue(label: "Circuit Breaker Queue", attributes: .concurrent)

  // MARK: Initializers

  private init(timeout: Int, resetTimeout: Int, maxFailures: Int, rollingWindow: Int, bulkhead: Int, command: (AnyFunction<A>)?, contextCommand: (AnyContextFunction<A>)?, fallback: @escaping AnyFallback<B>) {
    self.timeout = timeout
    self.resetTimeout = resetTimeout
    self.maxFailures = maxFailures
    self.rollingWindow = rollingWindow
    self.fallback = fallback
    self.command = command
    self.contextCommand = contextCommand
    self.failures = FailureQueue(size: maxFailures)
    self.bulkhead = (bulkhead > 0) ? Bulkhead.init(limit: bulkhead) : nil
  }

  /// Initializes CircuitBreaker instance with syncronous context command (Basic usage)
  ///
  /// - Parameters:
  ///   - timeout: Execution timeout for command contect (Default: 1000 ms)
  ///   - resetTimeout: Timeout to reset circuit (Default: 6000 ms)
  ///   - maxFailures: Maximum number of failures allowed before opening circuit (Default: 5)
  ///   - rollingWindow: (Default: 10000 ms)
  ///   - bulkhead: Number of the limit of concurrent requests running at one time. Default is set to 0, which is equivalent to not using the bulkheading feature. (Default: 0)
  ///   - command: Function to circuit break (basic usage constructor).
  ///   - fallback: Function user specifies to signal timeout or fastFail completion. Required format: (BreakerError, (fallbackArg1, fallbackArg2,...)) -> Void
  ///
  public convenience init(timeout: Int = 1000, resetTimeout: Int = 60000, maxFailures: Int = 5, rollingWindow: Int = 10000, bulkhead: Int = 0, command: @escaping AnyFunction<A>, fallback: @escaping AnyFallback<B>) {
    self.init(timeout: timeout, resetTimeout: resetTimeout, maxFailures: maxFailures, rollingWindow: rollingWindow, bulkhead: bulkhead, command: command, contextCommand: nil, fallback: fallback)
  }
  
  /// Initializes CircuitBreaker instance with syncronous context command (Advanced usage)
  ///
  /// - Parameters:
  ///   - timeout: Execution timeout for command contect (Default: 1000 ms)
  ///   - resetTimeout: Timeout to reset circuit (Default: 6000 ms)
  ///   - maxFailures: Maximum number of failures allowed before opening circuit (Default: 5)
  ///   - rollingWindow: (Default: 10000 ms)
  ///   - bulkhead: Number of the limit of concurrent requests running at one time. Default is set to 0, which is equivalent to not using the bulkheading feature.(Default: 0)
  ///   - contextCommand: Contextual function to circuit break, which allows user defined failures (the context provides an indirect reference to the corresponding circuit breaker instance; advanced usage constructor).
  ///   - fallback: Function user specifies to signal timeout or fastFail completion. Required format: (BreakerError, (fallbackArg1, fallbackArg2,...)) -> Void
  ///
  public convenience init(timeout: Int = 1000, resetTimeout: Int = 60000, maxFailures: Int = 5, rollingWindow: Int = 10000, bulkhead: Int = 0, contextCommand: @escaping AnyContextFunction<A>, fallback: @escaping AnyFallback<B>) {
    self.init(timeout: timeout, resetTimeout: resetTimeout, maxFailures: maxFailures, rollingWindow: rollingWindow, bulkhead: bulkhead, command: nil, contextCommand: contextCommand, fallback: fallback)
  }

  // MARK: Class Methods

  /// Runs the circuit using the provided arguments
  /// - Parameters:
  ///   - commandArgs: Arguments of type `A` for the circuit command
  ///   - fallbackArgs: Arguments of type `C` for the circuit fallback
  ///
  public func run(commandArgs: A, fallbackArgs: B) {
    breakerStats.trackRequest()
    
    switch breakerState {
    case .open:
      fastFail(fallbackArgs: fallbackArgs)

    case .halfopen:
      
      let startTime = Date()

      if let bulkhead = self.bulkhead {
          bulkhead.enqueue {
              self.callFunction(commandArgs: commandArgs, fallbackArgs: fallbackArgs)
          }
      }
      else {
          callFunction(commandArgs: commandArgs, fallbackArgs: fallbackArgs)
      }

      self.breakerStats.trackLatency(latency: Int(Date().timeIntervalSince(startTime)))

    case .closed:

      let startTime = Date()
      
      if let bulkhead = self.bulkhead {
          bulkhead.enqueue {
              self.callFunction(commandArgs: commandArgs, fallbackArgs: fallbackArgs)
          }
      }
      else {
          callFunction(commandArgs: commandArgs, fallbackArgs: fallbackArgs)
      }
      
      self.breakerStats.trackLatency(latency: Int(Date().timeIntervalSince(startTime)))
    }
  }

  /// Method to Print Current Stats Snapshot
  public func snapshot() {
    breakerStats.snapshot()
  }

  /// Method to force the circuit open
  public func notifyFailure(error: BreakerError, fallbackArgs: B) {
    handleFailure(error: error, fallbackArgs: fallbackArgs)
  }

  /// Method to force the circuit open
  public func notifySuccess() {
    handleSuccess()
  }

  /// Method to force the circuit open
  public func forceOpen() {
    semaphoreCircuit.wait()
    open()
    semaphoreCircuit.signal()
  }

  /// Method to force the circuit closed
  public func forceClosed() {
    semaphoreCircuit.wait()
    close()
    semaphoreCircuit.signal()
  }

  /// Method to force the circuit halfopen
  public func forceHalfOpen() {
    breakerState = .halfopen
  }

  /// Wrapper for calling and handling CircuitBreaker command
  private func callFunction(commandArgs: A, fallbackArgs: B) {

    var completed = false

    func complete(error: Bool) -> () {
      weak var _self = self
      semaphoreCompleted.wait()
      if completed {
        semaphoreCompleted.signal()
      } else {
        completed = true
        semaphoreCompleted.signal()
        
        error ? _self?.handleFailure(error: .timeout, fallbackArgs: fallbackArgs)
                :
                _self?.handleSuccess()

        return
      }
    }

    if let command = self.command {
      setTimeout() {
        complete(error: true)
      }

      let _ = command(commandArgs)
      complete(error: false)

    } else if let contextCommand = self.contextCommand {
      let invocation = Invocation(breaker: self, commandArgs: commandArgs, fallbackArgs: fallbackArgs)

      setTimeout() { [weak invocation] in
        if invocation?.completed == false {
          invocation?.setTimedOut()
          complete(error: true)
        }
      }

      let _ = contextCommand(invocation)
    }
  }

  /// Wrapper for setting the command timeout and updating breaker stats
  private func setTimeout(closure: @escaping () -> ()) {
    queue.asyncAfter(deadline: .now() + .milliseconds(self.timeout)) { [weak self] in
      self?.breakerStats.trackTimeouts()
      closure()
    }
  }

  /// The Current number of failures
  internal var numberOfFailures: Int {
    get {
      return failures.count
    }
  }

  /// Handler for a circuit failure. 
  private func handleFailure(error: BreakerError, fallbackArgs: B) {
    semaphoreCircuit.wait()
    Log.verbose("Handling failure...")

    // Add a new failure
    failures.add(Date.currentTimeMillis())

    // Get time difference between oldest and newest failure
    let timeWindow: UInt64? = failures.currentTimeWindow

    defer {
      breakerStats.trackFailedResponse()
      semaphoreCircuit.signal()
    }

    if state == .halfopen {
      Log.verbose("Failed in halfopen state.")
      let _ = fallback(error, fallbackArgs)
      open()
      return
    }

    if let timeWindow = timeWindow {
      if failures.count >= maxFailures && timeWindow <= UInt64(rollingWindow) {
        Log.verbose("Reached maximum number of failures allowed before tripping circuit.")
        let _ = fallback(error, fallbackArgs)
        open()
        return
      }
    }
    
    let _ = fallback(error, fallbackArgs)
  }

  /// Command Success handler
  private func handleSuccess() {
    semaphoreCircuit.wait()
    Log.verbose("Handling success...")
    if state == .halfopen {
      close()
    }
    breakerStats.trackSuccessfulResponse()
    semaphoreCircuit.signal()
  }

  /**
  * This function should be called within the boundaries of a semaphore.
  * Otherwise, resulting behavior may be unexpected.
  */
  private func close() {
    // Remove all failures (i.e. reset failure counter to 0)
    failures.clear()
    breakerState = .closed
  }

  /**
  * This function should be called within the boundaries of a semaphore.
  * Otherwise, resulting behavior may be unexpected.
  */
  private func open() {
    breakerState = .open
    startResetTimer(delay: .milliseconds(resetTimeout))
  }

  /// Fast Fail Handler
  private func fastFail(fallbackArgs: B) {
    Log.verbose("Breaker open... failing fast.")
    breakerStats.trackRejected()
    let _ = fallback(.fastFail, fallbackArgs)
  }

  /// Reset Timer Setup Method
  private func startResetTimer(delay: DispatchTimeInterval) {
    // Cancel previous timer if any
    resetTimer?.cancel()

    resetTimer = DispatchSource.makeTimerSource(queue: queue)

    resetTimer?.setEventHandler { [weak self] in
      self?.forceHalfOpen()
    }
    
    resetTimer?.schedule(deadline: .now() + delay)

    resetTimer?.resume()
  }
}
