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

@testable import CircuitBreaker

class StatsTests: XCTestCase {

  var stats: Stats = Stats()

  static var allTests: [(String, (StatsTests) -> () throws -> Void)] {
    return [
      ("testDefaultConstructor", testDefaultConstructor),
      ("testTotalLatency", testTotalLatency),
      ("testLatencyExecutePercentiles", testLatencyExecutePercentiles),
      ("testLatencyTotalPercentiles", testLatencyTotalPercentiles),
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
      ("testSnapshot", testSnapshot)
    ]
  }

  override func setUp() {
    super.setUp()
    stats.reset()
  }

  // Create Stats, and check that default values are set
  func testDefaultConstructor() {
    XCTAssertEqual(stats.timeouts, 0)
    XCTAssertEqual(stats.successfulResponses, 0)
    XCTAssertEqual(stats.failedResponses, 0)
    XCTAssertEqual(stats.totalRequests, 0)
    XCTAssertEqual(stats.rejectedRequests, 0)
    XCTAssertEqual(stats.totalLatencies.count, 0)
    XCTAssertEqual(stats.executionLatencies.count, 0)
  }

  // Calculate total latency
  func testTotalLatency() {
    stats.totalLatencies = [1, 2, 3, 4, 5]
    let latency = stats.totalLatency
    XCTAssertEqual(latency, 15)
  }

  // Calculate execute latency percentiles
  func testLatencyExecutePercentiles() {
    stats.executionLatencies = [1, 2, 3, 4, 5]
    let latency = stats.latencyExecute
    XCTAssertEqual(latency, [90.0: 5, 100.0: 5, 99.5: 5, 99.0: 5, 75.0: 4, 50.0: 3, 25.0: 2, 0.0: 1, 95.0: 5])
  }

  // Calculate total latency Percentiles
  func testLatencyTotalPercentiles() {
    stats.totalLatencies = [1, 2, 3, 4, 5]
    let latency = stats.latencyTotal
    XCTAssertEqual(latency, [90.0: 5, 100.0: 5, 99.5: 5, 99.0: 5, 75.0: 4, 50.0: 3, 25.0: 2, 0.0: 1, 95.0: 5])
  }
  // Increase timeout count by 1
  func testTrackTimeouts() {
    stats.trackTimeouts()
    XCTAssertEqual(stats.timeouts, 1)
  }

  // Increase successful responses count by 1
  func testTrackSuccessfulResponse() {
    stats.trackSuccessfulResponse()
    XCTAssertEqual(stats.successfulResponses, 1)
  }

  // Increase failed responses count by 1
  func testTrackFailedResponse() {
    stats.trackFailedResponse()
    XCTAssertEqual(stats.failedResponses, 1)
  }

  // Increase rejected request count by 1
  func testTrackRejected() {
    stats.trackRejected()
    XCTAssertEqual(stats.rejectedRequests, 1)
  }

  // Increase request count by 1
  func testTrackRequest() {
    stats.trackRequest()
    XCTAssertEqual(stats.totalRequests, 1)
  }

  // Add latency value
  func testTrackLatency() {
    stats.trackExecutionLatency(latency: 10)
    stats.trackTotalLatency(latency: 10)
    XCTAssertEqual(stats.totalLatencies.count, 1)
    XCTAssertEqual(stats.executionLatencies.count, 1)
    XCTAssertEqual(stats.totalLatencies[0], 10)
    XCTAssertEqual(stats.executionLatencies[0], 10)
  }

  // Check average response time when latency array is empty
  func testAvgResponseTimeInitial() {
    XCTAssertEqual(stats.meanExecutionLatency, 0)
    XCTAssertEqual(stats.meanTotalLatency, 0)
  }

  // Check average response time when latency array has multiple values
  func testAvgResponseTime() {
    stats.executionLatencies = [1, 2, 3, 4, 5]
    stats.totalLatencies = [1, 2, 3, 4, 5]
    XCTAssertEqual(stats.meanExecutionLatency, 3)
    XCTAssertEqual(stats.meanTotalLatency, 3)
  }

  // Calculate total concurrent requests
  func testConcurrentRequests() {
    stats.totalRequests = 8
    stats.successfulResponses = 1
    stats.failedResponses = 2
    stats.rejectedRequests = 3
    XCTAssertEqual(stats.concurrentRequests, 2)

  }

  // Reset all values
  func testReset() {
    stats.timeouts = 2
    stats.successfulResponses = 1
    stats.failedResponses = 2
    stats.totalRequests = 8
    stats.rejectedRequests = 3
    stats.totalLatencies = [1, 2, 3]
    stats.executionLatencies = [1, 2, 3]
    stats.reset()

    XCTAssertEqual(stats.timeouts, 0)
    XCTAssertEqual(stats.successfulResponses, 0)
    XCTAssertEqual(stats.failedResponses, 0)
    XCTAssertEqual(stats.totalRequests, 0)
    XCTAssertEqual(stats.rejectedRequests, 0)
    XCTAssertEqual(stats.totalLatencies.count, 0)
    XCTAssertEqual(stats.executionLatencies.count, 0)
  }

  // Print out current snapshot of CircuitBreaker Stats
  func testSnapshot() {

    stats.trackRequest()
    stats.trackFailedResponse()
    stats.trackTotalLatency(latency: 30)
    stats.trackExecutionLatency(latency: 30)

    stats.trackRequest()
    stats.trackSuccessfulResponse()
    stats.trackExecutionLatency(latency: 4)
    stats.trackTotalLatency(latency: 4)

    stats.trackRequest()
    stats.trackTimeouts()
    stats.trackExecutionLatency(latency: 100)
    stats.trackTotalLatency(latency: 100)

    stats.snapshot()
  }
}
