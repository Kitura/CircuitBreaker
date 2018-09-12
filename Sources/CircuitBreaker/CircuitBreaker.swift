/**
* Copyright IBM Corporation 2017, 2018
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

/// CircuitBreaker enables you to use Circuit Breaker logic in your Swift applications.
///
/// - A: Parameter types used in the arguments for the command closure.
/// - B: Parameter type used as the second argument for the fallback closure.
///
/// ### Usage Example: ###
/// The example below shows how to create a `CircuitBreaker` instance for each context
/// function (e.g. endpoint) you wish to circuit break. You need to give the CircuitBreaker instance a name,
/// create a context function for the endpoint you intend to circuit break (`myContextFunction` in the example
/// below) and define a fallback function (`myFallback` in the example below) to call if there are timeouts
/// or user defined failures occur.
/// ```swift
/// let breaker = CircuitBreaker(name: "Circuit1", command: myContextFunction, fallback: myFallback)
/// ```
///
/// For a more complete example see the
/// [CircuitBreaker README](https://github.com/IBM-Swift/CircuitBreaker).
public class CircuitBreaker<A, B> {

  // MARK: Closure Aliases

  /// The context function that runs using the given arguments of generic type A.
  public typealias AnyContextFunction<A> = (Invocation<A, B>) -> Void

  /// The fallback function that runs when the invocation fails.
  public typealias AnyFallback<B> = (BreakerError, B) -> Void

  // MARK: Public Fields

  /// Name of the CircuitBreaker instance.
  public private(set) var name: String

  /// Name of the CircuitBreaker group.
  public private(set) var group: String?

  /// Execution timeout for the command context, that is, the time in milliseconds that your function must
  /// complete within before the invocation is considered a failure. Default value is 1000 milliseconds.
  public let timeout: Int

  /// Timeout to reset the circuit, that is, the time in milliseconds to wait before resetting the circuit
  /// to half open state. Default value is 6000 milliseconds.
  public let resetTimeout: Int

  /// Number of failures allowed within `rollingWindow` before setting the circuit state to open.
  /// Default value is 5.
  public let maxFailures: Int

  /// Time window in milliseconds within which the maximum number of failures must occur to trip the circuit.
  /// For instance, say `maxFailures` is 5 and `rollingWindow` is 10000 milliseconds. In such a case, for the
  /// circuit to trip, 5 invocation failures must occur in a time window of 10 seconds, even if these failures
  /// are not consecutive. Default value is 10000 milliseconds.
  public let rollingWindow: Int

  /// Instance of Circuit Breaker statistics.
  public let breakerStats = Stats()

  /// The Circuit Breaker's current state.
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
  //fallback function is invoked ONLY when failing fast OR when timing out OR when application
  //notifies circuit that command did not complete successfully.
  private let fallback: AnyFallback<B>
  private let command: AnyContextFunction<A>
  private let bulkhead: Bulkhead?

  /// Dispatch
  private var resetTimer: DispatchSourceTimer?
  private let semaphoreCircuit = DispatchSemaphore(value: 1)

  private let queue = DispatchQueue(label: "Circuit Breaker Queue", attributes: .concurrent)

  // MARK: Initializers

  /// Initializes a CircuitBreaker instance with an asyncronous context command.
  ///
  /// - Parameters:
  ///   - name: Name of the CircuitBreaker instance.
  ///   - group: Name of the CircuitBreaker group (optional).
  ///   - timeout: Execution timeout for command context. That is, the time in milliseconds that your function must
  ///     complete within before the invocation is considered a failure. Default is set to 1000 milliseconds.
  ///   - resetTimeout: Time in milliseconds to wait before resetting the circuit to half open state. Default is
  ///     set to 60000 milliseconds.
  ///   - maxFailures: Maximum number of failures allowed within `rollingWindow` before opening the circuit.
  ///     Default is set to 5.
  ///   - rollingWindow: Time window in milliseconds within which the maximum number of failures must occur to
  ///     trip the circuit. For instance, say `maxFailures` is 5 and `rollingWindow` is 10000 milliseconds. In such
  ///     a case, for the circuit to trip, 5 invocation failures must occur in a time window of 10 seconds, even if
  ///     these failures are not consecutive. Default is set to 10000 milliseconds.
  ///   - bulkhead: Number representing the limit of concurrent requests running at one time. Default is 0,
  ///     which is equivalent to not using the bulk heading feature.
  ///   - command: Contextual function to circuit break, which allows user defined failures
  ///     (the context provides an indirect reference to the corresponding circuit breaker instance).
  ///   - fallback: Function user specifies to signal timeout or fastFail completion.
  ///     Required format: ```(BreakerError, (fallbackArg1, fallbackArg2,...)) -> Void```
  ///
  public init(name: String,
              group: String? = nil,
              timeout: Int = 1000,
              resetTimeout: Int = 60000,
              maxFailures: Int = 5,
              rollingWindow: Int = 10000,
              bulkhead: Int = 0,
              command: @escaping AnyContextFunction<A>,
              fallback: @escaping AnyFallback<B>) {
    self.name = name
    self.group = group
    self.timeout = timeout
    self.resetTimeout = resetTimeout
    self.maxFailures = maxFailures
    self.rollingWindow = rollingWindow
    self.fallback = fallback
    self.command = command
    self.failures = FailureQueue(size: maxFailures)
    self.bulkhead = (bulkhead > 0) ? Bulkhead.init(limit: bulkhead) : nil

    // Link to Observers

    MonitorCollection.sharedInstance.values.forEach { $0.register(breakerRef: self) }
  }

  // MARK: Class Methods

  /// Runs the circuit using the provided arguments.
  /// ### Usage Example: ###
  /// The example below shows how to create and then run a circuit.
  /// ```swift
  /// let breaker = CircuitBreaker(name: "Circuit1", command: myFunction, fallback: myFallback)
  /// breaker.run(commandArgs: (a: 10, b: 20), fallbackArgs: "Something went wrong.")
  /// ```
  /// - Parameters:
  ///   - commandArgs: Arguments of type `A` for the circuit command.
  ///   - fallbackArgs: Arguments of type `B` for the circuit fallback.
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
              self.callFunction(startTime: startTime, commandArgs: commandArgs, fallbackArgs: fallbackArgs)
          }
      } else {
          callFunction(startTime: startTime, commandArgs: commandArgs, fallbackArgs: fallbackArgs)
      }

    case .closed:
      let startTime = Date()

      if let bulkhead = self.bulkhead {
          bulkhead.enqueue {
              self.callFunction(startTime: startTime, commandArgs: commandArgs, fallbackArgs: fallbackArgs)
          }
      } else {
          callFunction(startTime: startTime, commandArgs: commandArgs, fallbackArgs: fallbackArgs)
      }
    }
  }

  /// Method to print current statistics.
  /// ### Usage Example: ###
  /// The example below shows how to log a snapshot of the statistics for a given CircuitBreaker instance.
  /// ```swift
  /// let breaker = CircuitBreaker(name: "Circuit1", command: myFunction, fallback: myFallback)
  /// breaker.run(commandArgs: (a: 10, b: 20), fallbackArgs: "Something went wrong.")
  /// breaker.logSnapshot()
  /// ```
  public func logSnapshot() {
    breakerStats.snapshot()
  }

  /// Method to notify circuit of a completion with a failure.
  internal func notifyFailure(error: BreakerError, fallbackArgs: B) {
    handleFailure(error: error, fallbackArgs: fallbackArgs)
  }

  /// Method to notify circuit of a successful completion.
  internal func notifySuccess() {
    handleSuccess()
  }

  /// Method to force the circuit open.
  public func forceOpen() {
    semaphoreCircuit.wait()
    open()
    semaphoreCircuit.signal()
  }

  /// Method to force the circuit closed.
  public func forceClosed() {
    semaphoreCircuit.wait()
    close()
    semaphoreCircuit.signal()
  }

  /// Method to force the circuit half open.
  public func forceHalfOpen() {
    breakerState = .halfopen
  }

  /// Wrapper for calling and handling CircuitBreaker command
  private func callFunction(startTime: Date, commandArgs: A, fallbackArgs: B) {

    let invocation = Invocation(startTime: startTime, breaker: self, commandArgs: commandArgs, fallbackArgs: fallbackArgs)

    setTimeout { [weak invocation, weak self] in
      if invocation?.nofityTimedOut() == true {
        self?.handleFailure(error: .timeout, fallbackArgs: fallbackArgs)
      }
    }

    // Invoke command
    command(invocation)
  }

  /// Wrapper for setting the command timeout and updating breaker stats
  private func setTimeout(closure: @escaping () -> Void) {
    queue.asyncAfter(deadline: .now() + .milliseconds(self.timeout)) { [weak self] in
      self?.breakerStats.trackTimeouts()
      closure()
    }
  }

  /// The current number of failures.
  internal var numberOfFailures: Int {
    return failures.count
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
      // Invoking callback after updating circuit stats and state
      // This way we eliminate the possibility of a deadlock and/or
      // holding on to the semaphore for a long time because the fallback
      // method has not returned.
      fallback(error, fallbackArgs)
    }

    defer {
      breakerStats.trackFailedResponse()
      semaphoreCircuit.signal()
    }

    if state == .halfopen {
      Log.verbose("Failed in halfopen state.")
      open()
      return
    }

    if let timeWindow = timeWindow {
      if failures.count >= maxFailures && timeWindow <= UInt64(rollingWindow) {
        Log.verbose("Reached maximum number of failures allowed before tripping circuit.")
        open()
        return
      }
    }

  }

  /// Command success handler
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

  /// Fast fail handler
  private func fastFail(fallbackArgs: B) {
    Log.verbose("Breaker open... failing fast.")
    breakerStats.trackRejected()
    fallback(.fastFail, fallbackArgs)
  }

  /// Reset timer setup
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

extension CircuitBreaker: StatsProvider {

  /// Method to create a link to a StatsMonitor instance.
  /// ### Usage Example: ###
  /// Given a monitor class called `exampleMonitor` which implements `StatsMonitor` you can link this
  /// monitor to CircuitBreaker as shown below. During the initialization of the CircuitBreaker instances
  /// (circuit1 and circuit2) the linked monitor is notified of their instantiation thus allowing it to begin
  /// tracking the statistics for both instances.
  /// ```swift
  /// let monitor1 = exampleMonitor()
  /// CircuitBreaker<Any, Any>.addMonitor(monitor: monitor1)
  /// let circuit1 = CircuitBreaker(name: "Circuit1", command: myContextFunction, fallback: myFallback)
  /// let circuit2 = CircuitBreaker(name: "Circuit2", command: myContextFunction, fallback: myFallback)
  /// ```
  public static func addMonitor(monitor: StatsMonitor) {
    MonitorCollection.sharedInstance.values.append(monitor)
  }

  /// Property to compute a snapshot.
  /// ### Usage Example: ###
  /// The example below shows how to compute a Hystrix compliant snapshot of the statistics for a given
  /// CircuitBreaker instance.
  /// ```swift
  /// let breaker = CircuitBreaker(name: "Circuit1", command: myFunction, fallback: myFallback)
  /// breaker.run(commandArgs: (a: 10, b: 20), fallbackArgs: "Something went wrong.")
  /// let snapshot = breaker.snapshot
  /// ```
  public var snapshot: Snapshot {
    return Snapshot(name: name, group: group, stats: self.breakerStats, state: breakerState)
  }
}
