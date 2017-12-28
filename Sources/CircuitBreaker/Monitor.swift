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

import Foundation

/// Protocol identifying a Hystrix observer
public protocol HystrixMonitor {

  /// References to monitored CircuitBreaker instances
  var refs: [HystrixProvider] { get set }

  /// Method to register a hystrix provider
  ///
  /// - Parameters:
  ///   - breakerRef: The HystrixProvider to monitor
  func register(breakerRef: HystrixProvider)

}

/// Protocol identifying a hystrix compliant object
public protocol HystrixProvider: class {

  /// Registers a monitor for a breaker reference
  func addMonitor(monitor: HystrixMonitor)

  /// Histrix compliant instance
  var hystrixSnapshot: [String: Any] { get }
}
