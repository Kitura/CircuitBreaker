import Foundation
// TODO: Remove PromiseKit reference
import PromiseKit

public class CircuitBreaker {
    
    public enum State {
        case OPEN
        case HALFOPEN
        case CLOSED
    }
    
    private(set) var state: State
    private(set) var failures: Int
    var breakerStats: Stats!
    var function: () -> Void
    var callback: () -> Void
    
    let timeout: Double
    let resetTimeout: Double
    let maxFailures: Int
    var pendingHalfOpen: Bool
    
    var resetTimer: DispatchSourceTimer?
    let dispatchSemaphoreState = DispatchSemaphore(value: 0)
    let dispatchSemaphoreFailure = DispatchSemaphore(value: 0)
    
    let timeoutQueue = DispatchQueue(label: "Circuit Breaker Timeout", attributes: .concurrent)
    
    init (timeout: Double = 10, resetTimeout: Double = 60, maxFailures: Int = 5, callback: @escaping () -> Void, selector: @escaping () -> Void) {
        self.timeout = timeout
        self.resetTimeout = resetTimeout
        self.maxFailures = maxFailures
    
        self.state = State.CLOSED
        self.failures = 0
        self.pendingHalfOpen = false
        self.breakerStats = Stats()
        
        self.callback = callback
        self.function = selector
    }
    
    
    // Run
    func run () {
        breakerStats.trackRequest()
        
        if self.state == State.OPEN || (self.state == State.HALFOPEN && self.pendingHalfOpen == true) {
            return self.fastFail()
        } else if self.state == State.HALFOPEN && self.pendingHalfOpen == false {
            self.pendingHalfOpen = true
            return self.callFunction()
        } else {
            return self.callFunction()
        }
    }
    
    // fastFail
    func fastFail () {
        return breakerStats.trackRejected()
    
    }
    
    // callFunction
    func callFunction () {
        
        var completed = false
        
        func complete (error: Bool) -> () {
            if completed == false {
                completed = true
                if error == false {
                    self.handleSuccess()
                } else {
                    self.handleFailures()
                }
                
                return self.callback()
            }
        }
        
        // Call the function using timeout/error
        // If the function fails, handle failure
        // If the function is successful, handle success
        // Then this ends
        
        let startTime:Date = Date()
        
        self.breakerStats.trackLatency(latency: Int(Date().timeIntervalSince(startTime)))
        
        // TODO: Wrap this function call with a promise or a timer associated with the CircuitBreaker
        self.setTimeout(delay: self.timeout) {
            print("Exiting...")
            complete(error: true)
            return
        }
        
        print("Running function")
        self.handleFunction {
            self.function()
            complete(error: false)
            return
        }
    }
    
    func setTimeout(delay: Double, closure: @escaping () -> ()) {
        timeoutQueue.asyncAfter(deadline: .now() + delay) {
            self.breakerStats.trackTimeouts()
            closure()
        }
    }
    
    func handleFunction(closure: @escaping () -> ()) {
        closure()
    }
    
    // Print Current Stats Snapshot
    func snapshot () {
        return breakerStats.snapshot()
    }
    
    // Get/Set functions
    // TODO: Have this code reviewed
    var breakerState: State {
        
        get {
            return self.state
        }
        
        set {
            if case DispatchTimeoutResult.timedOut = dispatchSemaphoreState.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(1)) {
                print("In wait.")
            }
            self.state = newValue
            dispatchSemaphoreState.signal()
        }
    }
    
    var numFailures: Int {
        
        get {
            return self.failures
        }
        
        set {
            if case DispatchTimeoutResult.timedOut = dispatchSemaphoreFailure.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(1)) {
                print("In wait.")
            }
            self.failures = newValue
            dispatchSemaphoreFailure.signal()
        }
        
    }
    
    func handleFailures () {
        print("Incrementing failures..")
        self.numFailures += 1
        
        if self.failures == self.maxFailures || self.state == State.HALFOPEN {
            self.forceOpen()
        }
        
        breakerStats.trackFailedResponse()
    }
    
    func handleSuccess () {
        print("Incrementing success..")
        self.forceClosed()
        
        breakerStats.trackSuccessfulResponse()
    }
    
    func forceOpen () {
        self.breakerState = State.OPEN
        
        // TODO: Test timer is working here
        self.startResetTimer(delay: .seconds(Int(self.resetTimeout)))
    }
    
    func forceClosed () {
        self.breakerState = State.CLOSED
        self.numFailures = 0
        self.pendingHalfOpen = false
    }
    
    func forceHalfOpen () {
        self.breakerState = State.HALFOPEN
    }
    
    private func startResetTimer(delay: DispatchTimeInterval) {
        let queue = DispatchQueue(label: "Circuit Breaker Reset Timer", attributes: .concurrent)
        
        // Cancel previous timer if any
        resetTimer?.cancel()
        
        resetTimer = DispatchSource.makeTimerSource(queue: queue)
        
        resetTimer?.scheduleOneshot(deadline: .now(), leeway: delay)
        
        resetTimer?.setEventHandler { [weak self] in
            self?.forceHalfOpen()
        }
        
        resetTimer?.resume()
    }
    
    private func stopResetTimer() {
        resetTimer?.cancel()
        resetTimer = nil
    }
    
}

