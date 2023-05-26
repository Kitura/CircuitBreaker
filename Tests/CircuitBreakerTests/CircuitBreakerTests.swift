/**
* Copyright IBM Corporation 2017, 2018
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

extension BreakerError {
  public static let networking = BreakerError(reason: "URL Could Not Be Found")
  public static let generic = BreakerError(reason: "There was an error")
}

class CircuitBreakerTests: XCTestCase {

  // Test static vars
  static var allTests: [(String, (CircuitBreakerTests) -> () throws -> Void)] {
    return [
      ("testDefaultConstructor", testDefaultConstructor),
      ("testConstructor", testConstructor),
      ("testPartialConstructor", testPartialConstructor),
      ("testDefaultCtxFunctionConstructor", testDefaultCtxFunctionConstructor),
      ("testCtxFunctionConstructor", testCtxFunctionConstructor),
      ("testPartialCtxFunctionConstructor", testPartialCtxFunctionConstructor),
      ("testForceOpen", testForceOpen),
      ("testHalfOpenResetTimeout", testHalfOpenResetTimeout),
      ("testResetFailures", testResetFailures),
      ("testFailingAsyncFallbackClosed", testFailingAsyncFallbackClosed),
      ("testFailingAsyncFallbackHalfOpen", testFailingAsyncFallbackHalfOpen),
      ("testFastFail", testFastFail),
      ("testHalfOpenSuccess", testHalfOpenSuccess),
      ("testHalfOpenSuccessCtxFunction", testHalfOpenSuccessCtxFunction),
      ("testHalfOpenSuccessBulkhead", testHalfOpenSuccessBulkhead),
      ("testFunctionCall", testFunctionCall),
      ("testStatsSnapshot", testStatsSnapshot),
      ("testTimeout", testTimeout),
      ("testTimeoutReset", testTimeoutReset),
      ("testInvocationCtxFunction", testInvocationCtxFunction),
      ("testInvocationCtxFunctionTimeout", testInvocationCtxFunctionTimeout),
      ("testInvocationCtxFunctionComplex", testInvocationCtxFunctionComplex),
      ("testCtxFunctionAsync", testCtxFunctionAsync),
      ("testBulkhead", testBulkhead),
      ("testBulkheadCtxFunction", testBulkheadCtxFunction),
      ("testBulkheadFullQueue", testBulkheadFullQueue),
      ("testStateCycle", testStateCycle),
      ("testFallback", testFallback),
      ("testRollingWindow", testRollingWindow),
      ("testSmallRollingWindow", testSmallRollingWindow)
    ]
  }

  // Test instance vars
  let semaphore = DispatchSemaphore(value: 1)
  let dispatchGroup = DispatchGroup()
  var timedOut: Bool = false
  var fastFailed: Bool = false
  var invocationErrored = false
  var testCalled: Bool = false

  override func setUp() {
    super.setUp()
    //HeliumLogger.use(LoggerMessageType.debug)
    semaphore.wait()
    timedOut = false
    fastFailed = false
    testCalled = false
    invocationErrored = false
    semaphore.signal()
  }

  func dispatchTime(afterMs: Int) -> DispatchTime {
    return DispatchTime.now() + .milliseconds(afterMs)
  }

  func sum(invocation: Invocation<(Int, Int), Void>) {
    let args = invocation.commandArgs
    let _ = args.0 + args.1
    invocation.notifySuccess()
  }

  func dummyCtxFunction(invocation: Invocation<(Void), Void>) {
    invocation.notifySuccess()
  }

  func dummyFallback(error: BreakerError, _: Void) -> Void {
    //print("dummyFallback() -> Error: \(error)")
  }

  func dummyFallback(error: BreakerError, _: BreakerError) -> Void {
    //print("dummyFallback() -> Error: \(error)")
  }

  func simpleCtxFunction(invocation: Invocation<(Bool), Void>) {
    invocation.commandArgs ? invocation.notifySuccess() : invocation.notifyFailure(error: .generic)
  }

  // There is no 1-tuple in Swift...
  // https://medium.com/swift-programming/facets-of-swift-part-2-tuples-4bfe58d21abf#.v4rj4md9c
  func fallbackFunction(error: BreakerError, expectedError: BreakerError) -> Void {
    semaphore.wait()
    switch error {
    case .timeout:
      timedOut = true
    case .fastFail:
      fastFailed = true
    default:
      invocationErrored = true
    }
    semaphore.signal()
    // Validate the outcome was the desired one
    XCTAssertEqual(error, expectedError, "Breaker error was not the expected one.")
  }

  func time(milliseconds: Int) {
    usleep(UInt32(milliseconds * 1000))
  }

  func timeCtxFunction(invocation: Invocation<(Int), BreakerError>) {
    time(milliseconds: invocation.commandArgs)
    invocation.notifySuccess()
  }
  
  func timeDispatchGroupFunction(invocation: Invocation<Int, BreakerError>) {
    let args = invocation.commandArgs
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(args), execute: {
      invocation.notifySuccess()
      self.dispatchGroup.leave()
    })
  }

  func test(inv: Invocation<(Void), BreakerError>) { testCalled = true; inv.notifySuccess() }

  func testVoidArgs(inv: Invocation<(Void), Void>) { testCalled = true; inv.notifySuccess() }

  // Create CircuitBreaker, state should be Closed and no failures
  func testDefaultConstructor() {
    let breaker = CircuitBreaker(name: "Test", command: test, fallback: fallbackFunction)

    // Check that the state is Closed
    XCTAssertEqual(breaker.breakerState, State.closed)

    // Check that the number of failures is zero
    XCTAssertEqual(breaker.numberOfFailures, 0)
  }

  // Create CircuitBreaker with user options set
  func testConstructor() {
    let breaker = CircuitBreaker(name: "Test", timeout: 5000, resetTimeout: 5000, maxFailures: 3, command: test, fallback: fallbackFunction)

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
    let breaker = CircuitBreaker(name: "Test", timeout: 5000, resetTimeout: 5000, command: test, fallback: fallbackFunction)

    // Check that the state is Closed
    XCTAssertEqual(breaker.breakerState, State.closed)

    // Check that the number of failures is zero
    XCTAssertEqual(breaker.numberOfFailures, 0)

    // Check that the options are set on the CircuitBreaker
    XCTAssertEqual(breaker.timeout, 5000)
    XCTAssertEqual(breaker.resetTimeout, 5000)
    XCTAssertEqual(breaker.maxFailures, 5)
  }

  // Create CircuitBreaker using a command, state should be Closed and no failures
  func testDefaultCtxFunctionConstructor() {
    let breaker = CircuitBreaker(name: "Test", command: dummyCtxFunction, fallback: dummyFallback)

    // Check that the state is Closed
    XCTAssertEqual(breaker.breakerState, State.closed)

    // Check that the number of failures is zero
    XCTAssertEqual(breaker.numberOfFailures, 0)
  }

  // Create CircuitBreaker with user options set
  func testCtxFunctionConstructor() {
    let breaker = CircuitBreaker(name: "Test", timeout: 5000, resetTimeout: 5000, maxFailures: 3, command: dummyCtxFunction, fallback: dummyFallback)

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
  func testPartialCtxFunctionConstructor() {
    let breaker = CircuitBreaker(name: "Test", timeout: 5000, resetTimeout: 5000, command: dummyCtxFunction, fallback: dummyFallback)

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
    let breaker = CircuitBreaker(name: "Test", command: test, fallback: fallbackFunction)

    // Force open
    breaker.forceOpen()

    // Check that the state is Open
    XCTAssertEqual(breaker.breakerState, State.open)
  }

  // Force open state, then breaker should enter half open state after reset timeout.
  func testHalfOpenResetTimeout() {
    let resetTimeout = 100
    let breaker = CircuitBreaker(name: "Test", timeout: 100, resetTimeout: resetTimeout, command: test, fallback: fallbackFunction)

    // Force open
    breaker.forceOpen()

    // Check that the state is Open
    XCTAssertEqual(breaker.breakerState, State.open)

    time(milliseconds: 200)

    // Validate state of the circuit (should be half open)
    XCTAssertEqual(breaker.breakerState, State.halfopen)

  }

  // Should enter open state and fast fail
  func testFastFail() {
    let breaker = CircuitBreaker(name: "Test", command: test, fallback: fallbackFunction)

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

    let timeout: Int = 50
    let maxFailures = 2
    let sleepTime = 500
    let rollingWindow = (sleepTime * maxFailures) + 500

    // Verify validity of tests
    XCTAssertTrue(rollingWindow > (sleepTime * maxFailures))

    let breaker = CircuitBreaker(name: "Test", timeout: timeout, maxFailures: maxFailures, rollingWindow: rollingWindow, command: timeCtxFunction, fallback: fallbackFunction)

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
    let breaker = CircuitBreaker(name: "Test", command: test, fallback: dummyFallback)

    breaker.forceHalfOpen()
    XCTAssertEqual(breaker.breakerState, State.halfopen)

    breaker.run(commandArgs: (), fallbackArgs: BreakerError.networking)
    XCTAssertTrue(testCalled)
    XCTAssertEqual(breaker.breakerState, State.closed)
  }

  // Should enter closed state from halfopen state after a success
  func testHalfOpenSuccessCtxFunction() {
    // Breaker will be closed after successful request in halfopen state.
    let breaker = CircuitBreaker(name: "Test", command: simpleCtxFunction, fallback: dummyFallback)

    breaker.forceHalfOpen()
    XCTAssertEqual(breaker.breakerState, State.halfopen)

    breaker.run(commandArgs: true, fallbackArgs: ())
    XCTAssertEqual(breaker.breakerState, State.closed)
  }

  // Should enter closed state from halfopen state after a success
  func testHalfOpenSuccessBulkhead() {
    let expectation1 = expectation(description: "Breaker will be closed after successful bulkhead request in halfopen state.")

    func testHalfOpen(invocation: Invocation<Void, Void>) {
      invocation.notifySuccess()
      expectation1.fulfill()
    }

    let breaker = CircuitBreaker(name: "Test", bulkhead: 3, command: testHalfOpen, fallback: dummyFallback)

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
    let breaker = CircuitBreaker(name: "Test", command: sum, fallback: dummyFallback)
    breaker.run(commandArgs: (a: 1, b: 3), fallbackArgs: ())
    XCTAssertEqual(breaker.breakerState, State.closed)
    XCTAssertEqual(breaker.breakerStats.successfulResponses, 1)
  }

  // Print Stats snapshot
  func testStatsSnapshot() {
    let breaker = CircuitBreaker(name: "Test", command: testVoidArgs, fallback: dummyFallback)
    breaker.run(commandArgs: (), fallbackArgs: ())
    XCTAssertTrue(testCalled)
    XCTAssertEqual(breaker.breakerState, State.closed)
    XCTAssertEqual(breaker.breakerStats.successfulResponses, 1)
    XCTAssertEqual(breaker.breakerStats.failedResponses, 0)
    XCTAssertEqual(breaker.breakerStats.totalRequests, 1)
    XCTAssertEqual(breaker.breakerStats.rejectedRequests, 0)
    XCTAssertEqual(breaker.breakerState, State.closed)
  }

  // Test timeout
  func testTimeout() {
    let expectation1 = expectation(description: "Command will timeout, breaker will still be closed.")
    
    let breaker = CircuitBreaker(name: "Test", timeout: 50, command: timeDispatchGroupFunction, fallback: fallbackFunction)
    dispatchGroup.enter()
    breaker.run(commandArgs: 100, fallbackArgs: BreakerError.timeout)
    dispatchGroup.notify(queue: .main) {
      XCTAssertEqual(breaker.breakerState, State.closed)
      XCTAssertEqual(self.timedOut, true)
      expectation1.fulfill()
    }
    waitForExpectations(timeout: 20)
  }

  // Test timeout and reset
  func testTimeoutReset() {

    // Command will timeout, breaker will open, and then reset to halfopen.
    let resetTimeout = 100

    let breaker = CircuitBreaker(name: "Test", timeout: 0, resetTimeout: resetTimeout, maxFailures: 1, command: timeCtxFunction, fallback: fallbackFunction)

    breaker.run(commandArgs: 50, fallbackArgs: BreakerError.timeout) // times outs

    time(milliseconds: 200)

    XCTAssertEqual(breaker.breakerState, State.halfopen)
    XCTAssertEqual(self.timedOut, true)
  }

  // Test Invocation Ctx Function
  func testInvocationCtxFunction() {
    //The context function notifies the breaker of the failures, ends in open state.
    let maxFailures = 5

    let breaker = CircuitBreaker(name: "Test", maxFailures: maxFailures, command: simpleCtxFunction, fallback: dummyFallback)

    breaker.run(commandArgs: true, fallbackArgs: ())

    XCTAssertEqual(breaker.breakerState, State.closed)

    for _ in 1...maxFailures {
      breaker.run(commandArgs: false, fallbackArgs: ())
    }

    XCTAssertEqual(breaker.breakerState, State.open)
  }

  // Test Invocation Ctx Function
  func testInvocationCtxFunctionTimeout() {
    //Breaker using ctx function will timeout but should remain in closed state.
    let breaker = CircuitBreaker(name: "Test", timeout: 100, command: timeCtxFunction, fallback: fallbackFunction)
    breaker.run(commandArgs: 200, fallbackArgs: BreakerError.timeout)

    XCTAssertEqual(breaker.breakerState, State.closed)
    XCTAssertEqual(self.timedOut, true)
  }

  // Test Invocation Ctx Function with complex fallback
  func testInvocationCtxFunctionComplex() {
    // The ctx function notifies the breaker of the failures, breaker ends in open state.

    let maxFailures = 5

    let breaker = CircuitBreaker(name: "Test", maxFailures: maxFailures, command: simpleCtxFunction, fallback: dummyFallback)

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

  // Test Invocation Ctx Function with Async call
  func testCtxFunctionAsync() {
    let expectation1 = expectation(description: "Add two numbers asynchronously.")

    func asyncWrapper(invocation: Invocation<(Int, Int), Void>) {
      //sumAsync(a: invocation.args.0, b: invocation.args.1, completion: invocation.args.2)
      let queue = DispatchQueue(label: "asyncWrapperTestQueue", attributes: .concurrent)
      queue.async(execute: {
        let _ = invocation.commandArgs.0 + invocation.commandArgs.1
        //print("Sum (asyncWrapper): \(sum)")
        invocation.notifySuccess()
        expectation1.fulfill()
      })
    }

    let breaker = CircuitBreaker(name: "Test", command: asyncWrapper, fallback: dummyFallback)
    breaker.run(commandArgs: (a: 3, b: 4), fallbackArgs: ())

    waitForExpectations(timeout: 10, handler: { _ in
      XCTAssertEqual(breaker.breakerState, State.closed)
    })
  }

  // Test Failing fallback for user called error when circuit is closed
  func testFailingAsyncFallbackClosed() {
    let expectation1 = expectation(description: "Fallback called")

    func failingCommand(invocation: Invocation<Void, Void>) {
      invocation.notifyFailure(error: .networking)
    }

    func fallback(error: BreakerError, _: Void) -> Void {
      XCTAssertEqual(error, BreakerError.networking)
      expectation1.fulfill()
    }

    let breaker = CircuitBreaker(name: "Test", command: failingCommand, fallback: fallback)
    breaker.run(commandArgs: (), fallbackArgs: ())

    waitForExpectations(timeout: 10, handler: { _ in
      XCTAssertEqual(breaker.breakerState, State.closed)
    })
  }

  // Test Failing fallback for user called error when circuit is half-open
  func testFailingAsyncFallbackHalfOpen() {
    let expectation1 = expectation(description: "Fallback called")

    func failingCommand(invocation: Invocation<Bool, Void>) {
      invocation.notifyFailure(error: .networking)
    }

    func fallback(error: BreakerError, _: Void) -> Void {
      XCTAssertEqual(error, BreakerError.networking)
      expectation1.fulfill()
    }

    let breaker = CircuitBreaker(name: "Test", command: failingCommand, fallback: fallback)
    breaker.forceHalfOpen()

    // Context Command Failure
    breaker.run(commandArgs: (false), fallbackArgs: ())

    waitForExpectations(timeout: 10, handler: { _ in
      XCTAssertEqual(breaker.breakerState, State.open)
    })
  }

  // Test bulkhead basic
  func testBulkhead() {
    let expectation1 = expectation(description: "Use bulkheading feature, breaker is closed after completion of request.")

    func tstCall(invocation: Invocation<Void, Void>) {
      expectation1.fulfill()
    }

    let breaker = CircuitBreaker(name: "Test", bulkhead: 2, command: tstCall, fallback: dummyFallback)
    breaker.run(commandArgs: (), fallbackArgs: ())

    // Check that the state is closed and the sum is 4
    waitForExpectations(timeout: 10, handler: { _ in
      XCTAssertEqual(breaker.breakerState, State.closed)
    })
  }

  // Test bulkhead for command
  func testBulkheadCtxFunction() {
    let expectation1 = expectation(description: "Use bulkheading feature and command, breaker is closed after completion of request.")

    func tstCallWrapper(invocation: Invocation<(Void), Void>) {
      invocation.notifySuccess()
      expectation1.fulfill()
    }

    let breaker = CircuitBreaker(name: "Test", bulkhead: 2, command: tstCallWrapper, fallback: dummyFallback)

    breaker.run(commandArgs: (), fallbackArgs: ())

    // Check that the state is closed
    waitForExpectations(timeout: 10, handler: { _ in
      XCTAssertEqual(breaker.breakerState, State.closed)
      XCTAssertEqual(breaker.breakerStats.successfulResponses, 1)
    })
  }

  // Run multiple requests in the bulkhead queue
  func testBulkheadFullQueue() {
    let expectation1 = expectation(description: "Wait for a predefined amount of time and then return.")

    let timeout = 200
    let maxFailures = 4

    // Validate test case configuration
    XCTAssertTrue(maxFailures > 1)

    let breaker = CircuitBreaker(name: "Test", timeout: timeout, maxFailures: maxFailures, bulkhead: 2, command: timeDispatchGroupFunction, fallback: fallbackFunction)

    for _ in 1..<maxFailures {
      dispatchGroup.enter()
      breaker.run(commandArgs: timeout * 2, fallbackArgs: (BreakerError.timeout))
    }
    
    dispatchGroup.notify(queue: .main) {
      XCTAssertEqual(breaker.breakerState, State.closed)
      XCTAssertEqual(breaker.breakerStats.failedResponses, (maxFailures - 1))
      expectation1.fulfill()
    }
    waitForExpectations(timeout: 20)
  }

  // Validate fallback function is called from the circuit breaker library.
  func testFallback() {
    let timeout = 200
    let breaker = CircuitBreaker(name: "Test", timeout: timeout, command: timeCtxFunction, fallback: fallbackFunction)

    breaker.run(commandArgs: (timeout + 100), fallbackArgs: BreakerError.timeout)

    // Validate fallback function was called
    XCTAssertEqual(self.timedOut, true)

    // Validate state of the circuit
    XCTAssertEqual(breaker.breakerState, State.closed)
  }

  // Validate state cycle of the circuit with halfopen
  func testStateCycle() {

    let expectation1 = expectation(description: "Breaker enters open state after maxFailures is reached. Then after resetTimeout, it should enter half open state.")
    let timeout = 100
    let resetTimeout = 2000
    let maxFailures = 2
    
    let breaker = CircuitBreaker(name: "Test", timeout: timeout, resetTimeout: resetTimeout, maxFailures: maxFailures, command: timeDispatchGroupFunction, fallback: fallbackFunction)

    // Breaker should start in closed state
    XCTAssertEqual(breaker.breakerState, State.closed)
    dispatchGroup.enter()
    breaker.run(commandArgs: 0, fallbackArgs: BreakerError.timeout) // Success

    for _ in 1...maxFailures {
      dispatchGroup.enter()
      breaker.run(commandArgs: timeout + 100, fallbackArgs: BreakerError.timeout) // Timeout, Timeout
    }
    
    // All timeStateCycle closures have completed
    dispatchGroup.notify(queue: .main) {
      XCTAssertEqual(breaker.breakerState, State.open)

      // Breaker closure should not be called since it is failing fast
      breaker.run(commandArgs: 0, fallbackArgs: BreakerError.fastFail) // Fast fail
      XCTAssertEqual(breaker.breakerState, State.open)

      // Wait for reset timeout
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(resetTimeout), execute: {
        XCTAssertEqual(breaker.breakerState, State.halfopen)
        self.dispatchGroup.enter()
        breaker.run(commandArgs: 0, fallbackArgs: BreakerError.timeout) // Success
        self.dispatchGroup.notify(queue: .main) {
          XCTAssertEqual(breaker.breakerState, State.closed)
          expectation1.fulfill()
        }
      })
    }
    waitForExpectations(timeout: 20)
  }

  // Validate state cycle of the circuit (rolling window)
  func testRollingWindow() {
    let expectation1 = expectation(description: "Breaker enters open state after maxFailures is reached. Then after resetTimeout, it should enter half open state.")
    let timeout = 100
    let resetTimeout = 1000
    let maxFailures = 3
    let rollingWindow = (timeout * maxFailures) + 1000
    
    let breaker = CircuitBreaker(name: "Test", timeout: timeout, resetTimeout: resetTimeout, maxFailures: maxFailures, rollingWindow: rollingWindow, command: timeDispatchGroupFunction, fallback: fallbackFunction)

    // Breaker should start in closed state
    XCTAssertEqual(breaker.breakerState, State.closed)
    dispatchGroup.enter()
    breaker.run(commandArgs: 0, fallbackArgs: BreakerError.timeout) // Success

    dispatchGroup.notify(queue: .main) {
        // Validate state of circuit
        XCTAssertEqual(breaker.breakerState, State.closed)
        XCTAssertEqual(breaker.breakerStats.successfulResponses, 1)
        XCTAssertEqual(breaker.breakerStats.failedResponses, 0)
        XCTAssertEqual(breaker.breakerStats.totalRequests, 1)
        XCTAssertEqual(breaker.breakerStats.rejectedRequests, 0)
    

      // Create maxFailures-1 consecutive failures
      for _ in 1...(maxFailures-1) {
        self.dispatchGroup.enter()
        breaker.run(commandArgs: timeout + 100, fallbackArgs: BreakerError.timeout)
      }

      // All timeRollingWindow closures have completed
      self.dispatchGroup.notify(queue: .main) {
        XCTAssertEqual(breaker.breakerState, State.closed)
          
        // Create a successful invocation
        self.dispatchGroup.enter()
        breaker.run(commandArgs: 0, fallbackArgs: BreakerError.timeout) // Success
                
        // Create one more failure
        self.dispatchGroup.enter()
        breaker.run(commandArgs: timeout + 100, fallbackArgs: BreakerError.timeout) // timeout
        self.dispatchGroup.notify(queue: .main) {
          XCTAssertEqual(breaker.breakerState, State.open)
          XCTAssertEqual(breaker.breakerStats.successfulResponses, 2)
          XCTAssertEqual(breaker.breakerStats.failedResponses, maxFailures)
          XCTAssertEqual(breaker.breakerStats.totalRequests, (maxFailures + 2))

          // Breaker closure should not be called since it is failing fast
          breaker.run(commandArgs: 0, fallbackArgs: BreakerError.fastFail) // Fast fail
          XCTAssertEqual(breaker.breakerState, State.open)
          XCTAssertEqual(breaker.breakerStats.rejectedRequests, 1)

          // Wait for reset timeout
          DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(resetTimeout), execute: {
            XCTAssertEqual(breaker.breakerState, State.halfopen)
            self.dispatchGroup.enter()
            breaker.run(commandArgs: 0, fallbackArgs: BreakerError.timeout) // Success
            self.dispatchGroup.notify(queue: .main) {
              XCTAssertEqual(breaker.breakerState, State.closed)
              expectation1.fulfill()
            }
          })
        }
      }
    }
    waitForExpectations(timeout: 20)
  }

  // Validate state cycle of the circuit (small rolling window)
  func testSmallRollingWindow() {
    let expectation1 = expectation(description: "Breaker should not enter open state after maxFailures is reached because the max number of failures did not occur within the time window specified by rollingWindow.")
    let timeout = 100
    let resetTimeout = 10000
    let maxFailures = 5
    let rollingWindow = timeout

    XCTAssertTrue(rollingWindow <= timeout)
    
    let breaker = CircuitBreaker(name: "Test", timeout: timeout, resetTimeout: resetTimeout, maxFailures: maxFailures, rollingWindow: rollingWindow, command: timeDispatchGroupFunction, fallback: fallbackFunction)

    // Breaker should start in closed state
    XCTAssertEqual(breaker.breakerState, State.closed)
    dispatchGroup.enter()
    breaker.run(commandArgs: 0, fallbackArgs: BreakerError.timeout) // Success

    // Create max failures
    for i in 1...(maxFailures) {
      dispatchGroup.enter()
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(i * timeout), execute: {
        breaker.run(commandArgs: timeout + 100, fallbackArgs: BreakerError.timeout)
      })
    }

    dispatchGroup.notify(queue: .main) {
      XCTAssertEqual(breaker.breakerState, State.closed)
      // Execute one more successful invocation
      self.dispatchGroup.enter()
      breaker.run(commandArgs: 0, fallbackArgs: BreakerError.timeout) // Success
      self.dispatchGroup.notify(queue: .main) {
        XCTAssertEqual(breaker.breakerState, State.closed)
        XCTAssertEqual(breaker.breakerStats.successfulResponses, 2)
        XCTAssertEqual(breaker.breakerStats.failedResponses, maxFailures)
        XCTAssertEqual(breaker.breakerStats.totalRequests, (maxFailures + 2))
        expectation1.fulfill()
      }
    }
    waitForExpectations(timeout: 20)
  }
}
