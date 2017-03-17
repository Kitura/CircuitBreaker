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
The latest version of CircuitBreaker works with the `3.0.2` version of the Swift binaries. You can download this version of the Swift binaries by following this [link](https://swift.org/download/#releases).

## Installation
To leverage the CircuitBreaker package in your Swift application, you should specify a dependency for it in your `Package.swift` file:

```swift
 import PackageDescription

 let package = Package(
     name: "MySwiftProject",

     ...

     dependencies: [
         .Package(url: "https://github.com/IBM-Swift/CircuitBreaker.git", majorVersion: 0, minor: 0),

         ...

     ])
 ```

### Basic Usage:

*The CircuitBreaker state is based on timeouts only.*

1. Define a fallback function with the signature `(<BreakerError, (fallbackArg1, fallbackArg2,...)>) -> Void`:
```swift
func testFallback (error: Bool, msg: String) {
    // The fallback will be called if the request does not return before the specified timeout
    // or if the CircuitBreaker is currently in Open state and set to fail fast.
    // Client is expected to use the fallback to do alternate processing, such as show an error page.
    Log.verbose("Error: \(error)")
    Log.verbose("Message: \(msg)")
}
```

2. Create an endpoint to circuit break:
```swift
func testEndpoint(input: String, completion: @escaping (JSON, Bool) -> ()) {
    // Create Request
    var req = URLRequest(url: URL(string: "http://testAPIRoute/\(input)")!)
    req.httpMethod = "GET"
    req.allHTTPHeaderFields = ["Content-Type": "application/json"]

    let session = URLSession.shared

    // Perform Request
    session.dataTask(with: req) {result, res, err in
        guard let result = result else {
            let json = JSON("Error: No results.")
            completion(json, true)
            return
        }

        // Convert results to a JSON object
        let json = JSON(data: result)

        completion(json, false)
        }.resume()
}
```

3. Create a CircuitBreaker instance for each endpoint you wish to circuit break:
  * Must specify the fallback function, and the endpoint to circuit break
  * Optional configurations include: timeout, resetTimeout, maxFailures, and bulkhead
```swift
let breaker = CircuitBreaker(fallback: testFallback, command: testEndpoint)
```

4. Invoke the call to the endpoint by calling the CircuitBreaker `run()` function and pass any arguments:
```swift
breaker.run(commandArgs: (input : "testInput1", { data, err in
    if err {
        print(err)
    } else {
        print(data)
    }
}), fallbackArgs: (msg: "Something went wrong."))
```

 * May be called multiple times with varied input:
```swift
breaker.run(commandArgs: (input : "testInput2", { data, err in
    if err {
        print(err)
    } else {
        print(data)
    }
}), fallbackArgs: (msg: "Something went wrong."))
```

Full Implementation:
```swift
...

func testFallback (error: Bool, msg: String) {
    // The fallback will be called if the request does not return before the specified timeout
    // or if the CircuitBreaker is currently in Open state and set to fail fast.
    // Client is expected to use the fallback to do alternate processing, such as show an error page.
    Log.verbose("Error: \(error)")
    Log.verbose("Message: \(msg)")
}

func testEndpoint(input: String, completion: @escaping (JSON, Bool) -> ()) {
    // Create Request
    var req = URLRequest(url: URL(string: "http://testAPIRoute/\(input)")!)
    req.httpMethod = "GET"
    req.allHTTPHeaderFields = ["Content-Type": "application/json"]

    let session = URLSession.shared

    // Perform Request
    session.dataTask(with: req) {result, res, err in
        guard let result = result else {
            let json = JSON("Error: No results.")
            completion(json, true)
            return
        }

        // Convert results to a JSON object
        let json = JSON(data: result)

        completion(json, false)
        }.resume()
}

let breaker = CircuitBreaker(fallback: testFallback, command: testEndpoint)

breaker.run(commandArgs: (input : "testInput1", { data, err in
    if err {
        print(err)
    } else {
        print(data)
    }
}), fallbackArgs: (msg: "Something went wrong."))

breaker.run(commandArgs: (input : "testInput2", { data, err in
    if err {
        print(err)
    } else {
        print(data)
    }
}), fallbackArgs: (msg: "Something went wrong."))

...
```

### Advanced Usage:

*The CircuitBreaker state is based on timeouts and user defined failures.*

1. Define a fallback function with the signature `(<BreakerError, (fallbackArg1, fallbackArg2,...)>) -> Void`:
```swift
func testFallback (err: BreakerError, msg: String) {
    // The fallback will be called if the request does not return before the specified timeout
    // or if the CircuitBreaker is currently in Open state and set to fail fast.
    // Client is expected to use the fallback to do alternate processing, such as show an error page.
    Log.verbose("Error: \(error)")
    Log.verbose("Message: \(msg)")
}
```

2. Create an endpoint to circuit break:
```swift
func sum(a: Int, b: Int) -> (Int) {
    print(a + b)
    return a + b
}
```

3. Create an Invocation wrapper of the endpoint you wish to circuit break:
  * This allows the user to define and alert the CircuitBreaker of a failure
```swift
func sumWrapper(invocation: Invocation<(Int, Int), Int>) -> Int {
    let result = sum(a: invocation.args.0, b: invocation.args.1)
    if result != 7 {
        invocation.notifyFailure()
        return 0
    } else {
        invocation.notifySuccess()
        return result
    }
}
```

4. Create a CircuitBreaker instance for each endpoint you wish to circuit break:
  * Must specify the fallback function, and the endpoint to circuit break
  * Optional configurations include: timeout, resetTimeout, maxFailures, and bulkhead
```swift
let breakerAdvanced = CircuitBreaker(fallback: testCallback, commandWrapper: sumWrapper)
```

5. Invoke the call to the endpoint by calling the CircuitBreaker `run()` function and pass any arguments:
```swift
breakerAdvanced.run(commandArgs: (a: 3, b: 4), fallbackArgs: (msg: "Something went wrong."))
```

Full Implementation:

```swift
...

func testFallback (err: BreakerError, msg: String) {
    // The fallback will be called if the request does not return before the specified timeout
    // or if the CircuitBreaker is currently in Open state and set to fail fast.
    // Client is expected to use the fallback to do alternate processing, such as show an error page.
    Log.verbose("Error: \(error)")
    Log.verbose("Message: \(msg)")
}

func sum(a: Int, b: Int) -> (Int) {
    print(a + b)
    return a + b
}

func sumWrapper(invocation: Invocation<(Int, Int), Int>) -> Int {
    let result = sum(a: invocation.args.0, b: invocation.args.1)
    if result != 7 {
        invocation.notifyFailure()
        return 0
    } else {
        invocation.notifySuccess()
        return result
    }
}

let breakerAdvanced = CircuitBreaker(fallback: testCallback, commandWrapper: sumWrapper)

breakerAdvanced.run(commandArgs: (a: 3, b: 4), fallbackArgs: (msg: "Something went wrong."))

...
```

## API
### CircuitBreaker

#### Basic Usage Constructor:
```swift
CircuitBreaker(timeout: Double = 10, resetTimeout: Int = 60, maxFailures: Int = 5, bulkhead: Int = 0, callback: @escaping AnyFallback<C>, command: @escaping AnyFunction<A, B>)
```
 * `timeout` Amount in seconds that the request should complete before. Default is set to 10 seconds.
 * `resetTimeout` Amount in seconds to wait before setting to halfopen state. Default is set to 60 seconds.
 * `maxFailures` Number of failures allowed before setting state to open. Default is set to 5.
 * `bulkhead` Number of the limit of concurrent requests running at one time. Default is set to 0, which is equivalent to not using the bulkheading feature.
 * `fallback` Function user specifies to signal timeout or fastFail completion. Required format: `(BreakerError, (fallbackArg1, fallbackArg2,...)) -> Void`
 * `command` Endpoint name to circuit break.

#### Advanced Usage Constructor:
```swift
CircuitBreaker(timeout: Double = 10, resetTimeout: Int = 60, maxFailures: Int = 5, bulkhead: Int = 0, callback: @escaping AnyFallback<C>, commandWrapper: @escaping AnyFunctionWrapper<A, B>)
```
 * `timeout` Amount in seconds that the request should complete before. Default is set to 10 seconds.
 * `resetTimeout` Amount in seconds to wait before setting to halfopen state. Default is set to 60 seconds.
 * `maxFailures` Number of failures allowed before setting state to open. Default is set to 5.
 * `bulkhead` Number of the limit of concurrent requests running at one time. Default is set to 0, which is equivalent to not using the bulkheading feature.
 * `fallback` Function user specifies to signal timeout or fastFail completion. Required format: `(BreakerError, (fallbackArg1, fallbackArg2,...)) -> Void`
 * `commandWrapper` Invocation wrapper around endpoint name to circuit break, allows user defined failures.

### Stats
```swift
...
// Create CircuitBreaker
let breaker = CircuitBreaker(fallback: tesFallback, command: testEndpoint)

// Invoke breaker call
breaker.run(args: (input: "test"))

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
