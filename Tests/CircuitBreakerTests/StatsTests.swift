import XCTest
import Foundation
import EmitterKit

@testable import CircuitBreaker

class StatsTests: XCTestCase {
    
    var event: Event<Void>!
    var breaker: Stats!

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
            ("testTrackTimeoutsEvent", testTrackTimeoutsEvent),
            ("testTrackSuccessfulResponseEvent", testTrackSuccessfulResponseEvent),
            ("testTrackFailedResponseEvent", testTrackFailedResponseEvent),
            ("testTrackRejectedRequestsEvent", testTrackRejectedRequestsEvent),
            ("testTrackRequestsEvent", testTrackRequestsEvent),
            ("testTrackLatencyEvent", testTrackLatencyEvent),
            ("testAverageResponseTimeEvent", testAverageResponseTimeEvent),
            ("testConcurrentRequestsEvent", testConcurrentRequestsEvent),
            ("testConcurrentRequestsRejectedEvent", testConcurrentRequestsRejectedEvent),
            ("testResetTimeoutEvent", testResetTimeoutEvent),
            ("testResetTotalRequestsEvent", testResetTotalRequestsEvent),
            ("testResetAllAttributesEvent", testResetAllAttributesEvent)
        ]
    }
    
    override func setUp() {
        super.setUp()
        
        event = Event<Void>()
        breaker = Stats(event: event)
    }
    
    // Create Stats, and check that default values are set
    func testDefaultConstructor() {
        
        let expectation1 = expectation(description: "Create Stats, and check that default values are set")

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
        
        breaker.trackTimeouts()

        XCTAssertEqual(breaker.timeouts, 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Increase successful responses count by 1
    func testTrackSuccessfulResponse() {
        
        let expectation1 = expectation(description: "Increase successful responses count by 1")
        
        breaker.trackSuccessfulResponse()
        
        XCTAssertEqual(breaker.successfulResponses, 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Increase failed responses count by 1
    func testTrackFailedResponse() {
        
        let expectation1 = expectation(description: "Increase failed responses count by 1")
        
        breaker.trackFailedResponse()
        
        XCTAssertEqual(breaker.failedResponses, 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Increase rejected request count by 1
    func testTrackRejected() {
        
        let expectation1 = expectation(description: "Increase rejected request count by 1")
        
        breaker.trackRejected()
        
        XCTAssertEqual(breaker.rejectedRequests, 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Increase request count by 1
    func testTrackRequest() {
        
        let expectation1 = expectation(description: "Increase request count by 1")
        
        breaker.trackRequest()
        
        XCTAssertEqual(breaker.totalRequests, 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Add latency value
    func testTrackLatency() {
        
        let expectation1 = expectation(description: "Add latency value")
        
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
        
        XCTAssertEqual(breaker.averageResponseTime(), 0)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Check average response time when latency array has multiple values
    func testAvgResponseTime() {
        
        let expectation1 = expectation(description: "Check average response time when latency array has multiple values")
        
        breaker.latencies = [1, 2, 3, 4, 5]
        
        XCTAssertEqual(breaker.averageResponseTime(), 3)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Calculate total concurrent requests
    func testConcurrentRequests() {
        
        let expectation1 = expectation(description: "Calculate total concurrent requests")
        
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
    
    // Track timeouts via events
    func testTrackTimeoutsEvent() {
        
        let expectation1 = expectation(description: "Track timeouts via events")
        
        event.once {
            self.breaker.trackTimeouts()
        }
        
        event.emit()
        XCTAssertEqual(breaker.timeouts, 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Track successful responses via events
    func testTrackSuccessfulResponseEvent() {
        
        let expectation1 = expectation(description: "Track successful responses via events")
        
        event.once {
            self.breaker.trackSuccessfulResponse()
        }
        
        event.emit()
        XCTAssertEqual(breaker.successfulResponses, 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Track failed responses via events
    func testTrackFailedResponseEvent() {
        
        let expectation1 = expectation(description: "Track failed responses via events")
        
        event.once {
            self.breaker.trackFailedResponse()
        }
        
        event.emit()
        XCTAssertEqual(breaker.failedResponses, 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Track rejected requests via events
    func testTrackRejectedRequestsEvent() {
        
        let expectation1 = expectation(description: "Track rejected requests via events")
        
        event.once {
            self.breaker.trackRejected()
        }
        
        event.emit()
        XCTAssertEqual(breaker.rejectedRequests, 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Track total requests via events
    func testTrackRequestsEvent() {
        
        let expectation1 = expectation(description: "Track total requests via events")
        
        event.once {
            self.breaker.trackRequest()
        }
        
        event.emit()
        XCTAssertEqual(breaker.totalRequests, 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Track total response time via events
    func testTrackLatencyEvent() {
        
        let expectation1 = expectation(description: "Track total response time via events")
        
        event.emit(breaker.trackLatency(latency: 45))
        XCTAssertEqual(breaker.totalLatency(), 45)
        
        event.emit(breaker.trackLatency(latency: 55))
        XCTAssertEqual(breaker.totalLatency(), 100)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Calculate average response time via events
    func testAverageResponseTimeEvent() {
        
        let expectation1 = expectation(description: "Calculate average response time via events")
        
        event.emit(breaker.trackSuccessfulResponse())
        event.emit(breaker.trackLatency(latency: 30))
        
        event.emit(breaker.trackFailedResponse())
        event.emit(breaker.trackLatency(latency: 40))
        
        event.emit(breaker.trackSuccessfulResponse())
        
        event.emit(breaker.trackLatency(latency: 50))
        
        XCTAssertEqual(breaker.averageResponseTime(), 40)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Calculate concurrent requests via events
    func testConcurrentRequestsEvent() {
        
        let expectation1 = expectation(description: "Calculate concurrent requests via events")
        
        event.emit(breaker.trackRequest())
        event.emit(breaker.trackSuccessfulResponse())
        
        event.emit(breaker.trackRequest())
        event.emit(breaker.trackFailedResponse())
        
        event.emit(breaker.trackRequest())
        event.emit(breaker.trackRequest())
        
        XCTAssertEqual(breaker.concurrentRequests(), 2)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Calculate concurrent requests when requests get rejected via events
    func testConcurrentRequestsRejectedEvent() {
        
        let expectation1 = expectation(description: "Calculate concurrent requests when requests get rejected via events")
        
        event.emit(breaker.trackRequest())
        event.emit(breaker.trackSuccessfulResponse())
        
        event.emit(breaker.trackRequest())
        event.emit(breaker.trackFailedResponse())
        
        event.emit(breaker.trackRequest())
        event.emit(breaker.trackRejected())
        event.emit(breaker.trackRequest())
        
        XCTAssertEqual(breaker.concurrentRequests(), 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Reset timeouts to 0 via events
    func testResetTimeoutEvent() {
        
        let expectation1 = expectation(description: "Reset timeouts to 0 via events")
        
        event.emit(breaker.trackTimeouts())
        event.emit(breaker.trackTimeouts())
        
        event.once {
            XCTAssertEqual(self.breaker.timeouts, 3)
            
            self.breaker.reset()
            
            XCTAssertEqual(self.breaker.timeouts, 0)
        }
        
        event.emit(breaker.trackTimeouts())
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Reset total requests to 0 via events
    func testResetTotalRequestsEvent() {
        
        let expectation1 = expectation(description: "Reset total requests to 0 via events")
        
        event.emit(breaker.trackRequest())
        
        event.once {
            XCTAssertEqual(self.breaker.totalRequests, 2)
            
            self.breaker.reset()
            
            XCTAssertEqual(self.breaker.totalRequests, 0)
        }
        
        event.emit(breaker.trackRequest())
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Reset all attributes to 0 via events
    func testResetAllAttributesEvent() {
        
        let expectation1 = expectation(description: "Reset all attributes to 0 via events")
        
        event.emit(breaker.trackRequest())
        event.emit(breaker.trackFailedResponse())
        event.emit(breaker.trackLatency(latency: 30))
        
        event.emit(breaker.trackRequest())
        event.emit(breaker.trackSuccessfulResponse())
        event.emit(breaker.trackLatency(latency: 4))
        
        event.emit(breaker.trackRequest())
        event.emit(breaker.trackTimeouts())
        event.emit(breaker.trackLatency(latency: 100))
        
        event.once {
            XCTAssertEqual(self.breaker.totalRequests, 4)
            XCTAssertEqual(self.breaker.failedResponses, 1)
            XCTAssertEqual(self.breaker.timeouts, 1)
            XCTAssertEqual(self.breaker.successfulResponses, 1)
            
            self.breaker.reset()
            
            XCTAssertEqual(self.breaker.totalRequests, 0)
            XCTAssertEqual(self.breaker.failedResponses, 0)
            XCTAssertEqual(self.breaker.timeouts, 0)
            XCTAssertEqual(self.breaker.successfulResponses, 0)
            XCTAssertEqual(self.breaker.rejectedRequests, 0)
            XCTAssertEqual(self.breaker.totalLatency(), 0)
            XCTAssertEqual(self.breaker.averageResponseTime(), 0)
            XCTAssertEqual(self.breaker.concurrentRequests(), 0)
        }
        
        event.emit(breaker.trackRequest())
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }

}
