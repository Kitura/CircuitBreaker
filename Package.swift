import PackageDescription

let package = Package(
    name: "CircuitBreaker",
    dependencies: [
        .Package(url: "https://github.com/mxcl/PromiseKit", majorVersion: 4)
    ]
)
