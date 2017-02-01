import Foundation
import LoggerAPI
import Dispatch

public class CircuitBreaker {

    public enum State {
        case open
        case halfopen
        case closed
    }
    
    public typealias AnyFunction<A, B> = (A) -> B
    
    private(set) var state: State
    private(set) var failures: Int
    var breakerStats: Stats
    var command: String
    var callback: (_ error: Bool) -> Void

    let timeout: Double
    let resetTimeout: Int
    let maxFailures: Int
    var pendingHalfOpen: Bool

    var resetTimer: DispatchSourceTimer?
    let dispatchSemaphoreState = DispatchSemaphore(value: 1)
    let dispatchSemaphoreFailure = DispatchSemaphore(value: 1)

    // TODO: Look at using OperationQueue and Operation instead to allow cancelling of tasks
    let queue = DispatchQueue(label: "Circuit Breaker Queue", attributes: .concurrent)

    // command (Take a function, parameters, error completion)
    public init (timeout: Double = 10, resetTimeout: Int = 60, maxFailures: Int = 5, callback: @escaping (_ error: Bool) -> Void, command: String) {
        self.timeout = timeout
        self.resetTimeout = resetTimeout
        self.maxFailures = maxFailures

        self.state = State.closed
        self.failures = 0
        self.pendingHalfOpen = false
        self.breakerStats = Stats()

        self.callback = callback
        self.command = command
    }

    // Run
    public func run<A, B>(f: AnyFunction<A, B>,args: Any) -> B {
        breakerStats.trackRequest()

        if state == State.open || (state == State.halfopen && pendingHalfOpen == true) {
            fastFail()
            return () as! B
        } else if state == State.halfopen && pendingHalfOpen == false {
            pendingHalfOpen = true
            return callFunction(f: f, args: args)
        } else {
            return callFunction(f: f, args: args)
        }
    }

    private func callFunction<A, B>(f: AnyFunction<A, B>, args: Any) -> B{

        var completed = false

        func complete (error: Bool) -> () {
            if !completed {
                completed = true
                if !error {
                    handleSuccess()
                } else {
                    handleFailures()
                }
                return callback(error)
            }
        }

        let startTime:Date = Date()

        breakerStats.trackLatency(latency: Int(Date().timeIntervalSince(startTime)))

        setTimeout () {
            complete(error: true)
            return
        }

        let result = f(args as! A)
            
        complete(error: false)
        return result
    }

    private func setTimeout(closure: @escaping () -> ()) {
        queue.asyncAfter(deadline: .now() + self.timeout) {
            self.breakerStats.trackTimeouts()
            closure()
        }
    }

    // Print Current Stats Snapshot
    public func snapshot () {
        return breakerStats.snapshot()
    }

    // Get/Set functions
    var breakerState: State {

        get {
            dispatchSemaphoreState.wait()
            let currentState = state
            dispatchSemaphoreState.signal()
            return currentState
        }

        set {
            dispatchSemaphoreState.wait()
            state = newValue
            dispatchSemaphoreState.signal()
        }
    }

    var numFailures: Int {

        get {
            dispatchSemaphoreFailure.wait()
            let currentFailures = failures
            dispatchSemaphoreFailure.signal()
            return currentFailures
        }

        set {
            dispatchSemaphoreFailure.wait()
            failures = newValue
            dispatchSemaphoreFailure.signal()
        }

    }

    private func handleFailures () {
        numFailures += 1

        if ((failures == maxFailures) || (state == State.halfopen)) {
            Log.error("Reached max failures, or failed in halfopen state.")
            forceOpen()
        }

        breakerStats.trackFailedResponse()
    }

    private func handleSuccess () {
        forceClosed()

        breakerStats.trackSuccessfulResponse()
    }

    private func fastFail () {
        Log.verbose("Breaker open.")
        breakerStats.trackRejected()
        callback(true)

    }

    public func forceOpen () {
        breakerState = State.open

        startResetTimer(delay: .seconds(resetTimeout))
    }

    public func forceClosed () {
        breakerState = State.closed
        numFailures = 0
        pendingHalfOpen = false
    }

    public func forceHalfOpen () {
       breakerState = State.halfopen
    }

    private func startResetTimer(delay: DispatchTimeInterval) {
        // Cancel previous timer if any
        resetTimer?.cancel()

        resetTimer = DispatchSource.makeTimerSource(queue: queue)

        resetTimer?.scheduleOneshot(deadline: .now(), leeway: delay)

        resetTimer?.setEventHandler { [weak self] in
            self?.forceHalfOpen()
        }

        resetTimer?.resume()
    }

}
