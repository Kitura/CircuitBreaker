![Build Status](https://travis-ci.com/IBM-Swift/CircuitBreaker.svg?token=zkW1banusRzgHu6HwJiN&branch=master)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)

# CircuitBreaker

## Swift version
The latest version of CircuitBreaker works with the `3.0.2` version of the Swift binaries. You can download this version of the Swift binaries by following this [link](https://swift.org/download/#releases).

## Usage
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

 Basic CircuitBreaker example:

 ```swift
 ...

// Define a callback function with the signature (err: Bool) -> Void
func testCallback (err: Bool) {
    // The callback will return true if the request does not return before the specified timeout
    // or if the CircuitBreaker is currently in Open state and set to fail fast
    if !err {
        print("Successful request.")
        return
    }

    print("Something went wrong, request timed out!")
}

// Test REST endpoint to circuit break
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

// Create a CircuitBreaker instant for each endpoint to circuit break
// Must specify the callback function, and the endpoint to circuit break
// Optional configurations include: timeout, resetTimeout, and maxFailures
let breaker = CircuitBreaker(callback: testCallback) {
    testEndpoint(input: "testInput") { data, error in
        print("Results: \(data)")
        print("Error: \(error)")
    }
}

// Invoke the call to the endpoint by calling the CircuitBreaker run() function
breaker.run()

...
```
## API
### CircuitBreaker
```swift
CircuitBreaker(timeout: Double = 10, resetTimeout: Int = 60, maxFailures: Int = 5, callback: @escaping (_ error: Bool) -> Void, selector: @escaping () -> Void))
```
 * `timeout` Amount in seconds that the request should complete before. Default is set to 10 seconds.
 * `resetTimeout` Amount in seconds to wait before setting to halfopen state. Default is set to 60 seconds.
 * `maxFailures` Number of failures allowed before setting state to open. Default is set to 5.
 * `callback` Function user specifies to signal completion. Required format: `(error: Bool) -> Void`
 * `selector` Endpoint to circuit break.

### CircuitBreaker Stats
```swift
...
// Create CircuitBreaker
let breaker = CircuitBreaker(callback: testCallback) { data, error in
    print("Results: \(data)")
    print("Error: \(error)")
}

// Invoke breaker call
breaker.run()

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
