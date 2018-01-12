lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "pg/doc/version"

Gem::Specification.new do |gem|
  gem.name          = "pg-doc"
  gem.version       = PG::Doc::VERSION
  gem.authors       = ["Kenaniah Cerny"]
  gem.email         = ["kenaniah@gmail.com"]
  gem.license       = "MIT"

  gem.summary       = "Automatic documentation for your PostgreSQL database"
  gem.homepage      = "https://github.com/kenaniah/pg-doc"

  gem.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  gem.bindir        = "exe"
  gem.executables   = gem.files.grep(%r{^exe/}) { |f| File.basename(f) }
  gem.require_paths = ["lib"]

  gem.add_development_dependency "bundler", "~> 1.16"
  gem.add_development_dependency "rake", "~> 10.0"
  gem.add_development_dependency "appraisal"
  gem.add_development_dependency "minitest"

  gem.add_dependency "pg"
end
