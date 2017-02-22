import XCTest
import Foundation
import HeliumLogger
import LoggerAPI
import Dispatch

@testable import CircuitBreaker

class CircuitBreakerTests: XCTestCase {

    // Test static vars
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
            ("testInvocationWrapper", testInvocationWrapper),
            ("testWrapperAsync", testWrapperAsync),
            ("testBulkhead", testBulkhead),
            ("testBulkheadFullQueue", testBulkheadFullQueue)
        ]
    }

    // Test instance vars
    var timedOut: Bool = false

    override func setUp() {
        super.setUp()
        HeliumLogger.use(LoggerMessageType.debug)
        timedOut = false
    }

    func sum(a: Int, b: Int) -> Int {
        return a + b
    }

    func sumWrapper(invocation: Invocation<(Int, Int), Int, String>) -> Int {
        let result = sum(a: invocation.commandArgs.0, b: invocation.commandArgs.1)
        if result != 7 {
            invocation.notifyFailure()
            return 0
        } else {
            invocation.notifySuccess()
            return result
        }
    }

    func fallbackFunction(msg: String) -> Void {
        timedOut = true
        Log.verbose("Test case error: \(msg)")
    }

    func time(a: Int, seconds: Int) -> Int {
        sleep(UInt32(seconds))

        return a
    }

    func test(a: Any) -> () {}

    // Create CircuitBreaker, state should be Closed and no failures
    func testDefaultConstructor() {

        let breaker = CircuitBreaker(fallback: fallbackFunction, command: test)

        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, State.closed)

        // Check that the number of failures is zero
        XCTAssertEqual(breaker.numFailures, 0)

    }

    // Create CircuitBreaker with user options set
    func testConstructor() {

        let breaker = CircuitBreaker(timeout: 5.0, resetTimeout: 5, maxFailures: 3, fallback: fallbackFunction, command: test)

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

        let breaker = CircuitBreaker(timeout: 5.0, resetTimeout: 5, fallback: fallbackFunction, command: test)

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

        let breaker = CircuitBreaker(fallback: fallbackFunction, command: test)

        // Force open
        breaker.forceOpen()

        // Check that the state is Open
        XCTAssertEqual(breaker.breakerState, State.open)
    }

    // Should enter half open state after reset timeout
    func testHalfOpenResetTimeout() {

        let resetTimeout = 10

        let breaker = CircuitBreaker(timeout: 10.0, resetTimeout: resetTimeout, maxFailures: 10, fallback: fallbackFunction, command: test)

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

        let breaker = CircuitBreaker(fallback: fallbackFunction, command: test)

        breaker.forceOpen()
        breaker.run(commandArgs: (), fallbackArgs: (msg: "Fast fail."))

        // Sometimes the Travis timing throws this off
        sleep(3)

        // Check rejected request count
        XCTAssertEqual(breaker.breakerStats.rejectedRequests, 1)
    }

    // Should reset failures to 0
    func testResetFailures() {

        let breaker = CircuitBreaker(fallback: fallbackFunction, command: test)

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

        let breaker = CircuitBreaker(fallback: fallbackFunction, command: test)

        breaker.forceHalfOpen()
        breaker.run(commandArgs: (), fallbackArgs: (msg: "Failure."))

        // Check that state is now closed
        XCTAssertEqual(breaker.breakerState, State.closed)
    }

    // Execute method successfully
    func testFunctionCall() {

        let breaker = CircuitBreaker(fallback: fallbackFunction, command: sum)

        breaker.run(commandArgs: (a: 1, b: 3), fallbackArgs: (msg: "Error getting sum."))

        // Wait for set timeout
        XCTAssertEqual(breaker.breakerState, State.closed)
    }

    // Print Stats snapshot
    func testStatsSnapshot() {

        let breaker = CircuitBreaker(fallback: fallbackFunction, command: sum)

        // TODO: Do something more meaningful here
        breaker.run(commandArgs: (a: 1, b: 2), fallbackArgs: (msg: "Error getting snapshot."))

        breaker.snapshot()

        // TODO: Check that state is closed
        XCTAssertEqual(breaker.breakerState, State.closed)
    }

    // Test timeout
    func testTimeout() {

        let breaker = CircuitBreaker(timeout: 5.0, fallback: fallbackFunction, command: time)

        breaker.run(commandArgs: (a: 1, seconds: 11), fallbackArgs: (msg: "Timeout."))

        XCTAssertEqual(breaker.breakerState, State.closed)
        XCTAssertEqual(timedOut, true)
    }

    // Test timeout and reset
    func testTimeoutReset() {
        let resetTimeout = 10

        let breaker = CircuitBreaker(timeout: 5.0, resetTimeout: resetTimeout, maxFailures: 1, fallback: fallbackFunction, command: time)

        breaker.run(commandArgs: (a: 1, seconds: 11), fallbackArgs: (msg: "Timeout."))

        sleep(UInt32(resetTimeout + 2))

        // Wait for set timeout
        XCTAssertEqual(breaker.breakerState, State.halfopen)
        XCTAssertEqual(timedOut, true)
    }

    // Test Invocation Wrapper
    func testInvocationWrapper() {

        let breaker = CircuitBreaker(fallback: fallbackFunction, commandWrapper: sumWrapper)

        breaker.run(commandArgs: (a: 3, b: 4), fallbackArgs: (msg: "Failure."))

        XCTAssertEqual(breaker.breakerState, State.closed)

        for _ in 1...6 {
            breaker.run(commandArgs: (a: 2, b: 2), fallbackArgs: (msg: "Failure."))
        }

        XCTAssertEqual(breaker.breakerState, State.open)
    }

    // Test Invocation Wrapper with Async call
    func testWrapperAsync() {
        // Need to use expectations since this test is async (the assertions against the CircuitBreaker should happen once the async function has completed.)
        let expectation1 = expectation(description: "Add two numbers")

        func asyncWrapper(invocation: Invocation<(Int, Int), Void, String>) {
            //sumAsync(a: invocation.args.0, b: invocation.args.1, completion: invocation.args.2)
            let queue = DispatchQueue(label: "asyncWrapperTestQueue", attributes: .concurrent)
            queue.async(execute: {
                let sum = invocation.commandArgs.0 + invocation.commandArgs.1
                Log.verbose("sum: \(sum)")
                invocation.notifySuccess()
                expectation1.fulfill()
                //invocation.notifyFailure()
            })
        }

        let breaker = CircuitBreaker(fallback: fallbackFunction, commandWrapper: asyncWrapper)

        breaker.run(commandArgs: (a: 3, b: 4), fallbackArgs: (msg: "Failure."))

        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
        })
    }

    // Test bulkhead basic
    func testBulkhead() {

        let breaker = CircuitBreaker(bulkhead: 2, fallback: fallbackFunction, command: sum)

        breaker.run(commandArgs: (a: 2, b: 3), fallbackArgs: (msg: "Failure."))

        XCTAssertEqual(breaker.breakerState, State.closed)
    }

    //TODO: Figure out how to to set a full queue
    func testBulkheadFullQueue() {

        let expectation1 = expectation(description: "Wait for time and then return")

        var count = 0

        func timeBulkhead(a: Int, seconds: Int) -> Int {
            sleep(UInt32(seconds))

            count += 1

            if count == 3 {
                expectation1.fulfill()
            }

            return a
        }

        let breaker = CircuitBreaker(bulkhead: 2, fallback: fallbackFunction, command: timeBulkhead)

        breaker.run(commandArgs: (a: 4, seconds: 5), fallbackArgs: (msg: "Failure."))
        breaker.run(commandArgs: (a: 5, seconds: 6), fallbackArgs: (msg: "Failure."))
        breaker.run(commandArgs: (a: 3, seconds: 4), fallbackArgs: (msg: "Failure."))

        waitForExpectations(timeout: 17, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
        })
    }

    // TODO: Once BreakerError is added into fallback, make this test more meaningful
    // Multiple fallback parameters
    func testFallback() {

        func fallbackWithParms (msg: String, result: Int, err: Bool) -> Void {
            Log.verbose("Test case callback: \(msg) \(result) \(err)")
        }

        let breaker = CircuitBreaker(timeout: 5.0, fallback: fallbackWithParms, command: time)

        breaker.run(commandArgs: (a: 1, seconds: 11), fallbackArgs: (msg: "Error function timed out.", result: 2, err: true))

        // Wait for set timeout
        XCTAssertEqual(breaker.breakerState, State.closed)
    }

}
