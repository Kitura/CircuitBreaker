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
            ("testFastFail", testFastFail),
//            ("testIncrementFailures", testIncrementFailures),
//            ("testMaxFailures", testMaxFailures),
//            ("testHalfOpenFailure", testHalfOpenFailure),
//            ("testSuccess", testSuccess),
            ("testHalfOpenSuccess", testHalfOpenSuccess),
            ("testFunctionCall", testFunctionCall),
            ("testTimeout", testTimeout)
        ]
    }
    
    func sum(a: Int, b: Int) -> Int {
        return a + b
    }
    
    func callback () {
        print("Hello there.")
    }
    
    func time(a: Int, seconds: Int) -> Int {
        sleep(UInt32(seconds))
        
        return a
    }
    
    func test() -> Void {}

    // Create CircuitBreaker, state should be Closed and no failures
    func testDefaultConstructor() {
        
        let breaker = CircuitBreaker(callback: callback, selector: test)
        
        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.closed)
        
        // Check that the number of failures is zero
        XCTAssertEqual(breaker.numFailures, 0)
        
    }
    
    // Create CircuitBreaker with user options set
    func testConstructor() {
        
        let breaker = CircuitBreaker(timeout: 5.0, resetTimeout: 5, maxFailures: 3, callback: callback, selector: test)
        
        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.closed)
        
        // Check that the number of failures is zero
        XCTAssertEqual(breaker.failures, 0)
        
        // Check that the options are set on the CircuitBreaker
        XCTAssertEqual(breaker.timeout, 5.0)
        XCTAssertEqual(breaker.resetTimeout, 5)
        XCTAssertEqual(breaker.maxFailures, 3)
        
    }
    
    // Create CircuitBreaker with user options set
    func testPartialConstructor() {
        
        let breaker = CircuitBreaker(timeout: 5.0, resetTimeout: 5, callback: callback, selector: test)
        
        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.closed)
        
        // Check that the number of failures is zero
        XCTAssertEqual(breaker.numFailures, 0)
        
        // Check that the options are set on the CircuitBreaker
        XCTAssertEqual(breaker.timeout, 5.0)
        XCTAssertEqual(breaker.resetTimeout, 5)
        XCTAssertEqual(breaker.maxFailures, 5)
        
    }
    
    // Should enter open state
    func testForceOpen() {
        
        let breaker = CircuitBreaker(callback: callback, selector: test)
        
        // Force open
        breaker.forceOpen()
        
        // Check that the state is Open
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.open)
        
    }
    
    // Should enter half open state after reset timeout
    func testHalfOpenResetTimeout() {
        
        let resetTimeout = 10
        
        let breaker = CircuitBreaker(timeout: 10.0, resetTimeout: resetTimeout, maxFailures: 10, callback: callback, selector: test)
        
        // Force open
        breaker.forceOpen()
        
        // TODO: Check timing differences across runs
        // Check that the state is Open
        //XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.open)
        
        sleep(UInt32(resetTimeout + 2))
        
        // Wait for set timeout
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.halfopen)
        
    }
    
    // Should enter open state
    func testFastFail() {
        
        let breaker = CircuitBreaker(callback: callback, selector: test)
        
        breaker.forceOpen()
        breaker.run()
        
        // Check rejected request count
        XCTAssertEqual(breaker.breakerStats.rejectedRequests, 1)
        
    }
    
    // Should reset failures to 0
    func testResetFailures() {
        
        let breaker = CircuitBreaker(callback: callback, selector: test)
        
        // Set failures
        breaker.numFailures = 10
        
        // Check that failures is 10
        XCTAssertEqual(breaker.numFailures, 10)
        
        // Force closed
        breaker.forceClosed()
        
        // Check that failures is now 0
        XCTAssertEqual(breaker.numFailures, 0)
        
    }
    
    // Should increment failures by 1
//    func testIncrementFailures() {
//        
//        let breaker = CircuitBreaker(callback: callback, selector: test)
//        
//        // Check that failures is 0
//        XCTAssertEqual(breaker.numFailures, 0)
//        
//        // Increment failures by 1
//        breaker.handleFailures()
//        
//        // Check that failures is now 1
//        XCTAssertEqual(breaker.numFailures, 1)
//        
//    }
    
    // Should enter open state once maxFailures is reached
//    func testMaxFailures() {
//        
//        let breaker = CircuitBreaker(callback: callback, selector: test)
//        
//        // Check that failures is 0
//        XCTAssertEqual(breaker.numFailures, 0)
//        
//        // Increment failures 5 times
//        breaker.handleFailures()
//        breaker.handleFailures()
//        breaker.handleFailures()
//        breaker.handleFailures()
//        breaker.handleFailures()
//        
//        // Check that failures is now 5 and state is OPEN
//        XCTAssertEqual(breaker.numFailures, 5)
//        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.open)
//        
//    }
    
    // Should enter closed state after success
//    func testHalfOpenFailure() {
//        
//        let breaker = CircuitBreaker(callback: callback, selector: test)
//        
//        breaker.forceHalfOpen()
//        breaker.run()
//        
//        // Check that state is now closed
//        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.open)
//        
//    }
    
    // Should reset failures and state after a success
//    func testSuccess() {
//        
//        let breaker = CircuitBreaker(callback: callback, selector: test)
//        
//        breaker.numFailures = 10
//        
//        // Check that failures equals 10
//        XCTAssertEqual(breaker.numFailures, 10)
//        
//        breaker.handleSuccess()
//        
//        // Check that state is closed and the failures is 0
//        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.closed)
//        XCTAssertEqual(breaker.numFailures, 0)
//        
//    }
    
    // Should enter closed state from halfopen state after a success
    func testHalfOpenSuccess() {
    
        let breaker = CircuitBreaker(callback: callback, selector: test)
    
        breaker.forceHalfOpen()
        breaker.run()
    
        // Check that state is now closed
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.closed)

    }
    
    // Execute method successfully
    func testFunctionCall() {

        var result = 0

        let breaker = CircuitBreaker(callback: callback) {
            result = self.sum(a: 1, b: 2)
        }
        
        breaker.run()
        
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.closed)
        XCTAssertEqual(result, 3)
        
    }
    
    // Print Stats snapshot
    func testStatsSnapshot() {
        
        var result = 0
        
        let breaker = CircuitBreaker(callback: callback) {
            result = self.sum(a: 1, b: 2)
        }
        
        // TODO: Do something more meaningful here
        breaker.run()
        
        breaker.snapshot()
        
        // TODO: Check that state is closed
        XCTAssertEqual(result, 3)
        
    }
    
    // Test timeout
    func testTimeout() {
        
        var result = 0
        
        let breaker = CircuitBreaker(timeout: 5.0, callback: callback) {
            result = self.time(a: 1, seconds: 11)
        }
        
        breaker.run()
        
        // TODO: Still gets the result, is this okay???
        XCTAssertEqual(result, 1)
        
    }
    
    // Test timeout and reset
    func testTimeoutReset() {
        
        var result = 0
        let resetTimeout = 10
        
        let breaker = CircuitBreaker(timeout: 5.0, resetTimeout: resetTimeout, maxFailures: 1, callback: callback) {
            result = self.time(a: 1, seconds: 11)
        }
        
        breaker.run()
        
        sleep(UInt32(resetTimeout + 2))
        
        print(result)
        
        // Wait for set timeout
        XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.halfopen)
        
    }

}
