import XCTest
import Foundation
import HeliumLogger
import LoggerAPI

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
            ("testHalfOpenSuccess", testHalfOpenSuccess),
            ("testFunctionCall", testFunctionCall),
            ("testStatsSnapshot", testStatsSnapshot),
            ("testTimeout", testTimeout),
            ("testTimeoutReset", testTimeoutReset),
            ("testInvocationWrapper", testInvocationWrapper)
        ]
    }
    
    override func setUp() {
        super.setUp()
        
        HeliumLogger.use(LoggerMessageType.debug)
    }

    func sum(a: Int, b: Int) -> Int {
        return a + b
    }
    
    func sumWrapper(invocation: Invocation<(Int, Int), Int>) -> Int {
        let result = sum(a: invocation.args.0, b: invocation.args.1)
        if result != 7 {
            invocation.notifyFailure()
            return 0
        } else {
            invocation.notifySuccess()
            return result
        }
    }

    var timedOut = false

    func callback (error: BreakerError) -> Void {
        switch error {
        case BreakerError.timeout:
            timedOut = true
            Log.debug("Timeout")
        case BreakerError.fastFail:
            Log.debug("Circuit open")
        }
    }

    func time(a: Int, seconds: Int) -> Int {
        sleep(UInt32(seconds))

        return a
    }

    func test(a: Any) -> () {}

    // Create CircuitBreaker, state should be Closed and no failures
    func testDefaultConstructor() {

        let breaker = CircuitBreaker(fallback: callback, command: test)

        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, State.closed)

        // Check that the number of failures is zero
        XCTAssertEqual(breaker.numFailures, 0)

    }

    // Create CircuitBreaker with user options set
    func testConstructor() {

        let breaker = CircuitBreaker(timeout: 5.0, resetTimeout: 5, maxFailures: 3, fallback: callback, command: test)

        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, State.closed)

        // Check that the number of failures is zero
        XCTAssertEqual(breaker.failures, 0)

        // Check that the options are set on the CircuitBreaker
        XCTAssertEqual(breaker.timeout, 5.0)
        XCTAssertEqual(breaker.resetTimeout, 5)
        XCTAssertEqual(breaker.maxFailures, 3)

    }

    // Create CircuitBreaker with user options set
    func testPartialConstructor() {

        let breaker = CircuitBreaker(timeout: 5.0, resetTimeout: 5, fallback: callback, command: test)

        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, State.closed)

        // Check that the number of failures is zero
        XCTAssertEqual(breaker.numFailures, 0)

        // Check that the options are set on the CircuitBreaker
        XCTAssertEqual(breaker.timeout, 5.0)
        XCTAssertEqual(breaker.resetTimeout, 5)
        XCTAssertEqual(breaker.maxFailures, 5)

    }

    // Should enter open state
    func testForceOpen() {

        let breaker = CircuitBreaker(fallback: callback, command: test)

        // Force open
        breaker.forceOpen()

        // Check that the state is Open
        XCTAssertEqual(breaker.breakerState, State.open)

    }

    // Should enter half open state after reset timeout
    func testHalfOpenResetTimeout() {

        let resetTimeout = 10

        let breaker = CircuitBreaker(timeout: 10.0, resetTimeout: resetTimeout, maxFailures: 10, fallback: callback, command: test)

        // Force open
        breaker.forceOpen()

        // TODO: Check timing differences across runs
        // Check that the state is Open
        //XCTAssertEqual(breaker.breakerState, CircuitBreaker.State.open)

        sleep(UInt32(resetTimeout + 2))

        // Wait for set timeout
        XCTAssertEqual(breaker.breakerState, State.halfopen)

    }

    // Should enter open state
    func testFastFail() {

        let breaker = CircuitBreaker(fallback: callback, command: test)

        breaker.forceOpen()
        breaker.run(args: ())

        // Sometimes the Travis timing throws this off
        sleep(3)

        // Check rejected request count
        XCTAssertEqual(breaker.breakerStats.rejectedRequests, 1)

    }

    // Should reset failures to 0
    func testResetFailures() {

        let breaker = CircuitBreaker(fallback: callback, command: test)

        // Set failures
        breaker.numFailures = 10

        // Check that failures is 10
        XCTAssertEqual(breaker.numFailures, 10)

        // Force closed
        breaker.forceClosed()

        // Check that failures is now 0
        XCTAssertEqual(breaker.numFailures, 0)

    }

    // Should enter closed state from halfopen state after a success
    func testHalfOpenSuccess() {

        let breaker = CircuitBreaker(fallback: callback, command: test)

        breaker.forceHalfOpen()
        breaker.run(args: ())

        // Check that state is now closed
        XCTAssertEqual(breaker.breakerState, State.closed)

    }

    // Execute method successfully
    func testFunctionCall() {

        let breaker = CircuitBreaker(fallback: callback, command: sum)

        breaker.run(args: (a: 1, b: 3))

        // Wait for set timeout
        XCTAssertEqual(breaker.breakerState, State.closed)

    }

    // Print Stats snapshot
    func testStatsSnapshot() {

        let breaker = CircuitBreaker(fallback: callback, command: sum)

        // TODO: Do something more meaningful here
        breaker.run(args: (a: 1, b: 2))

        breaker.snapshot()

        // TODO: Check that state is closed
        XCTAssertEqual(breaker.breakerState, State.closed)

    }

    // Test timeout
    func testTimeout() {

        let breaker = CircuitBreaker(timeout: 5.0, fallback: callback, command: time)

        breaker.run(args: (a: 1, seconds: 11))

        XCTAssertEqual(breaker.breakerState, State.closed)
        XCTAssertEqual(timedOut, true)

    }

    // Test timeout and reset
    func testTimeoutReset() {
        let resetTimeout = 10

        let breaker = CircuitBreaker(timeout: 5.0, resetTimeout: resetTimeout, maxFailures: 1, fallback: callback, command: time)

        breaker.run(args: (a: 1, seconds: 11))

        sleep(UInt32(resetTimeout + 2))

        // Wait for set timeout
        XCTAssertEqual(breaker.breakerState, State.halfopen)
        XCTAssertEqual(timedOut, true)

    }

    // Test Invocation Wrapper
     func testInvocationWrapper() {
    
         let breaker = CircuitBreaker(fallback: callback, commandWrapper: sumWrapper)
    
         breaker.run(args: (a: 3, b: 4))
    
         XCTAssertEqual(breaker.breakerState, State.closed)
    
         for _ in 1...6 {
             breaker.run(args: (a: 2, b: 2))
         }
    
         XCTAssertEqual(breaker.breakerState, State.open)
     }

}
