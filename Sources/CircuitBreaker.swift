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
    
    // Test helper functions
    var breakerState: State {
        
        get {
            return self.state
        }
        
        set {
            self.state = newValue
        }
    }
    
    var numFailures: Int {
        
        get {
            return self.failures
        }
        
        set {
            self.failures = newValue
        }
        
    }
    
    func handleFailures () {
        self.failures += 1
        
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
        self.state = State.OPEN
        
        // TODO: Test timer is working here
        //self.startTimer(delay: .seconds(Int(self.resetTimeout)))
    }
    
    func forceClosed () {
        self.state = State.CLOSED
        self.failures = 0
        self.pendingHalfOpen = false
    }
    
    func forceHalfOpen () {
        self.state = State.HALFOPEN
    }
    
    // Helper method used for testing only
    func updateState () {
        self.startTimer(delay: .seconds(Int(self.resetTimeout)))
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

