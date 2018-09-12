<p align="center">
    <a href="http://kitura.io/">
        <img src="https://raw.githubusercontent.com/IBM-Swift/Kitura/master/Sources/Kitura/resources/kitura-bird.svg?sanitize=true" height="100" alt="Kitura">
    </a>
</p>

<p align="center">
    <a href="https://ibm-swift.github.io/CircuitBreaker/index.html">
    <img src="https://img.shields.io/badge/apidoc-CircuitBreaker-1FBCE4.svg?style=flat" alt="APIDoc">
    </a>
    <a href="https://travis-ci.org/IBM-Swift/CircuitBreaker">
    <img src="https://travis-ci.org/IBM-Swift/CircuitBreaker.svg?branch=master" alt="Build Status - Master">
    </a>
    <img src="https://img.shields.io/badge/os-macOS-green.svg?style=flat" alt="macOS">
    <img src="https://img.shields.io/badge/os-linux-green.svg?style=flat" alt="Linux">
    <img src="https://img.shields.io/badge/license-Apache2-blue.svg?style=flat" alt="Apache 2">
    <a href="http://swift-at-ibm-slack.mybluemix.net/">
    <img src="http://swift-at-ibm-slack.mybluemix.net/badge.svg" alt="Slack Status">
    </a>
</p>

# CircuitBreaker
The Circuit Breaker design pattern is used to increase application stability, improve response times and prevent the application from making constant failing requests. This library provides the tools needed to bring Circuit Breaker logic to your Swift applications.

![Circuit Breaker Diagram](resources/circuitBreakerDiagram.png)

## Swift version
The latest version of CircuitBreaker works with the `4.1.2` and newer version of the Swift binaries. You can download this version of the Swift binaries by following this [link](https://swift.org/download/#releases).

## Getting Started

Add `CircuitBreaker` to the dependencies within your application's `Package.swift` file. Substitute `"x.x.x"` with the latest `CircuitBreaker` [release](https://github.com/IBM-Swift/CircuitBreaker/releases).

```swift
.package(url: "https://github.com/IBM-Swift/CircuitBreaker.git", from: "x.x.x")
```
Add `CircuitBreaker` to your target's dependencies:

```Swift
.target(name: "example", dependencies: ["CircuitBreaker"]),
```

Import the package inside your application:

```swift
import CircuitBreaker
```

### Usage

The CircuitBreaker state is based on timeouts and user defined failures (quite useful when the function you are circuit breaking makes an asynchronous call). To use the CircuitBreaker in your application code you need to do the following:

- Define a fallback function with the signature `(BreakerError, (fallbackArg1, fallbackArg2, ...)) -> Void`:

```swift
func myFallback(err: BreakerError, msg: String) {
    // The fallback will be called if one of the below occurs:
    //  1. The request does not return before the specified timeout
    //  2. CircuitBreaker is currently in Open state and set to fail fast.
    //  3. There was an error in the user's called context function (networking error, etc.)
    Log.verbose("Error: \(err)")
    Log.verbose("Message: \(msg)")
}
```

- Extend BreakerError by defining your own error handling to be used in your context function:

```swift
extension BreakerError {
    public static let encodingURLError = BreakerError(reason: "URL could not be created")
    public static let networkingError = BreakerError(reason: "There was an error, while sending the request")
    public static let jsonDecodingError = BreakerError(reason: "Could not decode result into JSON")
}
```

- Create a context function for the logic you intend to circuit break (this allows you to alert the CircuitBreaker of a failure or a success). A context function receives an `Invocation` object as its parameter. An instance of the `Invocation` class states:
    - The parameter types that must be passed to the context function.
    - The return type from the execution of the context function.
    - The parameter type used as the second argument for the fallback closure.

```swift
func myContextFunction(invocation: Invocation<(String), String>) {
  let requestParam = invocation.commandArgs
  // Create HTTP request
  guard let url = URL(string: "http://myserver.net/path/\(requestParam)") else {
    // Something went wrong

    invocation.notifyFailure(error: .encodingURLError)
    return
  }

  var req = URLRequest(url: url)
  req.httpMethod = "GET"
  let session = URLSession.shared

  // Perform the request
  session.dataTask(with: req) { result, res, err in
    guard let result = result else {
      // Failed getting a result from the server

      invocation.notifyFailure(error: .networkingError)
      return
    }

    // Convert results to a JSON object
    guard let json = (try? JSONSerialization.jsonObject(with: result, options: [])) as? [String: Any] else {
      invocation.notifyFailure(error: .jsonDecodingError)
      return
    }
    // Process JSON data

    invocation.notifySuccess()
  }.resume()
}
```

- Create a CircuitBreaker instance for each context function (e.g. endpoint) you wish to circuit break. The CircuitBreaker instance must specify a name for the circuit breaker, the endpoint to circuit break and the fallback function. Optional configurations include: group, timeout, resetTimeout, maxFailures, rollingWindow and bulkhead, for further details about these configuration options see the [API reference](https://ibm-swift.github.io/CircuitBreaker/index.html).

```swift
let breaker = CircuitBreaker(name: "Circuit1", command: myContextFunction, fallback: myFallback)
```

- Invoke the call to the endpoint by calling the CircuitBreaker `run()` method. You should pass the corresponding arguments for the context command and fallback closures. In this sample, `myContextFunction` takes a string as its parameter while `myFallback` takes a string as its second parameter:

```swift
let requestParam: String = "myRequestParams"
breaker.run(commandArgs: requestParam, fallbackArgs: "Something went wrong.")
```

#### Full Implementation

```swift
extension BreakerError {
    public static let encodingURLError = BreakerError(reason: "URL could not be created")
    public static let networkingError = BreakerError(reason: "There was an error, while sending the request")
    public static let jsonDecodingError = BreakerError(reason: "Could not decode result into JSON")
}

func myFallback(err: BreakerError, msg: String) {
    // The fallback will be called if one of the below occurs:
    //  1. The request does not return before the specified timeout
    //  2. CircuitBreaker is currently in Open state and set to fail fast.
    //  3. There was an error in the user's called context function (networking error, etc.)
    Log.verbose("Error: \(err)")
    Log.verbose("Message: \(msg)")
}

func myContextFunction(invocation: Invocation<(String), String>) {
  let requestParam = invocation.commandArgs
  // Create HTTP request
  guard let url = URL(string: "http://mysever.net/path/\(requestParam)") else {
    // Something went wrong...

    invocation.notifyFailure(error: .encodingURLError)
  }

  var req = URLRequest(url: url)
  req.httpMethod = "GET"
  let session = URLSession.shared

  // Perform Request
  session.dataTask(with: req) { result, res, err in
    guard let result = result else {
      // Failed getting a result from the server

      invocation.notifyFailure(error: .networkingError)
      return
    }

    // Convert results to a JSON object
    guard let json = (try? JSONSerialization.jsonObject(with: result, options: [])) as? [String: Any] else {
        invocation.notifyFailure(error: .jsonDecodingError)
        return
    }
    // Process JSON data

    invocation.notifySuccess()
  }.resume()
}

let breaker = CircuitBreaker(name: "Circuit1", command: myContextFunction, fallback: myFallback)

let requestParam: String = "myRequestParams"
breaker.run(commandArgs: requestParam, fallbackArgs: "Something went wrong.")
```

#### Statistics

The following statistics will be tracked for the CircuitBreaker instance:

##### Tracked Statistics
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

The example code below shows how to log a snapshot of the statistics and how to create
 a Hystrix compliant snapshot.

```swift
// Create CircuitBreaker
let breaker = CircuitBreaker(name: "Circuit1", command: myFunction, fallback: myFallback)

// Invoke breaker call
breaker.run(commandArgs: (a: 10, b: 20), fallbackArgs: "Something went wrong.")

// Log statistics snapshot
breaker.logSnapshot()

// Hystrix compliant snapshot
let snapshot = breaker.snapshot
```

#### Observing statistics
The CircuitBreaker library provides an interface for observing new CircuitBreaker instances in order to register and track statistics changes. In the initialization of a CircuitBreaker instance, the linked monitors are notified of its instantiation allowing them to begin tracking the instance's statistics. The CircuitBreaker instance exposes a Hystrix compliant statistics snapshot to the monitor which can then be processed accordingly.  See the API documentation for more information.

## API Documentation
For more information visit our [API reference](https://ibm-swift.github.io/CircuitBreaker/index.html).

## Community
We love to talk server-side Swift, and Kitura. Join our [Slack](http://swift-at-ibm-slack.mybluemix.net/) to meet the team!

## License
This Swift package is licensed under Apache 2.0. Full license text is available in [LICENSE](https://github.com/IBM-Swift/CircuitBreaker/blob/master/LICENSE).
