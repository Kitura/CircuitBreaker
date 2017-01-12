import XCTest
@testable import CircuitBreakerTests

XCTMain([
    testCase(CircuitBreakerTests.allTests),
    testCase(StatsTests.allTests)
])
