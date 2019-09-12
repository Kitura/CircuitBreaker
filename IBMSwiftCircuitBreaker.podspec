
Pod::Spec.new do |s|
  s.name        = "IBMSwiftCircuitBreaker"
  s.version     = "5.0.3"
  s.summary     = "A Swift Circuit Breaker library"
  s.homepage    = "https://github.com/IBM-Swift/CircuitBreaker"
  s.license     = { :type => "Apache License, Version 2.0" }
  s.author     = "IBM"
  s.module_name  = 'CircuitBreaker'
  s.ios.deployment_target = "10.0"
  s.osx.deployment_target = "10.11"
  s.source   = { :git => "https://github.com/IBM-Swift/CircuitBreaker.git", :tag => s.version }
  s.source_files = "Sources/CircuitBreaker/*.swift"
  s.dependency 'LoggerAPI', '~> 1.7'
end
