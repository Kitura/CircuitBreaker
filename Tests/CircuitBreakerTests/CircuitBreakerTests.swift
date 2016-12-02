import XCTest
import Foundation

@testable import CircuitBreaker

class CircuitBreakerTests: XCTestCase {
    
    static var allTests: [(String, (CircuitBreakerTests) -> () throws -> Void)] {
        return [
            ("testDefaultConstructor", testDefaultConstructor),
            ("testConstructor", testConstructor),
            ("testPartialConstructor", testPartialConstructor),
            ("testForceOpen", testForceOpen),
            ("testHalfOpenResetTimeout", testHalfOpenResetTimeout),
            ("testResetFailures", testResetFailures),
            ("testIncrementFailures", testIncrementFailures),
            ("testMaxFailures", testMaxFailures),
            ("testHalfOpenFailure", testHalfOpenFailure),
            ("testSuccess", testSuccess),
            ("testHalfOpenSuccess", testHalfOpenSuccess)
        ]
    }
    
    // Create CircuitBreaker, state should be Closed and no failures
    func testDefaultConstructor() {
        
        let expectation1 = expectation(description: "Create CircuitBreaker, state should be Closed and no failures")
        
        let breaker = CircuitBreaker()
        
        // Check that the state is Closed
        XCTAssertEqual(breaker.getState(), State.CLOSED)
        
        // Check that the number of failures is zero
        XCTAssertEqual(breaker.getNumFailures(), 0)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Create CircuitBreaker with user options set
    func testConstructor() {
        
        let expectation1 = expectation(description: "Create CircuitBreaker with user options set")
        
        let breaker = CircuitBreaker(opts: ["timeout": 5.0, "resetTimeout": 5.0, "maxFailures": 3.0])
        
        // Check that the state is Closed
        XCTAssertEqual(breaker.getState(), State.CLOSED)
        
        // Check that the number of failures is zero
        XCTAssertEqual(breaker.getNumFailures(), 0)
        
        // Check that the options are set on the CircuitBreaker
        XCTAssertEqual(breaker.timeout, 5.0)
        XCTAssertEqual(breaker.resetTimeout, 5.0)
        XCTAssertEqual(breaker.maxFailures, 3.0)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Create CircuitBreaker with user options set
    func testPartialConstructor() {
        
        let expectation1 = expectation(description: "Create CircuitBreaker with some user options set")
        
        let breaker = CircuitBreaker(opts: ["timeout": 5.0, "resetTimeout": 5.0])
        
        // Check that the state is Closed
        XCTAssertEqual(breaker.getState(), State.CLOSED)
        
        // Check that the number of failures is zero
        XCTAssertEqual(breaker.getNumFailures(), 0)
        
        // Check that the options are set on the CircuitBreaker
        XCTAssertEqual(breaker.timeout, 5.0)
        XCTAssertEqual(breaker.resetTimeout, 5.0)
        XCTAssertEqual(breaker.maxFailures, 5.0)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Should enter open state
    func testForceOpen() {
        
        let expectation1 = expectation(description: "Should enter open state")
        
        let breaker = CircuitBreaker()
        
        // Force open
        breaker.forceOpen()
        
        // Check that the state is Open
        XCTAssertEqual(breaker.getState(), State.OPEN)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Should enter half open state after reset timeout
    func testHalfOpenResetTimeout() {
        let expectation1 = expectation(description: "Should enter half open state after reset timeout")
        
        let breaker = CircuitBreaker(opts: ["timeout": 10.0, "resetTimeout": 10.0, "maxFailures": 10.0])
        
        // Force open
        breaker.forceOpen()
        breaker.setTimeout(delay: breaker.resetTimeout)
        
        var time:Date = Date()
        
        let elapsedTime = time.addingTimeInterval(0.2 * 60.0)
        
        // Wait 11 seconds
        while time < elapsedTime {
            time = Date()
        }
        
        // Wait for set timeout
        XCTAssertEqual(breaker.getState(), State.HALFOPEN)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 15, handler: { _ in  })
        
    }
    
    // Should reset failures to 0
    func testResetFailures() {
        let expectation1 = expectation(description: "Should reset failures to 0")
        
        let breaker = CircuitBreaker()
        
        // Set failures
        breaker.setNumFailures(count: 10)
        
        // Check that failures is 10
        XCTAssertEqual(breaker.getNumFailures(), 10)
        
        // Force closed
        breaker.forceClosed()
        
        // Check that failures is now 0
        XCTAssertEqual(breaker.getNumFailures(), 0)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Should incrememnt failures by 1
    func testIncrementFailures() {
        let expectation1 = expectation(description: "Should incrememnt failures by 1")
        
        let breaker = CircuitBreaker()
        
        // Check that failures is 0
        XCTAssertEqual(breaker.getNumFailures(), 0)
        
        // Increment failures by 1
        breaker.handleFailures()
        
        // Check that failures is now 1
        XCTAssertEqual(breaker.getNumFailures(), 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Should enter open state once maxFailures is reached
    func testMaxFailures() {
        let expectation1 = expectation(description: "Should enter open state once maxFailures is reached")
        
        let breaker = CircuitBreaker()
        
        // Check that failures is 0
        XCTAssertEqual(breaker.getNumFailures(), 0)
        
        // Increment failures 5 times
        breaker.handleFailures()
        breaker.handleFailures()
        breaker.handleFailures()
        breaker.handleFailures()
        breaker.handleFailures()
        
        // Check that failures is now 5 and state is OPEN
        XCTAssertEqual(breaker.getNumFailures(), 5)
        XCTAssertEqual(breaker.getState(), State.OPEN)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Should enter open state after failure while in halfopen state
    func testHalfOpenFailure() {
        let expectation1 = expectation(description: "Should enter open state after failure while in halfopen state")
        
        let breaker = CircuitBreaker()
        
        breaker.forceHalfOpen()
        
        // Increment failures 1 time
        breaker.handleFailures()
        
        // Check that state is now open
        XCTAssertEqual(breaker.getState(), State.OPEN)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Should reset failures and state after a success
    func testSuccess() {
        let expectation1 = expectation(description: "Should reset failures and state after a success")
        
        let breaker = CircuitBreaker()
        
        breaker.setNumFailures(count: 10)
        
        // Check that failures equals 10
        XCTAssertEqual(breaker.getNumFailures(), 10)
        
        breaker.handleSuccess()
        
        // Check that state is closed and the failures is 0
        XCTAssertEqual(breaker.getState(), State.CLOSED)
        XCTAssertEqual(breaker.getNumFailures(), 0)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Should enter closed state from halfopen state after a success
    func testHalfOpenSuccess() {
        let expectation1 = expectation(description: "Should enter closed state from halfopen state after a success")
        
        let breaker = CircuitBreaker()
        
        breaker.forceHalfOpen()
        
        breaker.handleSuccess()
        
        // Check that state is closed
        XCTAssertEqual(breaker.getState(), State.CLOSED)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }

}
