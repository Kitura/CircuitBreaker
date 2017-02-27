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

    // There is no 1-tuple in Swift...
    // https://medium.com/swift-programming/facets-of-swift-part-2-tuples-4bfe58d21abf#.v4rj4md9c
    func fallbackFunction(error: BreakerError, msg: String) -> Void {
        if error == BreakerError.timeout {
            timedOut = true
            Log.verbose("Timeout: \(msg)")
        } else if error == BreakerError.fastFail {
            Log.verbose("Fast fail: \(msg)")
        } else {
            Log.verbose("Test case error: \(msg)")
        }
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
    
    // Create CircuitBreaker using a commandWrapper, state should be Closed and no failures
    func testDefaultWrapperConstructor() {
        
        let breaker = CircuitBreaker(fallback: fallbackFunction, commandWrapper: sumWrapper)
        
        // Check that the state is Closed
        XCTAssertEqual(breaker.breakerState, State.closed)
        
        // Check that the number of failures is zero
        XCTAssertEqual(breaker.numFailures, 0)
        
    }
    
    // Create CircuitBreaker with user options set
    func testWrapperConstructor() {
        
        let breaker = CircuitBreaker(timeout: 5.0, resetTimeout: 5, maxFailures: 3, fallback: fallbackFunction, command: sumWrapper)
        
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
    func testPartialWrapperConstructor() {
        
        let breaker = CircuitBreaker(timeout: 5.0, resetTimeout: 5, fallback: fallbackFunction, command: sumWrapper)
        
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

        // Check that the state is Open
        XCTAssertEqual(breaker.breakerState, State.open)

        sleep(UInt32(resetTimeout + 2))

        // Wait for set timeout
        XCTAssertEqual(breaker.breakerState, State.halfopen)
    }

    // Should enter open state and fast fail
    func testFastFail() {

        let expectation1 = expectation(description: "Breaker open, will fast fail.")
        
        func fallbackFastFail(error: BreakerError, msg: String) -> Void {
            if error == BreakerError.timeout {
                timedOut = true
                Log.verbose("Timeout: \(msg)")
            } else if error == BreakerError.fastFail {
                Log.verbose("Fast fail: \(msg)")
            } else {
                Log.verbose("Test case error: \(msg)")
            }
            expectation1.fulfill()
        }
        
        let breaker = CircuitBreaker(fallback: fallbackFastFail, command: test)

        breaker.forceOpen()
        
        breaker.run(commandArgs: (), fallbackArgs: (msg: "Fast fail."))
        
        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.open)
            XCTAssertEqual(breaker.breakerStats.rejectedRequests, 1)
        })
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

        let expectation1 = expectation(description: "Breaker will be closed after successful request in halfopen state.")
        
        func testHalfOpen(completion: (Bool) -> ()) {
            return completion(false)
        }
        
        let breaker = CircuitBreaker(fallback: fallbackFunction, command: testHalfOpen)

        breaker.forceHalfOpen()
        
        XCTAssertEqual(breaker.breakerState, State.halfopen)
        
        breaker.run(commandArgs: (completion: { err in
            Log.verbose("Error: \(err)")
            expectation1.fulfill()
        }), fallbackArgs: (msg: "Failure."))

        // Check that state is now closed
        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
        })
    }
    
    // Should enter closed state from halfopen state after a success
    func testHalfOpenSuccessWrapper() {
        
        let expectation1 = expectation(description: "Breaker will be closed after successful request in halfopen state.")
        
        func sumWrapperCall(invocation: Invocation<(Int, Int), Int, String>) -> Int {
            let result = sum(a: invocation.commandArgs.0, b: invocation.commandArgs.1)
            if result != 7 {
                invocation.notifyFailure()
                expectation1.fulfill()
                return 0
            } else {
                invocation.notifySuccess()
                expectation1.fulfill()
                return result
            }
        }
        
        let breaker = CircuitBreaker(fallback: fallbackFunction, commandWrapper: sumWrapperCall)
        
        breaker.forceHalfOpen()
        
        XCTAssertEqual(breaker.breakerState, State.halfopen)
        
        breaker.run(commandArgs: (a: 3, b: 4), fallbackArgs: (msg: "Failure."))
        
        // Check that state is now closed
        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
        })
    }
    
    // Should enter closed state from halfopen state after a success
    func testHalfOpenSuccessBulkhead() {
        
        let expectation1 = expectation(description: "Breaker will be closed after successful request in halfopen state.")
        
        func testHalfOpen(completion: (Bool) -> ()) {
            return completion(false)
        }
        
        let breaker = CircuitBreaker(bulkhead: 3, fallback: fallbackFunction, command: testHalfOpen)
        
        breaker.forceHalfOpen()
        
        XCTAssertEqual(breaker.breakerState, State.halfopen)
        
        breaker.run(commandArgs: (completion: { err in
            Log.verbose("Error: \(err)")
            expectation1.fulfill()
        }), fallbackArgs: (msg: "Failure."))
        
        // Check that state is now closed
        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
        })
    }

    // Execute method successfully
    func testFunctionCall() {
        
        var total = 0
        
        let expectation1 = expectation(description: "Breaker is closed, and result is 4")
        
        func sumCall (a: Int, b: Int, completion: (Int) -> ()) {
            return completion(a + b)
        }
        
        let breaker = CircuitBreaker(fallback: fallbackFunction, command: sumCall)

        breaker.run(commandArgs: (a: 1, b: 3, completion: { result in
            total = result
            expectation1.fulfill()
        }), fallbackArgs: (msg: "Error getting sum."))

        // Check that the state is closed and the sum is 4
        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
            XCTAssertEqual(total, 4)
        })
    }

    // Print Stats snapshot
    func testStatsSnapshot() {

        let breaker = CircuitBreaker(fallback: fallbackFunction, command: test)

        // TODO: Do something more meaningful here
        breaker.run(commandArgs: (), fallbackArgs: (msg: "Error getting snapshot."))

        breaker.snapshot()

        // TODO: Check that state is closed
        XCTAssertEqual(breaker.breakerState, State.closed)
    }

    // Test timeout
    func testTimeout() {
        
        let expectation1 = expectation(description: "Command will timeout, breaker will still be closed.")
        
        func fallbackTimeout(error: BreakerError, msg: String) -> Void {
            if error == BreakerError.timeout {
                timedOut = true
                Log.verbose("Timeout: \(msg)")
            } else if error == BreakerError.fastFail {
                Log.verbose("Fast fail: \(msg)")
            } else {
                Log.verbose("Test case error: \(msg)")
            }
            expectation1.fulfill()
        }
        
        let breaker = CircuitBreaker(timeout: 5.0, fallback: fallbackTimeout, command: time)

        breaker.run(commandArgs: (a: 1, seconds: 7), fallbackArgs: (msg: "Timeout."))
        
        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
            XCTAssertEqual(self.timedOut, true)
        })
    }

    // Test timeout and reset
    func testTimeoutReset() {
        
        let expectation1 = expectation(description: "Command will timeout, breaker will open, and then reset to halfopen.")
        
        let resetTimeout = 10
        
        func sleepFulfill (time: Int) {
            sleep(UInt32(time))
            expectation1.fulfill()
        }

        let breaker = CircuitBreaker(timeout: 5.0, resetTimeout: resetTimeout, maxFailures: 1, fallback: fallbackFunction, command: time)

        breaker.run(commandArgs: (a: 1, seconds: 11), fallbackArgs: (msg: "Timeout."))

        sleepFulfill(time: resetTimeout + 2)

        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.halfopen)
            XCTAssertEqual(self.timedOut, true)
        })
    }

    // Test Invocation Wrapper
    func testInvocationWrapper() {
        
        let expectation1 = expectation(description: "The wrapper notifies the breaker of the failures, ends in open state.")
        
        func fallbackFunctionFulfill (error: BreakerError, msg: String) -> Void {
            Log.verbose("Test case fallback: \(msg)")
            expectation1.fulfill()
        }

        let breaker = CircuitBreaker(fallback: fallbackFunctionFulfill, commandWrapper: sumWrapper)

        breaker.run(commandArgs: (a: 3, b: 4), fallbackArgs: (msg: "Failure."))
        
        XCTAssertEqual(breaker.breakerState, State.closed)
        
        for _ in 1...6 {
            breaker.run(commandArgs: (a: 2, b: 2), fallbackArgs: (msg: "Failure."))
        }

        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.open)
        })
    }
    
    // Test Invocation Wrapper
    func testInvocationWrapperTimeout() {
        
        let expectation1 = expectation(description: "")
        
        func fallbackTimeout(error: BreakerError, msg: String) -> Void {
            if error == BreakerError.timeout {
                timedOut = true
                Log.verbose("Timeout: \(msg)")
            } else if error == BreakerError.fastFail {
                Log.verbose("Fast fail: \(msg)")
            } else {
                Log.verbose("Test case error: \(msg)")
            }
            expectation1.fulfill()
        }
        
        func timeWrapper(invocation: Invocation<(Int, Int), Int, String>) -> Int {
            let result = time(a: invocation.commandArgs.0, seconds: invocation.commandArgs.1)
            if result != 3 {
                invocation.notifyFailure()
                return 0
            } else {
                invocation.notifySuccess()
                return result
            }
        }
        
        let breaker = CircuitBreaker(timeout: 2, fallback: fallbackTimeout, commandWrapper: timeWrapper)
        
        breaker.run(commandArgs: (a: 3, seconds: 7), fallbackArgs: (msg: "Timeout."))
        
        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
            XCTAssertEqual(self.timedOut, true)
        })
    }
    
    // Test Invocation Wrapper with complex fallback
    func testInvocationWrapperComplex() {
        
        let expectation1 = expectation(description: "The wrapper notifies the breaker of the failures, ends in open state.")
    
        func complexFallbackFunction (error: BreakerError, params: (msg: String, end: Bool)) -> Void {
            if params.end {
                expectation1.fulfill()
            }
            Log.verbose("Test case fallback: \(params.msg)")
        }
    
        func sumWrapperComplex(invocation: Invocation<(Int, Int), Int, (String, Bool)>) -> Int {
            let result = sum(a: invocation.commandArgs.0, b: invocation.commandArgs.1)
            if result != 7 {
                invocation.notifyFailure()
                return 0
            } else {
                invocation.notifySuccess()
                return result
            }
        }

        let breaker = CircuitBreaker(fallback: complexFallbackFunction, commandWrapper: sumWrapperComplex)
    
        breaker.run(commandArgs: (a: 3, b: 4), fallbackArgs: (msg: "Failure.", end: false))
    
        for _ in 1...5 {
            breaker.run(commandArgs: (a: 2, b: 2), fallbackArgs: (msg: "Failure.", end: false))
        }

        breaker.run(commandArgs: (a: 2, b: 2), fallbackArgs: (msg: "Failure.", end: true))
    
        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.open)
        })
        
    }
    
    // Test Invocation Wrapper with Async call
    func testWrapperAsync() {
        
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

        let expectation1 = expectation(description: "Use bulkheading feature, breaker is closed, and result is 4.")
        
        var total = 0
        
        func sumCall (a: Int, b: Int, completion: (Int) -> ()) {
            return completion(a + b)
        }
        
        let breaker = CircuitBreaker(bulkhead: 2, fallback: fallbackFunction, command: sumCall)
        
        breaker.run(commandArgs: (a: 1, b: 3, completion: { result in
            total = result
            expectation1.fulfill()
        }), fallbackArgs: (msg: "Error getting sum."))
        
        // Check that the state is closed and the sum is 4
        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
            XCTAssertEqual(total, 4)
        })
    }
    
    // Test bulkhead for commandWrapper
    func testBulkheadWrapper() {
        
        let expectation1 = expectation(description: "Use bulkheading feature and commandWrapper, breaker is closed, and result is 4.")
        
        func sumWrapperFulfill(invocation: Invocation<(Int, Int), Int, String>) -> Int {
            let result = sum(a: invocation.commandArgs.0, b: invocation.commandArgs.1)
            if result != 7 {
                invocation.notifyFailure()
                expectation1.fulfill()
                return 0
            } else {
                invocation.notifySuccess()
                expectation1.fulfill()
                return result
            }
        }
        
        let breaker = CircuitBreaker(bulkhead: 2, fallback: fallbackFunction, commandWrapper: sumWrapperFulfill)
        
        breaker.run(commandArgs: (a: 4, b: 3), fallbackArgs: (msg: "Error getting sum."))
        
        // Check that the state is closed
        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
            XCTAssertEqual(breaker.breakerStats.successfulResponses, 1)
        })
    }

    // Run multiple requests in the bulkhead queue
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

    // Multiple fallback parameters
    func testFallback() {
        
        let expectation1 = expectation(description: "Function times out in multiple parameter fallback function.")
        
        var fallbackCalled: Bool = false

        func complexFallbackFunction (error: BreakerError, params: (msg: String, result: Int, err: Bool)) -> Void {
            Log.verbose("Test case callback: \(params.msg) \(params.result) \(params.err)")
            fallbackCalled = true
            expectation1.fulfill()
        }

        let breaker = CircuitBreaker(timeout: 5.0, fallback: complexFallbackFunction, command: time)

        breaker.run(commandArgs: (a: 1, seconds: 7), fallbackArgs: (msg: "Error function timed out.", result: 2, err: true))

        waitForExpectations(timeout: 10, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
            XCTAssertEqual(fallbackCalled, true)
        })
    }
    
    // State cycle issue with halfopen
    func testStateCycle() {
        
        let expectation1 = expectation(description: "Breaker enters open state after two maxFailures.")
        
        var count: Int = 0
        
        // Simulate an endpoint we can take down or force a timeout, or success
        func sumHalfOpen(a: Int, b: Int, flag: Bool) -> (Int) {
            
            if flag {
                sleep(5)
                Log.verbose("Sum: \(a + b)")
                return a + b
            } else {
                Log.verbose("Sum: \(a + b)")
                return a + b
            }
        }
        
        let breaker = CircuitBreaker(timeout: 2, resetTimeout: 3, maxFailures: 2, fallback: fallbackFunction, command: sumHalfOpen)
        
        // Breaker should start in closed state
        XCTAssertEqual(breaker.breakerState, State.closed)
        
        breaker.run(commandArgs: (a: 1, b: 3, flag: false), fallbackArgs: (msg: "Sum")) // Success
        
        for _ in 1...2 {
            breaker.run(commandArgs: (a: 2, b: 4, flag: true), fallbackArgs: (msg: "Sum")) // Timeout, Timeout
        }
        
        breaker.run(commandArgs: (a: 2, b: 4, flag: false), fallbackArgs: (msg: "Sum")) // Fast fail
        
        breaker.run(commandArgs: (a: 2, b: 4, flag: false), fallbackArgs: (msg: "Sum")) // Fast fail
        
        sleep(5)
        
        breaker.run(commandArgs: (a: 2, b: 4, flag: false), fallbackArgs: (msg: "Sum")) // Success
        
        sleep(5)
        
        expectation1.fulfill()
        
        waitForExpectations(timeout: 15, handler: { _ in
            XCTAssertEqual(breaker.breakerState, State.closed)
        })
    }

}
