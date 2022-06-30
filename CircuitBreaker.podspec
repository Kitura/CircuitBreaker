
Pod::Spec.new do |s|
  s.name        = "CircuitBreaker"
  s.version     = "5.1.0"
  s.summary     = "A Swift Circuit Breaker library"
  s.homepage    = "https://github.com/Kitura/CircuitBreaker"
  s.license     = { :type => "Apache License, Version 2.0" }
  s.author     = "IBM and the Kitura project authors"
  s.module_name  = 'CircuitBreaker'
  s.swift_version = '5.1'
  s.ios.deployment_target = "10.0"
  s.osx.deployment_target = "10.11"
  s.source   = { :git => "https://github.com/Kitura/CircuitBreaker.git", :tag => s.version }
  s.source_files = "Sources/CircuitBreaker/*.swift"
  s.dependency 'LoggerAPI', '~> 1.9'
end
