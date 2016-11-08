# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rails/sharding/version'

Gem::Specification.new do |spec|
  spec.name          = "rails-sharding"
  spec.version       = Rails::Sharding::VERSION
  spec.authors       = ["Henrique Gubert"]
  spec.email         = ["guberthenrique@hotmail.com"]

  spec.summary       = %q{Simple and robust sharding for Rails, including
    Migrations and ActiveRecord extensions}
  spec.description   = %q{This gems allows you to easily create extra databases
    to your rails application, and freely allocate ActiveRecord instances to
    any of the databases. It also provides rake tasks and migrations to help
    you manage the schema by shard groups.}
  spec.homepage      = "https://github.com/hsgubert/rails-sharding"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'rails', '~> 5.0'

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 11.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "byebug", '~> 9'
  spec.add_development_dependency "mysql2", '~> 0'
  spec.add_development_dependency "pg" # postgres driver
  spec.add_development_dependency "codeclimate-test-reporter", '~> 1'
  spec.add_development_dependency "simplecov"
end
