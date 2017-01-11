import Foundation

public class CircuitBreaker {
    
    public enum State {
        case open
        case halfopen
        case closed
    }
    
    private(set) var state: State
    private(set) var failures: Int
    var breakerStats: Stats!
    var function: () -> Void
    var callback: () -> Void
    
    let timeout: Double
    let resetTimeout: Int
    let maxFailures: Int
    var pendingHalfOpen: Bool
    
    var resetTimer: DispatchSourceTimer?
    let dispatchSemaphoreState = DispatchSemaphore(value: 1)
    let dispatchSemaphoreFailure = DispatchSemaphore(value: 1)
    
    // TODO: Look at using the built in queue (DispatchQueue.main doesn't work)
    let queue = DispatchQueue(label: "Circuit Breaker Queue", attributes: .concurrent)
    
    init (timeout: Double = 10, resetTimeout: Int = 60, maxFailures: Int = 5, callback: @escaping () -> Void, selector: @escaping () -> Void) {
        self.timeout = timeout
        self.resetTimeout = resetTimeout
        self.maxFailures = maxFailures
    
        self.state = State.closed
        self.failures = 0
        self.pendingHalfOpen = false
        self.breakerStats = Stats()
        
        self.callback = callback
        self.function = selector
    }
    
    // Run
    func run () {
        breakerStats.trackRequest()
        
        if state == State.open || (state == State.halfopen && pendingHalfOpen == true) {
            return self.fastFail()
        } else if state == State.halfopen && pendingHalfOpen == false {
            self.pendingHalfOpen = true
            return callFunction()
        } else {
            return callFunction()
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
                    handleSuccess()
                } else {
                    handleFailures()
                }
                
                return callback()
            }
        }
        
        let startTime:Date = Date()
        
        breakerStats.trackLatency(latency: Int(Date().timeIntervalSince(startTime)))
        
        setTimeout(delay: self.timeout) {
            complete(error: true)
            return
        }
        
        function()
        complete(error: false)
        return
    }
    
    func setTimeout(delay: Double, closure: @escaping () -> ()) {
        queue.asyncAfter(deadline: .now() + delay) {
            self.breakerStats.trackTimeouts()
            closure()
        }
    }
    
    // Print Current Stats Snapshot
    func snapshot () {
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
    
    func handleFailures () {
        numFailures += 1
        
        if ((failures == maxFailures) || (state == State.halfopen)) {
            forceOpen()
        }
        
        breakerStats.trackFailedResponse()
    }
    
    func handleSuccess () {
        forceClosed()
        
        breakerStats.trackSuccessfulResponse()
    }
    
    func forceOpen () {
        breakerState = State.open
        
        startResetTimer(delay: .seconds(resetTimeout))
    }
    
    func forceClosed () {
        breakerState = State.closed
        numFailures = 0
        pendingHalfOpen = false
    }
    
    func forceHalfOpen () {
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
    
    private func stopResetTimer() {
        resetTimer?.cancel()
        resetTimer = nil
    }
    
}

