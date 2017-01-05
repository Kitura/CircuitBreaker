import XCTest
import Foundation

@testable import CircuitBreaker

class StatsTests: XCTestCase {
    
    var stats: Stats!

    static var allTests: [(String, (StatsTests) -> () throws -> Void)] {
        return [
            ("testDefaultConstructor", testDefaultConstructor),
            ("testTotalLatency", testTotalLatency),
            ("testTrackTimeouts", testTrackTimeouts),
            ("testTrackSuccessfulResponse", testTrackSuccessfulResponse),
            ("testTrackFailedResponse", testTrackFailedResponse),
            ("testTrackRejected", testTrackRejected),
            ("testTrackRequest", testTrackRequest),
            ("testTrackLatency", testTrackLatency),
            ("testAvgResponseTimeInitial", testAvgResponseTimeInitial),
            ("testAvgResponseTime", testAvgResponseTime),
            ("testConcurrentRequests", testConcurrentRequests),
            ("testReset", testReset),
            ("testSnapshot", testSnapshot)
        ]
    }
    
    override func setUp() {
        super.setUp()
        
        stats = Stats()
    }
    
    // Create Stats, and check that default values are set
    func testDefaultConstructor() {
        
        let expectation1 = expectation(description: "Create Stats, and check that default values are set")

        XCTAssertEqual(stats.timeouts, 0)
        XCTAssertEqual(stats.successfulResponses, 0)
        XCTAssertEqual(stats.failedResponses, 0)
        XCTAssertEqual(stats.totalRequests, 0)
        XCTAssertEqual(stats.rejectedRequests, 0)
        XCTAssertEqual(stats.latencies.count, 0)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }

    // Calculate total latency
    func testTotalLatency() {
        
        let expectation1 = expectation(description: "Calculate total latency")
        
        stats.latencies = [1, 2, 3, 4, 5]
        
        let latency = stats.totalLatency()

        XCTAssertEqual(latency, 15)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Increase timeout count by 1
    func testTrackTimeouts() {
        
        let expectation1 = expectation(description: "Increase timeout count by 1")
        
        stats.trackTimeouts()

        XCTAssertEqual(stats.timeouts, 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Increase successful responses count by 1
    func testTrackSuccessfulResponse() {
        
        let expectation1 = expectation(description: "Increase successful responses count by 1")
        
        stats.trackSuccessfulResponse()
        
        XCTAssertEqual(stats.successfulResponses, 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Increase failed responses count by 1
    func testTrackFailedResponse() {
        
        let expectation1 = expectation(description: "Increase failed responses count by 1")
        
        stats.trackFailedResponse()
        
        XCTAssertEqual(stats.failedResponses, 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Increase rejected request count by 1
    func testTrackRejected() {
        
        let expectation1 = expectation(description: "Increase rejected request count by 1")
        
        stats.trackRejected()
        
        XCTAssertEqual(stats.rejectedRequests, 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Increase request count by 1
    func testTrackRequest() {
        
        let expectation1 = expectation(description: "Increase request count by 1")
        
        stats.trackRequest()
        
        XCTAssertEqual(stats.totalRequests, 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Add latency value
    func testTrackLatency() {
        
        let expectation1 = expectation(description: "Add latency value")
        
        stats.trackLatency(latency: 10)
        
        XCTAssertEqual(stats.latencies.count, 1)
        XCTAssertEqual(stats.latencies[0], 10)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Check average response time when latency array is empty
    func testAvgResponseTimeInitial() {
        
        let expectation1 = expectation(description: "Check average response time when latency array is empty")
        
        XCTAssertEqual(stats.averageResponseTime(), 0)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Check average response time when latency array has multiple values
    func testAvgResponseTime() {
        
        let expectation1 = expectation(description: "Check average response time when latency array has multiple values")
        
        stats.latencies = [1, 2, 3, 4, 5]
        
        XCTAssertEqual(stats.averageResponseTime(), 3)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Calculate total concurrent requests
    func testConcurrentRequests() {
        
        let expectation1 = expectation(description: "Calculate total concurrent requests")
        
        stats.totalRequests = 8
        stats.successfulResponses = 1
        stats.failedResponses = 2
        stats.rejectedRequests = 3
        
        XCTAssertEqual(stats.concurrentRequests(), 2)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Reset all values
    func testReset() {
        
        let expectation1 = expectation(description: "Reset all values")
        
        stats.timeouts = 2
        stats.successfulResponses = 1
        stats.failedResponses = 2
        stats.totalRequests = 8
        stats.rejectedRequests = 3
        stats.latencies = [1, 2, 3]
        
        stats.reset()
        
        XCTAssertEqual(stats.timeouts, 0)
        XCTAssertEqual(stats.successfulResponses, 0)
        XCTAssertEqual(stats.failedResponses, 0)
        XCTAssertEqual(stats.totalRequests, 0)
        XCTAssertEqual(stats.rejectedRequests, 0)
        XCTAssertEqual(stats.latencies.count, 0)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Print out current snapshot of CircuitBreaker Stats
    func testSnapshot() {
        
        let expectation1 = expectation(description: "Print out current snapshot of CircuitBreaker Stats")
        
        stats.trackRequest()
        stats.trackFailedResponse()
        stats.trackLatency(latency: 30)
        
        stats.trackRequest()
        stats.trackSuccessfulResponse()
        stats.trackLatency(latency: 4)
        
        stats.trackRequest()
        stats.trackTimeouts()
        stats.trackLatency(latency: 100)
        
        stats.snapshot()
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }

}
