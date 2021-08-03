# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'airrecord/version'

Gem::Specification.new do |spec|
  spec.name          = "airrecord"
  spec.version       = Airrecord::VERSION
  spec.authors       = ["Simon Eskildsen"]
  spec.email         = ["sirup@sirupsen.com"]

  spec.summary       = %q{Airtable client}
  spec.description   = %q{Airtable client to make Airtable interactions a breeze}
  spec.homepage      = "https://github.com/sirupsen/airrecord"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.2"

  spec.add_dependency "faraday", [">= 0.10", "< 2.0"]
  spec.add_dependency "net-http-persistent"

  spec.add_development_dependency "bundler", "~> 2"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 10.0"
end
