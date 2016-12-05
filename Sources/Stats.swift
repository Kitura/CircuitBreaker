import Foundation
import EmitterKit

class Stats {
    
    var timeouts:Int = 0
    var successfulResponses:Int = 0
    var failedResponses:Int = 0
    var totalRequests:Int = 0
    var rejectedRequests:Int = 0
    var latencies:Array<Int> = []
    var breaker:Event = Event<Void>()
    var listeners = [Listener]()
    
    convenience init () {
        let breakerEvents = Event<Void>()
        self.init(event: breakerEvents)
    }
    
    init (event: Event<Void>) {
        // TODO: Implement and how events will be handled
        self.breaker = event
        
        // Set defaults
        self.timeouts = 0
        self.successfulResponses = 0
        self.failedResponses = 0
        self.totalRequests = 0
        self.rejectedRequests = 0
        self.latencies = []
        
        self.listeners += event.on(self.totalRequests as AnyObject) {_ in
            self.trackRequest()
        }
        
        self.listeners += event.on(self.timeouts as AnyObject) {_ in
            self.trackTimeouts()
        }
        
        self.listeners += event.on(self.successfulResponses as AnyObject) {_ in
            self.trackSuccessfulResponse()
        }
        
        self.listeners += event.on(self.failedResponses as AnyObject) {_ in
            self.trackFailedResponse()
        }
        
        self.listeners += event.on(self.rejectedRequests as AnyObject) {_ in
            self.trackRejected()
        }
        
        self.listeners += event.on(self.totalLatency() as AnyObject) {_ in
            self.trackLatency(latency: 0)
        }
        
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
