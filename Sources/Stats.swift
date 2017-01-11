import Foundation

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
        return latencies.reduce(0, +)
    }
    
    func trackTimeouts () -> Void {
        timeouts += 1
    }
    
    func trackSuccessfulResponse () -> Void {
        successfulResponses += 1
    }
    
    func trackFailedResponse () {
        failedResponses += 1
    }
    
    func trackRejected () -> Void {
        rejectedRequests += 1
    }
    
    func trackRequest () -> Void {
        totalRequests += 1
    }
    
    // TODO: What type is latency ???
    func trackLatency (latency:Int) -> Void {
        latencies.append(latency)
    }
    
    func averageResponseTime () -> Int {
        if(latencies.count == 0) {
            return 0
        }
    
        return totalLatency() / latencies.count
    }
    
    func concurrentRequests () -> Int {
        let totalResponses = successfulResponses + failedResponses + rejectedRequests
    
        return totalRequests - totalResponses
    }
    
    func reset () -> Void {
        initCounters()
    }
    
    // Log current snapshot of CircuitBreaker
    // TODO: What format should this be in?
    func snapshot () {
        print("\n")
        print("**************************************")
        print(Date())
        print("Total Requests: \(totalRequests)")
        print("Concurrent Requests: \(concurrentRequests())")
        print("Rejected Requests: \(rejectedRequests)")
        print("Successful Responses: \(successfulResponses)")
        print("Average Response Time: \(averageResponseTime())")
        print("Failed Responses: \(failedResponses)")
        print("Total Timeouts: \(timeouts)")
        print("Total Latency: \(totalLatency())")
        print("**************************************")
        print("\n")

    }
    
}
