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
 
 var result = 0
 
 // Function to circuit break
 func sum(a: Int, b: Int) -> Int {
     return a + b
 }
 
 // Callback to signal completion
 func callback () -> Void {
     print("Done.")
 }
 
 // Create CircuitBreaker for sum() function
 let breaker = CircuitBreaker(timeout: 10.0, resetTimeout: 10, maxFailures: 2, callback: callback) {
     result = sum(a: 10, b: 3)
 }
 
 // Run your function in the CircuitBreaker
 breaker.run()
 
...
```
## API
*Coming soon...*

## CircuitBreaker Stats
*Coming soon...*

## License
This Swift package is licensed under Apache 2.0. Full license text is available in [LICENSE](LICENSE).
