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
            ("testHalfOpenSuccess", testHalfOpenSuccess),
            ("testFunctionCall", testFunctionCall)
        ]
    }
    
    func sum(a: Int, b: Int) -> Int {
        print(a + b)
        return a + b
    }
    
    func test(a: Any, b: Any) -> Any {
        let c: Any = 3
        return c
    }

    // Create CircuitBreaker, state should be Closed and no failures
    func testDefaultConstructor() {
        
        let expectation1 = expectation(description: "Create CircuitBreaker, state should be Closed and no failures")
        
        let breaker = CircuitBreaker(selector: test)
        
        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.CLOSED)
        
        // Check that the number of failures is zero
        XCTAssertEqual(breaker.numFailures, 0)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Create CircuitBreaker with user options set
    func testConstructor() {
        
        let expectation1 = expectation(description: "Create CircuitBreaker with user options set")
        
        let breaker = CircuitBreaker(timeout: 5.0, resetTimeout: 5.0, maxFailures: 3, selector: test)
        
        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.CLOSED)
        
        // Check that the number of failures is zero
        XCTAssertEqual(breaker.failures, 0)
        
        // Check that the options are set on the CircuitBreaker
        XCTAssertEqual(breaker.timeout, 5.0)
        XCTAssertEqual(breaker.resetTimeout, 5.0)
        XCTAssertEqual(breaker.maxFailures, 3)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Create CircuitBreaker with user options set
    func testPartialConstructor() {
        
        let expectation1 = expectation(description: "Create CircuitBreaker with some user options set")
        
        let breaker = CircuitBreaker(timeout: 5.0, resetTimeout: 5.0, selector: test)
        
        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.CLOSED)
        
        // Check that the number of failures is zero
        XCTAssertEqual(breaker.numFailures, 0)
        
        // Check that the options are set on the CircuitBreaker
        XCTAssertEqual(breaker.timeout, 5.0)
        XCTAssertEqual(breaker.resetTimeout, 5.0)
        XCTAssertEqual(breaker.maxFailures, 5)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Should enter open state
    func testForceOpen() {
        
        let expectation1 = expectation(description: "Should enter open state")
        
        let breaker = CircuitBreaker(selector: test)
        
        // Force open
        breaker.forceOpen()
        
        // Check that the state is Open
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.OPEN)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Should enter half open state after reset timeout
    func testHalfOpenResetTimeout() {
        let expectation1 = expectation(description: "Should enter half open state after reset timeout")
        
        let breaker = CircuitBreaker(timeout: 10.0, resetTimeout: 10.0, maxFailures: 10, selector: test)
        
        // Force open
        breaker.forceOpen()
        breaker.updateState()
        
        var time:Date = Date()
        
        let elapsedTime = time.addingTimeInterval(0.2 * 60.0)
        
        // Wait 11 seconds
        while time < elapsedTime {
            time = Date()
        }
        
        // Wait for set timeout
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.HALFOPEN)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 15, handler: { _ in  })
        
    }
    
    // Should reset failures to 0
    func testResetFailures() {
        let expectation1 = expectation(description: "Should reset failures to 0")
        
        let breaker = CircuitBreaker(selector: test)
        
        // Set failures
        breaker.numFailures = 10
        
        // Check that failures is 10
        XCTAssertEqual(breaker.numFailures, 10)
        
        // Force closed
        breaker.forceClosed()
        
        // Check that failures is now 0
        XCTAssertEqual(breaker.numFailures, 0)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Should increment failures by 1
    func testIncrementFailures() {
        let expectation1 = expectation(description: "Should incrememnt failures by 1")
        
        let breaker = CircuitBreaker(selector: test)
        
        // Check that failures is 0
        XCTAssertEqual(breaker.numFailures, 0)
        
        // Increment failures by 1
        breaker.handleFailures()
        
        // Check that failures is now 1
        XCTAssertEqual(breaker.numFailures, 1)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Should enter open state once maxFailures is reached
    func testMaxFailures() {
        let expectation1 = expectation(description: "Should enter open state once maxFailures is reached")
        
        let breaker = CircuitBreaker(selector: test)
        
        // Check that failures is 0
        XCTAssertEqual(breaker.numFailures, 0)
        
        // Increment failures 5 times
        breaker.handleFailures()
        breaker.handleFailures()
        breaker.handleFailures()
        breaker.handleFailures()
        breaker.handleFailures()
        
        // Check that failures is now 5 and state is OPEN
        XCTAssertEqual(breaker.numFailures, 5)
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.OPEN)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Should enter open state after failure while in halfopen state
    func testHalfOpenFailure() {
        let expectation1 = expectation(description: "Should enter open state after failure while in halfopen state")
        
        let breaker = CircuitBreaker(selector: test)
        
        breaker.forceHalfOpen()
        
        // Increment failures 1 time
        breaker.handleFailures()
        
        // Check that state is now open
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.OPEN)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Should reset failures and state after a success
    func testSuccess() {
        let expectation1 = expectation(description: "Should reset failures and state after a success")
        
        let breaker = CircuitBreaker(selector: test)
        
        breaker.numFailures = 10
        
        // Check that failures equals 10
        XCTAssertEqual(breaker.numFailures, 10)
        
        breaker.handleSuccess()
        
        // Check that state is closed and the failures is 0
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.CLOSED)
        XCTAssertEqual(breaker.numFailures, 0)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Should enter closed state from halfopen state after a success
    func testHalfOpenSuccess() {
        let expectation1 = expectation(description: "Should enter closed state from halfopen state after a success")
        
        let breaker = CircuitBreaker(selector: test)
        
        breaker.forceHalfOpen()
        
        breaker.handleSuccess()
        
        // Check that state is closed
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.CLOSED)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }
    
    // Execute method successfully
    func testFunctionCall() {
        let expectation1 = expectation(description: "Execute method successfully")

        let breaker = CircuitBreaker(selector: test)
        
        let result = breaker.runFunc(f: sum, args: [1, 2])
        
        // Check that state is closed
        XCTAssertEqual(result, 3)
        
        expectation1.fulfill()
        print("Done")
        
        waitForExpectations(timeout: 10, handler: { _ in  })
        
    }

}
