import PackageDescription

let package = Package(
    name: "CircuitBreaker",
    dependencies: [
	.Package(url: "https://github.com/IBM-Swift/HeliumLogger.git", majorVersion: 1, minor: 4),
    ]
)
