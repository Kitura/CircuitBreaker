[![Build Status](https://travis-ci.com/IBM-Swift/CircuitBreaker.svg?token=zkW1banusRzgHu6HwJiN&branch=develop)](https://travis-ci.com/IBM-Swift/CircuitBreaker)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)

# CircuitBreaker
The Circuit Breaker design pattern is used to increase application stability, improve response time, and prevent the application from making constant failing requests. This library provides the tools needed to bring Circuit Breaker logic to your Swift applications.

![Circuit Breaker Diagram](Docs/circuitBreakerDiagram.png)

## Contents
* [Installation](#installation)
* [Basic Usage](#basic-usage)
* [Advanced Usage](#advanced-usage)
* [API](#api)

## Swift version
The latest version of CircuitBreaker works with the `3.1.1` version of the Swift binaries. You can download this version of the Swift binaries by following this [link](https://swift.org/download/#releases).

## Installation
To leverage the CircuitBreaker package in your Swift application, you should specify a dependency for it in your `Package.swift` file:

```swift
 import PackageDescription

 let package = Package(
     name: "MySwiftProject",

     ...

     dependencies: [
         .Package(url: "https://github.com/IBM-Swift/CircuitBreaker.git", majorVersion: 1),

         ...

     ])
 ```

### Basic Usage

*In this form of usage, the CircuitBreaker state is based on timeouts only.*

If the function you are circuit breaking makes an asynchronous call(s) and the execution time of that call should be taking into account, then see [`Advanced Usage`](#advanced-usage) below.

1. Define a fallback function with the signature `(<BreakerError, (fallbackArg1, fallbackArg2,...)>) -> Void`:
```swift
func myFallback (err: BreakerError, msg: String) {
    // The fallback will be called if the request does not return before the specified timeout
    // or if the CircuitBreaker is currently in Open state and set to fail fast.
    // Client code can use the fallback function to do alternate processing, such as show an error page.
    Log.verbose("Error: \(error)")
    Log.verbose("Message: \(msg)")
}
```

2. Create a function to circuit break:
```swift
func myFunction(a: Int, b: Int) -> Int {
    // do stuff
    let value: Int = ...
    return value
}
```

3. Create a CircuitBreaker instance for each endpoint you wish to circuit break:
  * Must specify the fallback function, and the endpoint to circuit break
  * Optional configurations include: timeout, resetTimeout, maxFailures, and bulkhead
```swift
let breaker = CircuitBreaker(fallback: myFallback, command: myFunction)
```

4. Invoke the call to the function by calling the CircuitBreaker `run()` function and pass the corresponding arguments:
```swift
breaker.run(commandArgs: (a: 10, b: 20), fallbackArgs: (msg: "Something went wrong."))
```

 * May be called multiple times with varied input:
```swift
breaker.run(commandArgs: (a: 15, b: 35), fallbackArgs: (msg: "Something went wrong."))
```

Full Implementation:
```swift
...

func myFallback (err: BreakerError, msg: String) {
    // The fallback will be called if the request does not return before the specified timeout
    // or if the CircuitBreaker is currently in Open state and set to fail fast.
    // Client code can use the fallback function to do alternate processing, such as show an error page.
    Log.verbose("Error: \(error)")
    Log.verbose("Message: \(msg)")
}

func myFunction(a: Int, b: Int) -> Int {
    // do stuff
    let value: Int = ...
    return value
}

let breaker = CircuitBreaker(fallback: myFallback, command: myFunction)

breaker.run(commandArgs: (a: 10, b: 20), fallbackArgs: (msg: "Something went wrong."))
breaker.run(commandArgs: (a: 15, b: 35), fallbackArgs: (msg: "Something went wrong."))

...
```

### Advanced Usage

*In this form of usage, the CircuitBreaker state is based on timeouts and user defined failures (quite useful when the function you are circuit breaking makes an asynchronous call).*

1. Define a fallback function with the signature `(<BreakerError, (fallbackArg1, fallbackArg2,...)>) -> Void`:
```swift
func myFallback (err: BreakerError, msg: String) {
    // The fallback will be called if the request does not return before the specified timeout
    // or if the CircuitBreaker is currently in Open state and set to fail fast.
    Log.verbose("Error: \(error)")
    Log.verbose("Message: \(msg)")
}
```

2. Create a function wrapper for the logic you intend to circuit break (this allows you to alert the CircuitBreaker of a failure or a success):
```swift
func myWrapper(invocation: Invocation<(String), Void, String>) {
  let requestParam = invocation.commandArgs
  // Create HTTP request
  guard let url = URL(string: "http://mysever.net/path/\(requestParam)") else {
    // Something went wrong...

    ...

    invocation.notifyFailure()
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

      invocation.notifyFailure()
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

3. Create a CircuitBreaker instance for each function (e.g. endpoint) you wish to circuit break:
  * Must specify the fallback function and the endpoint to circuit break
  * Optional configurations include: timeout, resetTimeout, maxFailures, rollingWindow, and bulkhead
```swift
let breaker = CircuitBreaker(fallback: myFallback, commandWrapper: myWrapper)
```

4. Invoke the call to the endpoint by calling the CircuitBreaker `run()` function and pass any arguments:
```swift
breaker.run(commandArgs: "92827", fallbackArgs: (msg: "Something went wrong."))
```

Full Implementation:

```swift
...

func myFallback (err: BreakerError, msg: String) {
    // The fallback will be called if the request does not return before the specified timeout
    // or if the CircuitBreaker is currently in Open state and set to fail fast.
    Log.verbose("Error: \(error)")
    Log.verbose("Message: \(msg)")
}

func myWrapper(invocation: Invocation<(String), Void, String>) {
  let requestParam = invocation.commandArgs
  // Create HTTP request
  guard let url = URL(string: "http://mysever.net/path/\(requestParam)") else {
    // Something went wrong...

    ...

    invocation.notifyFailure()
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

      invocation.notifyFailure()
      return
    }

    // Convert results to a JSON object
    let json = JSON(data: result)
    // Process JSON data

    ...

    invocation.notifySuccess()
  }.resume()
}

let breaker = CircuitBreaker(fallback: myFallback, commandWrapper: myWrapper)

breaker.run(commandArgs: "92827", fallbackArgs: (msg: "Something went wrong."))

...
```

## API
### CircuitBreaker

#### Basic Usage Constructor:
```swift
CircuitBreaker(timeout: Int = 1000, resetTimeout: Int = 60000, maxFailures: Int = 5, rollingWindow: Int = 10000, bulkhead: Int = 0, callback: @escaping AnyFallback<C>, command: @escaping AnyFunction<A, B>)
```

#### Advanced Usage Constructor:
```swift
CircuitBreaker(timeout: Int = 1000, resetTimeout: Int = 60000, maxFailures: Int = 5, rollingWindow: Int = 10000, bulkhead: Int = 0, callback: @escaping AnyFallback<C>, commandWrapper: @escaping AnyFunctionWrapper<A, B>)
```

#### Constructor parameters
 * `timeout` Amount in milliseconds that your function should complete before the invocation is considered a failure. Default is set to 1000 milliseconds.
 * `resetTimeout` Amount in milliseconds to wait before setting to halfopen state. Default is set to 60000 milliseconds.
 * `maxFailures` Number of failures allowed within `rollingWindow` before setting state to open. Default is set to 5.
 * `rollingWindow` Time window in milliseconds where the maximum number of failures must occur to trip the circuit. For instance, say `maxFailures` is 5 and `rollingWindow` is 10000 milliseconds. In such case, for the circuit to trip, 5 invocation failures must occur in a time window of 10 seconds, even if these failures are not consecutive. Default is set to 10000 milliseconds.
 * `bulkhead` Number of the limit of concurrent requests running at one time. Default is set to 0, which is equivalent to not using the bulkheading feature.
 * `fallback` Function user specifies to signal timeout or fastFail completion. Required format: `(BreakerError, (fallbackArg1, fallbackArg2,...)) -> Void`
 * `command` Function to circuit break (basic usage constructor).
 * `commandWrapper` Invocation wrapper around logic to circuit break, allows user defined failures (provides reference to circuit breaker instance; advanced usage constructor).

### Stats
```swift
...
// Create CircuitBreaker
let breaker = CircuitBreaker(fallback: myFallback, command: myFunction)

// Invoke breaker call
breaker.run(commandArgs: (a: 10, b: 20), fallbackArgs: (msg: "Something went wrong."))

// Log Stats snapshot
breaker.snapshot()
...
```

#### Tracked Stats:
 * Total Requests
 * Concurrent Requests
 * Rejected Requests
 * Successful Responses
 * Average Response Time
 * Failed Responses
 * Total Timeouts
 * Total Latency

## License
This Swift package is licensed under Apache 2.0. Full license text is available in [LICENSE](LICENSE).
