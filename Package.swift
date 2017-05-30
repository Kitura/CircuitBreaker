import PackageDescription

let package = Package(
  name: "CircuitBreaker",
  targets: [
    Target(name: "CircuitBreaker", dependencies: [.Target(name: "Utils")])
  ],
  dependencies: [
    .Package(url: "https://github.com/IBM-Swift/LoggerAPI.git", majorVersion: 1),
  ]
)
