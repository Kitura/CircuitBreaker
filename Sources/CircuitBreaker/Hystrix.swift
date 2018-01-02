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

import Foundation

extension CircuitBreaker: HystrixProvider {

  /// Method to create link a Hystrix HystrixMonitor Instance
  public func addMonitor(monitor: HystrixMonitor) {
    monitor.register(breakerRef: self)
  }

  /// Property to computer hystrix snapshot
  public var hystrixSnapshot: [String: Any] {
    return  [
      "type": "HystrixCommand",
      "name": name,
      "group": group ?? "",
      "currentTime": Date().timeIntervalSinceNow,
      "isCircuitBreakerOpen": breakerState == .open,
      "errorPercentage": breakerStats.errorPercentage,
      "errorCount": breakerStats.errorCount,
      "requestCount": breakerStats.totalRequests,
      "rollingCountBadRequests": 0, // not reported
      "rollingCountCollapsedRequests": 0, // not reported
      "rollingCountExceptionsThrown": 0, // not reported
      "rollingCountFailure": breakerStats.failed,
      "rollingCountFallbackFailure": 0, // not reported
      "rollingCountFallbackRejection": 0, // not reported
      "rollingCountFallbackSuccess": 0, // not reported
      "rollingCountResponsesFromCache": 0, // not reported
      "rollingCountSemaphoreRejected": 0, // not reported
      "rollingCountShortCircuited": breakerStats.rejectedRequests,
      "rollingCountSuccess": breakerStats.successful,
      "rollingCountThreadPoolRejected": 0, // not reported
      "rollingCountTimeout": breakerStats.timeouts,
      "currentConcurrentExecutionCount": 0, // not reported
      "latencyExecute_mean": breakerStats.averageResponseTime,
      "latencyExecute": breakerStats.latencyExecute,
      "latencyTotal_mean": 15,
      "latencyTotal": breakerStats.latencyTotal,
      "propertyValue_circuitBreakerRequestVolumeThreshold": 0, //json.waitThreshold,
      "propertyValue_circuitBreakerSleepWindowInMilliseconds": 0, //json.circuitDuration,
      "propertyValue_circuitBreakerErrorThresholdPercentage": 0, //json.threshold,
      "propertyValue_circuitBreakerForceOpen": false,  // not reported
      "propertyValue_circuitBreakerForceClosed": false,  // not reported
      "propertyValue_circuitBreakerEnabled": true,  // not reported
      "propertyValue_executionIsolationStrategy": "THREAD",  // not reported
      "propertyValue_executionIsolationThreadTimeoutInMilliseconds": 800,  // not reported
      "propertyValue_executionIsolationThreadInterruptOnTimeout": true, // not reported
      //"propertyValue_executionIsolationThreadPoolKeyOverride": nil, // not reported
      "propertyValue_executionIsolationSemaphoreMaxConcurrentRequests": 20, //  not reported
      "propertyValue_fallbackIsolationSemaphoreMaxConcurrentRequests": 10, //  not reported
      "propertyValue_metricsRollingStatisticalWindowInMilliseconds": 10000, //  not reported
      "propertyValue_requestCacheEnabled": false,  // not reported
      "propertyValue_requestLogEnabled": false,  // not reported
      "reportingHosts": 1  // not reported
    ]
  }
}
