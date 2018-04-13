
Pod::Spec.new do |s|
  s.name        = "CircuitBreaker"
  s.version     = "5.0.1"
  s.summary     = "A Swift Circuit Breaker library – Improves application stability and reliability."
  s.homepage    = "https://github.com/IBM-Swift/CircuitBreaker"
  s.license     = { :type => "Apache License, Version 2.0" }
  s.author     = "IBM"
  s.module_name  = 'CircuitBreaker'
  s.requires_arc = true
  s.osx.deployment_target = "10.11"
  s.ios.deployment_target = "10.0"
  s.tvos.deployment_target = "10.0"
  s.source   = { :git => "https://github.com/IBM-Swift/CircuitBreaker.git", :tag => s.version }
  s.source_files = "Sources/CircuitBreaker/*.swift"
  s.pod_target_xcconfig =  {
        'SWIFT_VERSION' => '4.0.3',
  }
end