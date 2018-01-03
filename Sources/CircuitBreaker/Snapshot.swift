/**
* Copyright IBM Corporation 2017 2018
*
* Licensed under the Apache License Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing software
* distributed under the License is distributed on an "AS IS" BASIS
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
**/

import Foundation

public struct Snapshot: Codable {

  /// Tracked Statistics
  let name: String
  let group: String?
  let currentTime: Double
  let isCircuitBreakerOpen: Bool
  let errorPercentage: Double
  let errorCount: Int
  let requestCount: Int

  let rollingCountShortCircuited: Int
  let rollingCountSuccess: Int
  let rollingCountFailure: Int
  let rollingCountTimeout: Int
  let latencyExecute_mean: Int
  let latencyExecute: [Double: Int]
  let latencyTotal: [Double: Int]
  let type: String

  // Untracked Stats
  let rollingCountBadRequests: Int = 0
  let rollingCountCollapsedRequests: Int = 0
  let rollingCountExceptionsThrown: Int =  0
  let rollingCountFallbackFailure: Int = 0
  let rollingCountFallbackRejection: Int = 0
  let rollingCountFallbackSuccess: Int = 0
  let rollingCountResponsesFromCache: Int = 0
  let rollingCountSemaphoreRejected: Int = 0
  let rollingCountThreadPoolRejected: Int = 0
  let currentConcurrentExecutionCount: Int = 0
  let latencyTotal_mean: Int = 15
  let propertyValue_circuitBreakerRequestVolumeThreshold: Int = 0 //json.waitThreshold
  let propertyValue_circuitBreakerSleepWindowInMilliseconds: Int = 0 //json.circuitDuration
  let propertyValue_circuitBreakerErrorThresholdPercentage: Int = 0 //json.threshold
  let propertyValue_circuitBreakerForceOpen: Bool = false
  let propertyValue_circuitBreakerForceClosed: Bool = false
  let propertyValue_circuitBreakerEnabled: Bool = true
  let propertyValue_executionIsolationStrategy: String = "THREAD"
  let propertyValue_executionIsolationThreadTimeoutInMilliseconds: Int = 800
  let propertyValue_executionIsolationThreadInterruptOnTimeout: Bool = true
  let propertyValue_executionIsolationThreadPoolKeyOverride: String? = nil
  let propertyValue_executionIsolationSemaphoreMaxConcurrentRequests: Int = 20 //
  let propertyValue_fallbackIsolationSemaphoreMaxConcurrentRequests: Int = 10 //
  let propertyValue_metricsRollingStatisticalWindowInMilliseconds: Int = 10000 //
  let propertyValue_requestCacheEnabled: Bool = false
  let propertyValue_requestLogEnabled: Bool = false
  let reportingHosts: Int = 1

  public init(type: String, name: String, group: String? = nil, stats: Stats, state: State) {
    self.type = type
    self.name = name
    self.group = group
    self.currentTime = Date().timeIntervalSinceNow
    self.isCircuitBreakerOpen = state == .open
    self.errorPercentage = stats.errorPercentage
    self.errorCount = stats.errorCount
    self.requestCount = stats.totalRequests
    self.rollingCountShortCircuited = stats.rejectedRequests
    self.rollingCountSuccess = stats.successful
    self.rollingCountFailure = stats.failed
    self.rollingCountTimeout = stats.timeouts
    self.latencyExecute_mean = stats.averageResponseTime
    self.latencyExecute = stats.latencyExecute
    self.latencyTotal = stats.latencyTotal
  }
}
