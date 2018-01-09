[![Build Status](https://travis-ci.org/IBM-Swift/CircuitBreaker.svg?branch=master)](https://travis-ci.org/IBM-Swift/CircuitBreaker)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)

# CircuitBreaker
The Circuit Breaker design pattern is used to increase application stability, improve response time, and prevent the application from making constant failing requests. This library provides the tools needed to bring Circuit Breaker logic to your Swift applications.

![Circuit Breaker Diagram](resources/circuitBreakerDiagram.png)

## Contents
* [Installation](#installation)
* [Usage](#usage)
* [API](#api)
* [License](#license)

## Swift version
The latest version of CircuitBreaker works with the `4.0.3` and newer version of the Swift binaries. You can download this version of the Swift binaries by following this [link](https://swift.org/download/#releases).

## Installation
To leverage the CircuitBreaker package in your Swift application, you should specify a dependency for it in your `Package.swift` file:

```swift
 import PackageDescription

 let package = Package(
     name: "MySwiftProject",

     ...

     dependencies: [
         // Swift 4
         .package(url: "https://github.com/IBM-Swift/CircuitBreaker.git", .upToNextMajor(from: "5.0.0")),
         ...

     ])
 ```

### Usage

*The CircuitBreaker state is based on timeouts and user defined failures (quite useful when the function you are circuit breaking makes an asynchronous call).*

1. Define a fallback function with the signature `(BreakerError, (fallbackArg1, fallbackArg2,...)) -> Void`:
```swift
func myFallback(err: BreakerError, msg: String) {
    // The fallback will be called if one of the below occurs:
    //  1. The request does not return before the specified timeout
    //  2. CircuitBreaker is currently in Open state and set to fail fast.
    //  3. There was an error in the user's called context function (networking error, etc.)
    Log.verbose("Error: \(error)")
    Log.verbose("Message: \(msg)")
}
```
2. Extend BreakerError by defining your own error handling to be used in your context function.
```swift
extension BreakerError {
    public static let encodingURLError = BreakerError(reason: "URL could not be created")
    public static let networkingError = BreakerError(reason: "There was an error, while sending the request")
}
```
3. Create a context function for the logic you intend to circuit break (this allows you to alert the CircuitBreaker of a failure or a success). Please note that a context function receives an `Invocation` object as its parameter. An instance of the `Invocation` class states 1) the parameter types that must be passed to the context function, 2) the return type from the execution of the context function, and 3) parameter type used as the second argument for the fallback closure:
```swift
func myContextFunction(invocation: Invocation<(String), String>) {
  let requestParam = invocation.commandArgs
  // Create HTTP request
  guard let url = URL(string: "http://myserver.net/path/\(requestParam)") else {
    // Something went wrong...

    ...

    invocation.notifyFailure(error: .encodingURLError)
  }

  var req = URLRequest(url: url)
  req.httpMethod = "GET"
  req.allHTTPHeaderFields = ["Content-Type": "application/json"]
  let session = URLSession.shared

  // Perform Request
  session.dataTask(with: req) { result, res, err in
    guard let result = result else {
      // Failed getting a result from the server

      ...

      invocation.notifyFailure(error: .networkingError)
      return
    }

    // Convert results to a JSON object
    let json = JSON(data: result)
    // Process JSON data

    ...

    invocation.notifySuccess()
  }.resume()
}
```

4. Create a CircuitBreaker instance for each context function (e.g. endpoint) you wish to circuit break:
```swift
let breaker = CircuitBreaker(command: myContextFunction, fallback: myFallback)
```
    * Must specify the fallback function and the endpoint to circuit break
    * Optional configurations include: timeout, resetTimeout, maxFailures, rollingWindow, and bulkhead
5. Invoke the call to the endpoint by calling the CircuitBreaker `run()` method. You should pass the corresponding arguments for the context command and fallback closures. In this sample, `myContextFunction` takes a string as its parameter while `myFallback` takes a string as its second parameter:
```swift
let id: String = ...
breaker.run(commandArgs: id, fallbackArgs: "Something went wrong.")
```

###### Full Implementation:

```swift
...
extension BreakerError {
    public static let encodingURLError = BreakerError(reason: "URL could not be created")
    public static let networkingError = BreakerError(reason: "There was an error, while sending the request")
}

func myFallback(err: BreakerError, msg: String) {
    // The fallback will be called if one of the below occurs:
    //  1. The request does not return before the specified timeout
    //  2. CircuitBreaker is currently in Open state and set to fail fast.
    //  3. There was an error in the user's called context function (networking error, etc.)
    Log.verbose("Error: \(error)")
    Log.verbose("Message: \(msg)")
}

func myContextFunction(invocation: Invocation<(String), String>) {
  let requestParam = invocation.commandArgs
  // Create HTTP request
  guard let url = URL(string: "http://mysever.net/path/\(requestParam)") else {
    // Something went wrong...

    ...

    invocation.notifyFailure(error: .encodingURLError)
  }

  var req = URLRequest(url: url)
  req.httpMethod = "GET"
  req.allHTTPHeaderFields = ["Content-Type": "application/json"]
  let session = URLSession.shared

  // Perform Request
  session.dataTask(with: req) { result, res, err in
    guard let result = result else {
      // Failed getting a result from the server

      ...

      invocation.notifyFailure(error: .networkingError)
      return
    }

    // Convert results to a JSON object
    let json = JSON(data: result)
    // Process JSON data

    ...

    invocation.notifySuccess()
  }.resume()
}

let breaker = CircuitBreaker(command: myContextFunction, fallback: myFallback)

let id: String = ...
breaker.run(commandArgs: id, fallbackArgs: "Something went wrong.")

...
```

## API
### CircuitBreaker

#### Constructor
```swift
CircuitBreaker(timeout: Int = 1000, resetTimeout: Int = 60000, maxFailures: Int = 5, rollingWindow: Int = 10000, bulkhead: Int = 0, command: @escaping AnyContextFunction<A>, fallback: @escaping AnyFallback<C>)
```

#### Constructor parameters
 * `timeout` Amount in milliseconds that your function should complete before the invocation is considered a failure. Default is set to 1000 milliseconds.
 * `resetTimeout` Amount in milliseconds to wait before setting to halfopen state. Default is set to 60000 milliseconds.
 * `maxFailures` Number of failures allowed within `rollingWindow` before setting state to open. Default is set to 5.
 * `rollingWindow` Time window in milliseconds where the maximum number of failures must occur to trip the circuit. For instance, say `maxFailures` is 5 and `rollingWindow` is 10000 milliseconds. In such case, for the circuit to trip, 5 invocation failures must occur in a time window of 10 seconds, even if these failures are not consecutive. Default is set to 10000 milliseconds.
 * `bulkhead` Number of the limit of concurrent requests running at one time. Default is set to 0, which is equivalent to not using the bulkheading feature.
 * `fallback` Function user specifies to signal timeout or fastFail completion. Required format: `(BreakerError, (fallbackArg1, fallbackArg2,...)) -> Void`
 * `command` Contextual function to circuit break, which allows user defined failures (the context provides an indirect reference to the corresponding circuit breaker instance).

### Stats

#### Tracked Stats:
 * Total Requests
 * Concurrent Requests
 * Rejected Requests
 * Successful Responses
 * Average Execution Response Time
 * Average Total Response Time
 * Failed Responses
 * Total Timeouts
 * Total Latency
 * Total Execution Latency
 * Hystrix Compliant Snapshot

```swift
...
// Create CircuitBreaker
let breaker = CircuitBreaker(command: myFunction, fallback: myFallback)

// Invoke breaker call
breaker.run(commandArgs: (a: 10, b: 20), fallbackArgs: "Something went wrong.")

// Log Stats snapshot
breaker.snapshot()

// Hystrix compliant snapshot
let snapshot = breaker.snapshot
...
```

#### Observing stats
The CircuitBreaker library provides an interface for observing new CircuitBreaker instances in order to register and track stat changes. In the initialization of a CircuitBreaker instance, the linked monitors are notified of its instantiation allowing them to begin tracking the instance's stats. The CircuitBreaker instance exposes a Hystrix compliant stat snapshot to the monitor which can then be processed accordingly.

```swift

/// Initialize stat monitors
let monitor1 = SwiftMetrics()
let monitor2 = ...
...
let monitorN = ...

/// Register monitors
CircuitBreaker.addMonitor(monitor1)
CircuitBreaker.addMonitor(monitor2)
...
CircuitBreaker.addMonitor(monitorN)

// Create instances of CircuitBreaker
let circuit1 = CircuitBreaker()
let circuit2 = CircuitBreaker()
...
let circuitN = CircuitBreaker()
```

As mentioned above, the initializer takes care of notifying each one of the monitors of the new CircuitBreaker instance.

## License
This Swift package is licensed under Apache 2.0. Full license text is available in [LICENSE](LICENSE).
