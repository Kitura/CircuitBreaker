import Foundation

class Stats {
    
    var timeouts:Int = 0
    var successfulResponses:Int = 0
    var failedResponses:Int = 0
    var totalRequests:Int = 0
    var rejectedRequests:Int = 0
    var latencies:Array<Int> = []
    var breaker:Event<Any> = Event<Any>()
    
    convenience init () {
        let breakerEvents = Event<Any>()
        self.init(event: breakerEvents)
    }
    
    init (event: Event<Any>) {
        // TODO: Implement and how events will be handled
        self.breaker = event
        
        self.timeouts = 0
        self.successfulResponses = 0
        self.failedResponses = 0
        self.totalRequests = 0
        self.rejectedRequests = 0
        self.latencies = []
        
    }
    
    public func initCounters () -> Void {
        self.timeouts = 0
        self.successfulResponses = 0
        self.failedResponses = 0
        self.totalRequests = 0
        self.rejectedRequests = 0
        self.latencies = []
        
    }
    
    public func totalLatency () -> Int {
        return self.latencies.reduce(0, +)
    }
    
    public func trackTimeouts () -> Void {
        self.timeouts += 1
    }
    
    public func trackSuccessfulResponse () -> Void {
        self.successfulResponses += 1
    }
    
    public func trackFailedResponse () {
        self.failedResponses += 1
    }
    
    public func trackRejected () -> Void {
        self.rejectedRequests += 1
    }
    
    public func trackRequest () -> Void {
        self.totalRequests += 1
    }
    
    // TODO: What type is latency ???
    public func trackLatency (latency:Int) -> Void {
        self.latencies.append(latency)
    }
    
    public func averageResponseTime () -> Int {
        if(self.latencies.count == 0) {
            return 0;
        }
    
        return self.totalLatency() / self.latencies.count
    }
    
    public func concurrentRequests () -> Int {
        let totalResponses = self.successfulResponses + self.failedResponses + self.rejectedRequests
    
        return self.totalRequests - totalResponses
    }
    
    public func reset () -> Void {
        self.initCounters();
    }
    
}
