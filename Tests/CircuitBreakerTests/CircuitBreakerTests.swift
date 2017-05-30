/**
 * Copyright IBM Corporation 2017
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import XCTest
import Foundation
import Dispatch
//import HeliumLogger
//import LoggerAPI

@testable import CircuitBreaker

class CircuitBreakerTests: XCTestCase {

    // Test static vars
    static var allTests: [(String, (CircuitBreakerTests) -> () throws -> Void)] {
        return [
            ("testDefaultConstructor", testDefaultConstructor),
            ("testConstructor", testConstructor),
            ("testPartialConstructor", testPartialConstructor),
            ("testDefaultWrapperConstructor", testDefaultWrapperConstructor),
            ("testWrapperConstructor", testWrapperConstructor),
            ("testPartialWrapperConstructor", testPartialWrapperConstructor),
            ("testForceOpen", testForceOpen),
            ("testHalfOpenResetTimeout", testHalfOpenResetTimeout),
            ("testResetFailures", testResetFailures),
            ("testFastFail", testFastFail),
            ("testHalfOpenSuccess", testHalfOpenSuccess),
            ("testHalfOpenSuccessWrapper", testHalfOpenSuccessWrapper),
            ("testHalfOpenSuccessBulkhead", testHalfOpenSuccessBulkhead),
            ("testFunctionCall", testFunctionCall),
            ("testStatsSnapshot", testStatsSnapshot),
            ("testTimeout", testTimeout),
            ("testTimeoutReset", testTimeoutReset),
            ("testInvocationWrapper", testInvocationWrapper),
            ("testInvocationWrapperTimeout", testInvocationWrapperTimeout),
            ("testInvocationWrapperComplex", testInvocationWrapperComplex),
            ("testWrapperAsync", testWrapperAsync),
            ("testBulkhead", testBulkhead),
            ("testBulkheadWrapper", testBulkheadWrapper),
            ("testBulkheadFullQueue", testBulkheadFullQueue),
            ("testFallback", testFallback),
            ("testStateCycle", testStateCycle)
        ]
    }

    // Test instance vars
    var timedOut: Bool = false
    var fastFailed: Bool = false

    override func setUp() {
        super.setUp()
        //HeliumLogger.use(LoggerMessageType.debug)
        timedOut = false
        fastFailed = false
    }

    func sum(a: Int, b: Int) -> Int {
        return a + b
    }

    func dummyCmdWrapper(invocation: Invocation<(Void), Void, Void>) {
      invocation.notifySuccess()
    }

    func dummyFallback(error: BreakerError, _: Void) -> Void {
        print("dummyFallback() -> Error: \(error)")
    }

    func simpleWrapper(invocation: Invocation<(Bool), Void, Void>) {
      invocation.commandArgs ? invocation.notifySuccess() : invocation.notifyFailure()
    }

    // There is no 1-tuple in Swift...
    // https://medium.com/swift-programming/facets-of-swift-part-2-tuples-4bfe58d21abf#.v4rj4md9c
    func fallbackFunction(error: BreakerError, expectedError: BreakerError) -> Void {
        switch error {
        case .timeout:
          timedOut = true
        case .fastFail:
          fastFailed = true
        }
        // Validate the outcome was the desired one
        XCTAssertEqual(error, expectedError, "Breaker error was not the expected one.")
    }

    func time(milliseconds: Int) {
        sleep(UInt32(milliseconds / 1000))
        print("time() - > Slept for \(milliseconds) ms.")
    }

    func timeWrapper(invocation: Invocation<(Int), Void, BreakerError>) {
        time(milliseconds: invocation.commandArgs)
    }

    func test(a: Any) -> () {}

    // Create CircuitBreaker, state should be Closed and no failures
    func testDefaultConstructor() {
        let breaker = CircuitBreaker(fallback: fallbackFunction, command: test)

        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, State.closed)

        // Check that the number of failures is zero
        XCTAssertEqual(breaker.numberOfFailures, 0)
    }

    // Create CircuitBreaker with user options set
    func testConstructor() {
        let breaker = CircuitBreaker(timeout: 5000, resetTimeout: 5000, maxFailures: 3, fallback: fallbackFunction, command: test)

        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, State.closed)

        // Check that the number of failures is zero
        XCTAssertEqual(breaker.numberOfFailures, 0)

        // Check that the options are set on the CircuitBreaker
        XCTAssertEqual(breaker.timeout, 5000)
        XCTAssertEqual(breaker.resetTimeout, 5000)
        XCTAssertEqual(breaker.maxFailures, 3)
    }

    // Create CircuitBreaker with user options set
    func testPartialConstructor() {
        let breaker = CircuitBreaker(timeout: 5000, resetTimeout: 5000, fallback: fallbackFunction, command: test)

        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, State.closed)

        // Check that the number of failures is zero
        XCTAssertEqual(breaker.numberOfFailures, 0)

        // Check that the options are set on the CircuitBreaker
        XCTAssertEqual(breaker.timeout, 5000)
        XCTAssertEqual(breaker.resetTimeout, 5000)
        XCTAssertEqual(breaker.maxFailures, 5)
    }

    // Create CircuitBreaker using a commandWrapper, state should be Closed and no failures
    func testDefaultWrapperConstructor() {
        let breaker = CircuitBreaker(fallback: dummyFallback, commandWrapper: dummyCmdWrapper)

        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, State.closed)

        // Check that the number of failures is zero
        XCTAssertEqual(breaker.numberOfFailures, 0)
    }

    // Create CircuitBreaker with user options set
    func testWrapperConstructor() {
        let breaker = CircuitBreaker(timeout: 5000, resetTimeout: 5000, maxFailures: 3, fallback: dummyFallback, command: dummyCmdWrapper)

        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, State.closed)

        // Check that the number of failures is zero
        XCTAssertEqual(breaker.numberOfFailures, 0)

        // Check that the options are set on the CircuitBreaker
        XCTAssertEqual(breaker.timeout, 5000)
        XCTAssertEqual(breaker.resetTimeout, 5000)
        XCTAssertEqual(breaker.maxFailures, 3)
    }

    // Create CircuitBreaker with user options set
    func testPartialWrapperConstructor() {
        let breaker = CircuitBreaker(timeout: 5000, resetTimeout: 5000, fallback: dummyFallback, command: dummyCmdWrapper)

        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, State.closed)

        // Check that the number of failures is zero
        XCTAssertEqual(breaker.numberOfFailures, 0)

        // Check that the options are set on the CircuitBreaker
        XCTAssertEqual(breaker.timeout, 5000)
        XCTAssertEqual(breaker.resetTimeout, 5000)
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

    // Force open state, then breaker should enter half open state after reset timeout.
    func testHalfOpenResetTimeout() {
        let resetTimeout = 10000

        let breaker = CircuitBreaker(timeout: 10000, resetTimeout: resetTimeout, fallback: fallbackFunction, command: test)

        // Force open
        breaker.forceOpen()

        // Check that the state is Open
        XCTAssertEqual(breaker.breakerState, State.open)

        // Sleep for the same duration as the value assinged to the resetTimeout property plus 2 more seconds...
        sleep(UInt32((resetTimeout/1000) + 2))

        // Validate state of the circuit (should be half open)
        XCTAssertEqual(breaker.breakerState, State.halfopen)
    }

    // Should enter open state and fast fail
    func testFastFail() {
        let breaker = CircuitBreaker(fallback: fallbackFunction, command: test)

        breaker.forceOpen()
        XCTAssertEqual(breaker.breakerStats.rejectedRequests, 0)

        breaker.run(commandArgs: (), fallbackArgs: BreakerError.fastFail)

        // Validate circuit state
        XCTAssertTrue(fastFailed)
        XCTAssertEqual(breaker.breakerState, State.open)
        XCTAssertEqual(breaker.breakerStats.rejectedRequests, 1)
    }

    // Should reset failures to 0
    func testResetFailures() {
        let timeout: Int = 1000
        let maxFailures = 2
        let sleepTime = timeout * 4
        let rollingWindow = (sleepTime * maxFailures) + 5000

        // Verify validity of tests
        XCTAssertTrue(rollingWindow > (sleepTime * maxFailures))

        let breaker = CircuitBreaker(timeout: timeout, maxFailures: maxFailures, rollingWindow: rollingWindow, fallback: fallbackFunction, command: time)
        // Cause multiple failures, exceeding max number of failures allowed before tripping circuit
        for _ in 1...maxFailures {
          breaker.run(commandArgs: sleepTime, fallbackArgs: BreakerError.timeout)
        }

        // Check that failures equala maxFailures
        XCTAssertEqual(breaker.numberOfFailures, maxFailures)
        XCTAssertEqual(breaker.state, State.open)

        // Force closed
        breaker.forceClosed()

        // Check that failures is now 0
        XCTAssertEqual(breaker.numberOfFailures, 0)
    }

    // Should enter closed state from halfopen state after a success
    func testHalfOpenSuccess() {
        // Breaker will be closed after successful request in halfopen state.
        let breaker = CircuitBreaker(fallback: dummyFallback, command: test)

        breaker.forceHalfOpen()
        XCTAssertEqual(breaker.breakerState, State.halfopen)

        breaker.run(commandArgs: (), fallbackArgs: ())
        XCTAssertEqual(breaker.breakerState, State.closed)
    }

    // Should enter closed state from halfopen state after a success
    func testHalfOpenSuccessWrapper() {
        // Breaker will be closed after successful request in halfopen state.
        let breaker = CircuitBreaker(fallback: dummyFallback, commandWrapper: simpleWrapper)

        breaker.forceHalfOpen()
        XCTAssertEqual(breaker.breakerState, State.halfopen)

        breaker.run(commandArgs: true, fallbackArgs: ())
        XCTAssertEqual(breaker.breakerState, State.closed)
    }

    // Should enter closed state from halfopen state after a success
    func testHalfOpenSuccessBulkhead() {
        let expectation1 = expectation(description: "Breaker will be closed after successful bulkhead request in halfopen state.")

        func testHalfOpen() {
            expectation1.fulfill()
        }

        let breaker = CircuitBreaker(bulkhead: 3, fallback: dummyFallback, command: testHalfOpen)

        breaker.forceHalfOpen()

        XCTAssertEqual(breaker.breakerState, State.halfopen)

        breaker.run(commandArgs: (), fallbackArgs: ())

        // Check that state is now closed once expectation is fulfilled
        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
        })
    }

    // Execute method successfully
    func testFunctionCall() {
        // Breaker is closed after successful invocation.
        let breaker = CircuitBreaker(fallback: dummyFallback, command: sum)
        breaker.run(commandArgs: (a: 1, b: 3), fallbackArgs: ())
        XCTAssertEqual(breaker.breakerState, State.closed)
        XCTAssertEqual(breaker.breakerStats.successfulResponses, 1)
    }

    // Print Stats snapshot
    func testStatsSnapshot() {
        let breaker = CircuitBreaker(fallback: dummyFallback, command: test)
        breaker.run(commandArgs: (), fallbackArgs: ())
        // TODO: Do something more meaningful here
        breaker.snapshot()
        XCTAssertEqual(breaker.breakerState, State.closed)
    }

    // Test timeout
    func testTimeout() {
        // Command will timeout, breaker will still be closed.
        let breaker = CircuitBreaker(timeout: 5000, fallback: fallbackFunction, command: time)
        breaker.run(commandArgs: 7000, fallbackArgs: BreakerError.timeout)
        XCTAssertEqual(breaker.breakerState, State.closed)
        XCTAssertEqual(self.timedOut, true)
    }

    // Test timeout and reset
    func testTimeoutReset() {
        // Command will timeout, breaker will open, and then reset to halfopen.
        let resetTimeout = 10000

        let breaker = CircuitBreaker(timeout: 5000, resetTimeout: resetTimeout, maxFailures: 1, fallback: fallbackFunction, command: time)

        breaker.run(commandArgs: 11000, fallbackArgs: BreakerError.timeout)

        //sleepFulfill(milliseconds: resetTimeout + 2000)
        sleep(UInt32((resetTimeout/1000) + 2))

        XCTAssertEqual(breaker.breakerState, State.halfopen)
        XCTAssertEqual(self.timedOut, true)
    }

    // Test Invocation Wrapper
    func testInvocationWrapper() {
        //The wrapper notifies the breaker of the failures, ends in open state.
        let maxFailures = 5

        let breaker = CircuitBreaker(maxFailures: maxFailures, fallback: dummyFallback, commandWrapper: simpleWrapper)

        breaker.run(commandArgs: true, fallbackArgs: ())

        XCTAssertEqual(breaker.breakerState, State.closed)

        for _ in 1...maxFailures {
            breaker.run(commandArgs: false, fallbackArgs: ())
        }

        XCTAssertEqual(breaker.breakerState, State.open)
    }

    // Test Invocation Wrapper
    func testInvocationWrapperTimeout() {
        //Breaker using wrapper will timeout but should remain in closed state.
        let breaker = CircuitBreaker(timeout: 2000, fallback: fallbackFunction, commandWrapper: timeWrapper)
        breaker.run(commandArgs: 7000, fallbackArgs: BreakerError.timeout)
        XCTAssertEqual(breaker.breakerState, State.closed)
        XCTAssertEqual(self.timedOut, true)
    }

    // Test Invocation Wrapper with complex fallback
    func testInvocationWrapperComplex() {
        // The wrapper notifies the breaker of the failures, breaker ends in open state.

        let maxFailures = 5

        let breaker = CircuitBreaker(maxFailures: maxFailures, fallback: dummyFallback, commandWrapper: simpleWrapper)

        breaker.run(commandArgs: true, fallbackArgs: ())
        XCTAssertEqual(breaker.breakerState, State.closed)

        for index in 1...maxFailures {
            breaker.run(commandArgs: false, fallbackArgs: ())
            if index < maxFailures {
                XCTAssertEqual(breaker.breakerState, State.closed)
            } else {
                XCTAssertEqual(breaker.breakerState, State.open)
            }
        }
    }

    // Test Invocation Wrapper with Async call
    func testWrapperAsync() {
        let expectation1 = expectation(description: "Add two numbers asynchronously.")

        func asyncWrapper(invocation: Invocation<(Int, Int), Void, Void>) {
            //sumAsync(a: invocation.args.0, b: invocation.args.1, completion: invocation.args.2)
            let queue = DispatchQueue(label: "asyncWrapperTestQueue", attributes: .concurrent)
            queue.async(execute: {
                let sum = invocation.commandArgs.0 + invocation.commandArgs.1
                print("Sum (asyncWrapper): \(sum)")
                invocation.notifySuccess()
                expectation1.fulfill()
            })
        }

        let breaker = CircuitBreaker(fallback: dummyFallback, commandWrapper: asyncWrapper)
        breaker.run(commandArgs: (a: 3, b: 4), fallbackArgs: ())

        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
        })
    }

    // Test bulkhead basic
    func testBulkhead() {
        let expectation1 = expectation(description: "Use bulkheading feature, breaker is closed after completion of request.")

        func tstCall () {
            expectation1.fulfill()
        }

        let breaker = CircuitBreaker(bulkhead: 2, fallback: dummyFallback, command: tstCall)
        breaker.run(commandArgs: (), fallbackArgs: ())

        // Check that the state is closed and the sum is 4
        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
        })
    }

    // Test bulkhead for commandWrapper
    func testBulkheadWrapper() {
        let expectation1 = expectation(description: "Use bulkheading feature and commandWrapper, breaker is closed after completion of request.")

        func tstCallWrapper(invocation: Invocation<(Void), Void, Void>) {
          invocation.notifySuccess()
          expectation1.fulfill()
        }

        let breaker = CircuitBreaker(bulkhead: 2, fallback: dummyFallback, commandWrapper: tstCallWrapper)

        breaker.run(commandArgs: (), fallbackArgs: ())

        // Check that the state is closed
        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
            XCTAssertEqual(breaker.breakerStats.successfulResponses, 1)
        })
    }

    // Run multiple requests in the bulkhead queue
    func testBulkheadFullQueue() {
        let expectation1 = expectation(description: "Wait for predefined amount of time and then return.")

        func timeBulkhead(fulfill: Bool, milliseconds: Int) {
            sleep(UInt32(milliseconds / 1000))
            if fulfill {
                expectation1.fulfill()
            }
        }

        let timeout = 1000
        let maxFailures = 4
        // Validate test case configuration
        XCTAssertTrue(maxFailures > 1)

        let breaker = CircuitBreaker(timeout: timeout, maxFailures: maxFailures, bulkhead: 2, fallback: fallbackFunction, command: timeBulkhead)

        for index in 1..<maxFailures {
          let fulfill = (index < (maxFailures - 1)) ? false : true
          breaker.run(commandArgs: (fulfill: fulfill, milliseconds: (timeout * 5)), fallbackArgs: (BreakerError.timeout))
        }

        waitForExpectations(timeout: 20, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
            XCTAssertEqual(breaker.breakerStats.failedResponses, (maxFailures - 1))
        })
    }

    // Validate fallback function is called from the circuit breaker library.
    func testFallback() {
        let timeout = 5000
        let breaker = CircuitBreaker(timeout: timeout, fallback: fallbackFunction, command: time)

        breaker.run(commandArgs: (timeout + 2000), fallbackArgs: BreakerError.timeout)

        // Validate fallback function was called
        XCTAssertEqual(timedOut, true)

        // Validate state of the circuit
        XCTAssertEqual(breaker.breakerState, State.closed)
    }

    // Validate state cycle of the circuit with halfopen
    func testStateCycle() {
        // Breaker enters open state after two maxFailures. Then after resetTimeout, it should enter half open state.
        let timeout = 2000
        let resetTimeout = 10000
        let maxFailures = 2

        let breaker = CircuitBreaker(timeout: timeout, resetTimeout: resetTimeout, maxFailures: maxFailures, fallback: fallbackFunction, command: time)

        // Breaker should start in closed state
        XCTAssertEqual(breaker.breakerState, State.closed)
        breaker.run(commandArgs: 0, fallbackArgs: BreakerError.timeout) // Success
        XCTAssertEqual(breaker.breakerState, State.closed)

        for _ in 1...maxFailures {
            breaker.run(commandArgs: (timeout + 1000), fallbackArgs: BreakerError.timeout) // Timeout, Timeout
        }

        XCTAssertEqual(breaker.breakerState, State.open)

        breaker.run(commandArgs: 0, fallbackArgs: BreakerError.fastFail) // Fast fail

        XCTAssertEqual(breaker.breakerState, State.open)

        // Wait for reset timeout
        sleep(UInt32(resetTimeout/1000) + 1)

        XCTAssertEqual(breaker.breakerState, State.halfopen)

        breaker.run(commandArgs: 0, fallbackArgs: BreakerError.timeout) // Success

        XCTAssertEqual(breaker.breakerState, State.closed)
    }

}
