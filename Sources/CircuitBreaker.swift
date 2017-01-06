import Foundation
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
    
    let timeout: Double
    let resetTimeout: Double
    let maxFailures: Int
    var pendingHalfOpen: Bool
    
    var timer: DispatchSourceTimer?
    let dispatchSemaphoreState = DispatchSemaphore(value: 0)
    let dispatchSemaphoreFailure = DispatchSemaphore(value: 0)
    
    init (timeout: Double = 10, resetTimeout: Double = 60, maxFailures: Int = 5, selector: @escaping () -> Void) {
        self.timeout = timeout
        self.resetTimeout = resetTimeout
        self.maxFailures = maxFailures
    
        self.state = State.CLOSED
        self.failures = 0
        self.pendingHalfOpen = false
        self.breakerStats = Stats()
        
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
        
        // Call the function using timeout/error
        // If the function fails, handle failure
        // If the function is successful, handle success
        // Then this ends
        
        let startTime:Date = Date()
        
        self.breakerStats.trackLatency(latency: Int(Date().timeIntervalSince(startTime)))

        // TODO: Wrap this function call with a promise on a timer associated with the CircuitBreaker
        self.function()
        //if(err) {
        //    self.handleFailures()
        //} else {
        //    self.handleSuccess();
        //}
    }
    
    // handleTimeout
    func handleTimeout (deferred: Promise<Any>, startTime: Date) {
        self.handleFailures()
        
        breakerStats.trackTimeouts()
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
        self.numFailures += 1
        
        if self.failures == self.maxFailures || self.state == State.HALFOPEN {
            self.forceOpen()
        }
        
        breakerStats.trackFailedResponse()
    }
    
    func handleSuccess () {
        self.forceClosed()
        
        breakerStats.trackSuccessfulResponse()
    }
    
    func forceOpen () {
        self.breakerState = State.OPEN
        
        // TODO: Test timer is working here
        self.startTimer(delay: .seconds(Int(self.resetTimeout)))
    }
    
    func forceClosed () {
        self.breakerState = State.CLOSED
        self.numFailures = 0
        self.pendingHalfOpen = false
    }
    
    func forceHalfOpen () {
        self.breakerState = State.HALFOPEN
    }
    
    private func startTimer(delay: DispatchTimeInterval) {
        let queue = DispatchQueue(label: "Circuit Breaker", attributes: .concurrent)
        
        // Cancel previous timer if any
        timer?.cancel()
        
        timer = DispatchSource.makeTimerSource(queue: queue)
        
        timer?.scheduleOneshot(deadline: .now(), leeway: delay)
        
        timer?.setEventHandler { [weak self] in
            self?.forceHalfOpen()
        }
        
        timer?.resume()
    }
    
    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
}

