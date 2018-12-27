$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "search/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "search"
  s.version     = Search::VERSION
  s.authors     = ["H. Gregor Molter"]
  s.email       = ["gregor.molter@secretlab.de"]
  #s.homepage    = "TODO"
  s.summary     = "A DSL for an ActiveRecord search"
  s.description = "A DSL for an ActiveRecord search."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", ">= 5.0"
  s.add_dependency 'parslet', '>= 1.8.2'

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "pry"
end
