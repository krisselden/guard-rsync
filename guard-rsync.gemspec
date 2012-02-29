Gem::Specification.new do |s|
  s.name        = 'guard-rsync'
  s.version     = '0.1.1'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Kris Selden']
  s.email       = ['kris.selden@gmail.com']
  s.homepage    = 'http://github.com/kselden/guard-rsync'
  s.summary     = 'Guard gem for syncing directories'
  s.description = 'Guard::Rsync automatically syncs directories.'

  s.required_rubygems_version = '>= 1.3.6'
  s.rubyforge_project = 'guard-rsync'

  s.add_dependency 'guard', '>= 0.4'
  s.add_development_dependency 'bundler',     '~> 1.0'

  s.files        = Dir.glob('{lib}/**/*') + %w[LICENSE README.md]
  s.require_path = 'lib'
end
