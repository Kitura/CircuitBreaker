import XCTest
import Foundation

@testable import CircuitBreaker

class StatsTests: XCTestCase {

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
            ("testReset", testReset)
        ]
    }
    
    // Create Stats, and check that default values are set
    func testDefaultConstructor() {
        
        let expectation1 = expectation(description: "Create Stats, and check that default values are set")
        
        let event = Event<Any>()
        let breaker = Stats(event: event)

        XCTAssertEqual(breaker.timeouts, 0)
        XCTAssertEqual(breaker.successfulResponses, 0)
        XCTAssertEqual(breaker.failedResponses, 0)
        XCTAssertEqual(breaker.totalRequests, 0)
        XCTAssertEqual(breaker.rejectedRequests, 0)
        XCTAssertEqual(breaker.latencies.count, 0)
        
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Calculate total latency
    func testTotalLatency() {
        
        let expectation1 = expectation(description: "Calculate total latency")
        
        let event = Event<Any>()
        let breaker = Stats(event: event)
        
        breaker.latencies = [1, 2, 3, 4, 5]
        
        let latency = breaker.totalLatency()

        XCTAssertEqual(latency, 15)
        
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Increase timeout count by 1
    func testTrackTimeouts() {
        
        let expectation1 = expectation(description: "Increase timeout count by 1")
        
        let event = Event<Any>()
        let breaker = Stats(event: event)

        
        breaker.trackTimeouts()

        XCTAssertEqual(breaker.timeouts, 1)
        
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Increase successful responses count by 1
    func testTrackSuccessfulResponse() {
        
        let expectation1 = expectation(description: "Increase successful responses count by 1")
        
        let event = Event<Any>()
        let breaker = Stats(event: event)
        
        
        breaker.trackSuccessfulResponse()
        
        XCTAssertEqual(breaker.successfulResponses, 1)
        
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Increase failed responses count by 1
    func testTrackFailedResponse() {
        
        let expectation1 = expectation(description: "Increase failed responses count by 1")
        
        let event = Event<Any>()
        let breaker = Stats(event: event)
        
        
        breaker.trackFailedResponse()
        
        XCTAssertEqual(breaker.failedResponses, 1)
        
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Increase rejected request count by 1
    func testTrackRejected() {
        
        let expectation1 = expectation(description: "Increase rejected request count by 1")
        
        let event = Event<Any>()
        let breaker = Stats(event: event)
        
        
        breaker.trackRejected()
        
        XCTAssertEqual(breaker.rejectedRequests, 1)
        
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Increase request count by 1
    func testTrackRequest() {
        
        let expectation1 = expectation(description: "Increase request count by 1")
        
        let event = Event<Any>()
        let breaker = Stats(event: event)
        
        
        breaker.trackRequest()
        
        XCTAssertEqual(breaker.totalRequests, 1)
        
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Add latency value
    func testTrackLatency() {
        
        let expectation1 = expectation(description: "Add latency value")
        
        let event = Event<Any>()
        let breaker = Stats(event: event)
        
        
        breaker.trackLatency(latency: 10)
        
        XCTAssertEqual(breaker.latencies.count, 1)
        XCTAssertEqual(breaker.latencies[0], 10)
        
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Check average response time when latency array is empty
    func testAvgResponseTimeInitial() {
        
        let expectation1 = expectation(description: "Check average response time when latency array is empty")
        
        let event = Event<Any>()
        let breaker = Stats(event: event)
        
        XCTAssertEqual(breaker.averageResponseTime(), 0)
        
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Check average response time when latency array has multiple values
    func testAvgResponseTime() {
        
        let expectation1 = expectation(description: "Check average response time when latency array has multiple values")
        
        let event = Event<Any>()
        let breaker = Stats(event: event)
        
        breaker.latencies = [1, 2, 3, 4, 5]
        
        XCTAssertEqual(breaker.averageResponseTime(), 3)
        
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Calculate total concurrent requests
    func testConcurrentRequests() {
        
        let expectation1 = expectation(description: "Calculate total concurrent requests")
        
        let event = Event<Any>()
        let breaker = Stats(event: event)
        
        breaker.totalRequests = 8
        breaker.successfulResponses = 1
        breaker.failedResponses = 2
        breaker.rejectedRequests = 3
        
        XCTAssertEqual(breaker.concurrentRequests(), 2)
        
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Reset all values
    func testReset() {
        
        let expectation1 = expectation(description: "Reset all values")
        
        let event = Event<Any>()
        let breaker = Stats(event: event)
        
        breaker.timeouts = 2
        breaker.successfulResponses = 1
        breaker.failedResponses = 2
        breaker.totalRequests = 8
        breaker.rejectedRequests = 3
        breaker.latencies = [1, 2, 3]
        
        breaker.reset()
        
        XCTAssertEqual(breaker.timeouts, 0)
        XCTAssertEqual(breaker.successfulResponses, 0)
        XCTAssertEqual(breaker.failedResponses, 0)
        XCTAssertEqual(breaker.totalRequests, 0)
        XCTAssertEqual(breaker.rejectedRequests, 0)
        XCTAssertEqual(breaker.latencies.count, 0)
        
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }

}
