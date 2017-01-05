import Foundation

// TODO: Update this class to not use EmitterKit

public class Stats {
    
    var timeouts:Int = 0
    var successfulResponses:Int = 0
    var failedResponses:Int = 0
    var totalRequests:Int = 0
    var rejectedRequests:Int = 0
    var latencies:Array<Int> = []
    
    init () {
        // Set defaults
        self.timeouts = 0
        self.successfulResponses = 0
        self.failedResponses = 0
        self.totalRequests = 0
        self.rejectedRequests = 0
        self.latencies = []
        
    }
    
    func initCounters () -> Void {
        self.timeouts = 0
        self.successfulResponses = 0
        self.failedResponses = 0
        self.totalRequests = 0
        self.rejectedRequests = 0
        self.latencies = []
        
    }
    
    func totalLatency () -> Int {
        return self.latencies.reduce(0, +)
    }
    
    func trackTimeouts () -> Void {
        self.timeouts += 1
    }
    
    func trackSuccessfulResponse () -> Void {
        self.successfulResponses += 1
    }
    
    func trackFailedResponse () {
        self.failedResponses += 1
    }
    
    func trackRejected () -> Void {
        self.rejectedRequests += 1
    }
    
    func trackRequest () -> Void {
        self.totalRequests += 1
    }
    
    // TODO: What type is latency ???
    func trackLatency (latency:Int) -> Void {
        self.latencies.append(latency)
    }
    
    func averageResponseTime () -> Int {
        if(self.latencies.count == 0) {
            return 0;
        }
    
        return self.totalLatency() / self.latencies.count
    }
    
    func concurrentRequests () -> Int {
        let totalResponses = self.successfulResponses + self.failedResponses + self.rejectedRequests
    
        return self.totalRequests - totalResponses
    }
    
    func reset () -> Void {
        self.initCounters();
    }
    
    // Log current snapshot of CircuitBreaker
    func snapshot () {
        print("Total Requests: \(self.totalRequests)")
        print("Concurrent Requests: \(concurrentRequests())")
        print("Rejected Requests: \(self.rejectedRequests)")
        print("Successful Responses: \(self.successfulResponses)")
        print("Average Response Time: \(averageResponseTime())")
        print("Failed Responses: \(self.failedResponses)")
        print("Total Timeouts: \(self.timeouts)")
        print("Total Latency: \(self.totalLatency())")

    }
    
}
