import Foundation
import LoggerAPI
import Dispatch

public enum State {
    case open
    case halfopen
    case closed
}

public enum BreakerError {
    case timeout
    case fastFail
}

public class CircuitBreaker<A, B> {

    public typealias AnyFunction<A, B> = (A) -> (B)
    public typealias AnyFunctionWrapper<A, B> = (Invocation<A, B>) -> B

    var state: State
    private(set) var failures: Int
    var breakerStats: Stats
    var command: AnyFunction<A, B>?
    var commandWrapper: AnyFunctionWrapper<A, B>?
    var fallback: (BreakerError) -> Void

    let timeout: Double
    let resetTimeout: Int
    let maxFailures: Int
    var pendingHalfOpen: Bool
    var bulkhead: Bulkhead?

    var resetTimer: DispatchSourceTimer?
    let dispatchSemaphoreState = DispatchSemaphore(value: 1)
    let dispatchSemaphoreFailure = DispatchSemaphore(value: 1)
    let dispatchSemaphoreCompleted = DispatchSemaphore(value: 1)

    // TODO: Look at using OperationQueue and Operation instead to allow cancelling of tasks
    let queue = DispatchQueue(label: "Circuit Breaker Queue", attributes: .concurrent)

    public init (timeout: Double = 10, resetTimeout: Int = 60, maxFailures: Int = 5, bulkhead: Int = 0, fallback: @escaping (BreakerError) -> Void, command: @escaping AnyFunction<A, B>) {
        self.timeout = timeout
        self.resetTimeout = resetTimeout
        self.maxFailures = maxFailures

        self.state = State.closed
        self.failures = 0
        self.pendingHalfOpen = false
        self.breakerStats = Stats()

        self.fallback = fallback
        self.command = command
        self.commandWrapper = nil
        
        if bulkhead > 0 {
            self.bulkhead = Bulkhead.init(limit: bulkhead)
        }
    }

    public init (timeout: Double = 10, resetTimeout: Int = 60, maxFailures: Int = 5, bulkhead: Int = 0, fallback: @escaping (BreakerError) -> Void, commandWrapper: @escaping AnyFunctionWrapper<A, B>) {
        self.timeout = timeout
        self.resetTimeout = resetTimeout
        self.maxFailures = maxFailures

        self.state = State.closed
        self.failures = 0
        self.pendingHalfOpen = false
        self.breakerStats = Stats()

        self.fallback = fallback
        self.command = nil
        self.commandWrapper = commandWrapper
        
        if bulkhead > 0 {
            self.bulkhead = Bulkhead.init(limit: bulkhead)
        }
    }

    // Run
    public func run(args: A) {
        breakerStats.trackRequest()

        if state == State.open || (state == State.halfopen && pendingHalfOpen == true) {
           fastFail()
        } else if state == State.halfopen && pendingHalfOpen == false {
            pendingHalfOpen = true
            let startTime:Date = Date()
            
            if let bulkhead = self.bulkhead {
                bulkhead.enqueue(task: {
                    self.callFunction(args: args)
                })
            }
            else {
                callFunction(args: args)
            }
            
            self.breakerStats.trackLatency(latency: Int(Date().timeIntervalSince(startTime)))
        } else {
            let startTime:Date = Date()
            
            if let bulkhead = self.bulkhead {
                bulkhead.enqueue(task: {
                    self.callFunction(args: args)
                })
            }
            else {
                callFunction(args: args)
            }
            
            self.breakerStats.trackLatency(latency: Int(Date().timeIntervalSince(startTime)))
        }
    }

    private func callFunction(args: A) {

        var completed = false

        func complete (error: Bool) -> () {
           weak var _self = self
            dispatchSemaphoreCompleted.wait()
            if !completed {
                completed = true
                dispatchSemaphoreCompleted.signal()
                if !error {
                    _self?.handleSuccess()
                } else {
                    _self?.handleFailures()
                    _self?.fallback(BreakerError.timeout)
                }
                return
            } else {
                dispatchSemaphoreCompleted.signal()
            }
        }

        if let command = self.command {
            setTimeout () {
                complete(error: true)
                return
            }

            let _ = command(args)
            complete(error: false)
        } else if let commandWrapper = self.commandWrapper {
            let invocation = Invocation(breaker: self, args: args)

            setTimeout () { [weak invocation] in
                if invocation?.completed ?? false {
                    complete(error: true)
                    invocation?.setTimedOut()
                }

                return
            }

            let _ = commandWrapper(invocation)
        }

    }

    private func setTimeout(closure: @escaping () -> ()) {
        queue.asyncAfter(deadline: .now() + self.timeout) { [weak self] in
            self?.breakerStats.trackTimeouts()
            closure()
        }
    }

    // Print Current Stats Snapshot
    public func snapshot () {
        return breakerStats.snapshot()
    }

    public func notifyFailure() {
        handleFailures()
    }

    public func notifySuccess() {
        handleSuccess()
    }

    // Get/Set functions
    public private(set) var breakerState: State {

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

        if ((failures >= maxFailures) || (state == State.halfopen)) {
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
        fallback(BreakerError.fastFail)

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

        resetTimer?.setEventHandler { [weak self] in
            self?.forceHalfOpen()
        }

        resetTimer?.scheduleOneshot(deadline: .now() + delay)

        resetTimer?.resume()
    }

}

// Invocation entity
public class Invocation<A, B> {

    public let args: A
    private(set) var timedOut: Bool = false
    private(set) var completed: Bool = false
    weak private var breaker: CircuitBreaker<A, B>?
    public init(breaker: CircuitBreaker<A, B>, args: A) {
        self.args = args
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
            breaker?.notifySuccess()
        }
    }

    public func notifyFailure() {
        if !self.timedOut {
            breaker?.notifyFailure()
        }
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
        serialQueue.async {
            self.semaphore.wait()
            self.concurrentQueue.async {
                task()
                self.semaphore.signal()
            }
        }
    }
}
