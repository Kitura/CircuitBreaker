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

 //https://www.cocoawithlove.com/blog/2016/06/02/threads-and-mutexes.html

import Foundation
import Dispatch
import LoggerAPI

public enum State {
    case open
    case halfopen
    case closed
}

public enum BreakerError {
    case timeout
    case fastFail
}

public class CircuitBreaker<A, B, C> {
/*
  public class Builder {
    var id: String?
    var name: String?
    var uris: [String]?
    var version: String?
    var instanceId: String?
    var instanceIndex: Int?
    var limits: Limits?
    var port: Int?
    var spaceId: String?
    var startedAt: Date? // Not provided on Diego
    init() {}

    func setId(id: String?) -> Builder {
      self.id = id
      return self
    }

    func setName(name: String?) -> Builder {
      self.name = name
      return self
    }

    func setUris(uris: [String]) -> Builder {
      self.uris = uris
      return self
    }

    func setVersion(version: String?) -> Builder {
      self.version = version
      return self
    }

    func setInstanceId(instanceId: String?) -> Builder {
      self.instanceId = instanceId
      return self
    }

    func setInstanceIndex(instanceIndex: Int?) -> Builder {
      self.instanceIndex = instanceIndex
      return self
    }

    func setLimits(limits: Limits) -> Builder {
      self.limits = limits
      return self
    }

    func setPort(port: Int?) -> Builder {
      self.port = port
      return self
    }

    func setSpaceId(spaceId: String?) -> Builder {
      self.spaceId = spaceId
      return self
    }

    func setStartedAt(startedAt: Date?) -> Builder {
      self.startedAt = startedAt
      return self
    }

    func build() -> App? {
      guard let id = id, let name = name,
      let uris = uris, let version = version,
      let instanceId = instanceId,
      let instanceIndex = instanceIndex,
      let limits = limits,
      let port = port,
      let spaceId = spaceId else {
          return nil
      }

      return App(id: id, name: name, uris: uris, version: version, instanceId: instanceId,
        instanceIndex: instanceIndex, limits: limits, port: port, spaceId: spaceId,
        startedAt: startedAt)
    }
  }*/

    // Closure aliases
    public typealias AnyFunction<A, B> = (A) -> (B)
    public typealias AnyFunctionWrapper<A, B> = (Invocation<A, B, C>) -> B
    public typealias AnyFallback<C> = (BreakerError, C) -> Void

    var state: State = State.closed
    private var failures = Collection<UInt64>()
    private(set) var pendingHalfOpen: Bool = false
    var breakerStats: Stats = Stats()
    var command: AnyFunction<A, B>?
    var fallback: AnyFallback<C>
    var commandWrapper: AnyFunctionWrapper<A, B>?

    let timeout: Int
    let resetTimeout: Int
    let maxFailures: Int
    let rollingWindow: Int
    var bulkhead: Bulkhead?

    var resetTimer: DispatchSourceTimer?
    //let semaphoreState = DispatchSemaphore(value: 1)
    let semaphoreCompleted = DispatchSemaphore(value: 1)
    //let semaphoreHalfOpen = DispatchSemaphore(value: 1)
    let semaphoreHalfOpenCall = DispatchSemaphore(value: 1)
    //let semaphoreFailures = DispatchSemaphore(value: 1)
    let semaphoreCircuit = DispatchSemaphore(value: 1)

    let queue = DispatchQueue(label: "Circuit Breaker Queue", attributes: .concurrent)

    private init(timeout: Int, resetTimeout: Int, maxFailures: Int, rollingWindow: Int, bulkhead: Int, fallback: @escaping AnyFallback<C>, command: (AnyFunction<A, B>)?, commandWrapper: (AnyFunctionWrapper<A, B>)?) {
        self.timeout = timeout
        self.resetTimeout = resetTimeout
        self.maxFailures = maxFailures
        self.rollingWindow = rollingWindow
        self.fallback = fallback
        self.command = command
        self.commandWrapper = commandWrapper
        if bulkhead > 0 {
            self.bulkhead = Bulkhead.init(limit: bulkhead)
        }
    }

    public convenience init(timeout: Int = 1000, resetTimeout: Int = 60000, maxFailures: Int = 5, rollingWindow: Int = 10000, bulkhead: Int = 0, fallback: @escaping AnyFallback<C>, command: @escaping AnyFunction<A, B>) {
        self.init(timeout: timeout, resetTimeout: resetTimeout, maxFailures: maxFailures, rollingWindow: rollingWindow, bulkhead: bulkhead, fallback: fallback, command: command, commandWrapper: nil)
    }

    public convenience init(timeout: Int = 1000, resetTimeout: Int = 60000, maxFailures: Int = 5, rollingWindow: Int = 10000, bulkhead: Int = 0, fallback: @escaping AnyFallback<C>, commandWrapper: @escaping AnyFunctionWrapper<A, B>) {
        self.init(timeout: timeout, resetTimeout: resetTimeout, maxFailures: maxFailures, rollingWindow: rollingWindow, bulkhead: bulkhead, fallback: fallback, command: nil, commandWrapper: commandWrapper)
    }

    // Run
    public func run(commandArgs: A, fallbackArgs: C) {
        breakerStats.trackRequest()

        if breakerState == State.open {
            fastFail(fallbackArgs: fallbackArgs)

        } else if breakerState == State.halfopen {
                let startTime:Date = Date()

                if let bulkhead = self.bulkhead {
                    bulkhead.enqueue(task: {
                        self.callFunction(commandArgs: commandArgs, fallbackArgs: fallbackArgs)
                    })
                }
                else {
                    callFunction(commandArgs: commandArgs, fallbackArgs: fallbackArgs)
                }

                self.breakerStats.trackLatency(latency: Int(Date().timeIntervalSince(startTime)))

        } else {
            let startTime:Date = Date()

            if let bulkhead = self.bulkhead {
                bulkhead.enqueue(task: {
                    self.callFunction(commandArgs: commandArgs, fallbackArgs: fallbackArgs)
                })
            }
            else {
                callFunction(commandArgs: commandArgs, fallbackArgs: fallbackArgs)
            }

            self.breakerStats.trackLatency(latency: Int(Date().timeIntervalSince(startTime)))
        }
    }

    private func callFunction(commandArgs: A, fallbackArgs: C) {

        var completed = false

        func complete(error: Bool) -> () {
           weak var _self = self
            semaphoreCompleted.wait()
            if completed {
                semaphoreCompleted.signal()
            } else {
                completed = true
                semaphoreCompleted.signal()
                if error {
                    _self?.handleFailure()
                    let _ = fallback(.timeout, fallbackArgs)
                } else {
                    _self?.handleSuccess()
                }
                return
            }
        }

        if let command = self.command {
            setTimeout() {
                complete(error: true)
            }

            let _ = command(commandArgs)
            complete(error: false)
        } else if let commandWrapper = self.commandWrapper {
            let invocation = Invocation(breaker: self, commandArgs: commandArgs)

            setTimeout() { [weak invocation] in
                if invocation?.completed == false {
                    invocation?.setTimedOut()
                    complete(error: true)
                }
            }

            let _ = commandWrapper(invocation)
        }
    }

    private func setTimeout(closure: @escaping () -> ()) {
        queue.asyncAfter(deadline: .now() + .milliseconds(self.timeout)) { [weak self] in
            self?.breakerStats.trackTimeouts()
            closure()
        }
    }

    // Print Current Stats Snapshot
    public func snapshot() {
        return breakerStats.snapshot()
    }

    public func notifyFailure() {
        handleFailure()
    }

    public func notifySuccess() {
        handleSuccess()
    }

    // Get/Set functions
    public private(set) var breakerState: State {
        get {
            //semaphoreState.wait()
            //let currentState = state
            //semaphoreState.signal()
            //return currentState
            return state
        }

        set {
            //semaphoreState.wait()
            state = newValue
            //semaphoreState.signal()
        }
    }

    var numberOfFailures: Int {
        get {
            return failures.size
        }
    }

    // var pendingHalfOpenCall: Bool {
    //     get {
    //         //semaphoreHalfOpen.wait()
    //         //let halfOpenCallStatus = pendingHalfOpen
    //         //semaphoreHalfOpen.signal()
    //         //return halfOpenCallStatus
    //         return pendingHalfOpen
    //     }
    //
    //     set {
    //         //semaphoreHalfOpen.wait()
    //         pendingHalfOpen = newValue
    //         //semaphoreHalfOpen.signal()
    //     }
    // }

    private func handleFailure() {
        semaphoreCircuit.wait()
        Log.verbose("Handling failure...")
        // Add a new failure
        failures.add(Date.currentTimeMillis())
        if failures.size > maxFailures {
          let _ = failures.removeFirst()
        }

        // Get time difference
        let timeWindow: UInt64?
        if let firstFailureTs = failures.peekFirst(), let lastFailureTs = failures.peekLast() {
          timeWindow = lastFailureTs - firstFailureTs
        } else {
          timeWindow = nil
        }

        defer {
            breakerStats.trackFailedResponse()
            semaphoreCircuit.signal()
        }

        if (state == State.halfopen) {
            Log.error("Failed in halfopen state.")
            open()
            return
        }

        if let timeWindow = timeWindow {
            if failures.size >= maxFailures && timeWindow <= UInt64(rollingWindow) {
                Log.error("Reached maximum number of failures allowed before tripping circuit.")
                open()
                return
            }
        }
    }

    private func handleSuccess() {
        semaphoreCircuit.wait()
        Log.verbose("Handling success...")
        if state == State.halfopen {
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
      breakerState = State.closed
    }

    /**
    * This function should be called within the boundaries of a semaphore.
    * Otherwise, resulting behavior may be unexpected.
    */
    private func open() {
        breakerState = State.open
        startResetTimer(delay: .milliseconds(resetTimeout))
    }

    private func fastFail(fallbackArgs: C) {
        Log.verbose("Breaker open... failing fast.")
        breakerStats.trackRejected()
        let _ = fallback(.fastFail, fallbackArgs)
    }

    public func forceOpen() {
        semaphoreCircuit.wait()
        open()
        semaphoreCircuit.signal()
    }

    public func forceClosed() {
        semaphoreCircuit.wait()
        close()
        //pendingHalfOpenCall = false
        semaphoreCircuit.signal()
    }

    public func forceHalfOpen() {
        breakerState = State.halfopen
    }

    private func startResetTimer(delay: DispatchTimeInterval) {
        // Cancel previous timer if any
        resetTimer?.cancel()

        resetTimer = DispatchSource.makeTimerSource(queue: queue)

        resetTimer?.setEventHandler { [weak self] in
            self?.forceHalfOpen()
        }

        resetTimer?.scheduleOneshot(deadline: .now() + delay)

        resetTimer?.resume()
    }

}

class Bulkhead {

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
