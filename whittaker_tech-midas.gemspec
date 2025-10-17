# frozen_string_literal: true

require_relative 'lib/whittaker_tech/midas/version'

Gem::Specification.new do |spec|
  spec.name        = 'whittaker_tech-midas'
  spec.version     = WhittakerTech::Midas::VERSION
  spec.authors     = ['Lee Whittaker']
  spec.email       = ['lee@whittakertech.com']
  spec.homepage    = 'https://github.com/whittaker-tech/midas'
  spec.summary     = 'Multi-currency money management for Rails with polymorphic coin storage'
  spec.description = <<~DESC
    WhittakerTech Midas is a Rails engine that provides elegant multi-currency support 
    through a single polymorphic Coin model. Instead of adding price_cents/price_currency 
    columns to every model, Midas stores all monetary values in one place with a simple 
    has_coins DSL. Includes bank-style currency input fields powered by Stimulus.
  DESC
  spec.license = 'MIT'

  spec.metadata = {
    'homepage_uri'      => spec.homepage,
    'source_code_uri'   => 'https://github.com/whittakertech/midas',
    'changelog_uri'     => 'https://github.com/whittakertech/midas/blob/main/CHANGELOG.md',
    'bug_tracker_uri'   => 'https://github.com/whittakertech/midas/issues',
    'documentation_uri' => 'https://github.com/whittakertech/midas/blob/main/README.md',
    'rubygems_mfa_required' => 'true'
  }

  spec.required_ruby_version = '>= 3.4.0'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'money', '~> 6.19.0'
  spec.add_dependency 'rails', '>= 7.1.5.2'

  spec.add_development_dependency 'factory_bot_rails', '~> 6.4'
  spec.add_development_dependency 'pg', '~> 1.5'
  spec.add_development_dependency 'puma', '~> 6.0'
  spec.add_development_dependency 'rspec-rails', '~> 7.0'
  spec.add_development_dependency 'shoulda-matchers', '~> 6.5'
  spec.add_development_dependency 'simplecov', '~> 0.22'
  spec.add_development_dependency 'simplecov-console', '~> 0.9'
  spec.add_development_dependency 'sprockets-rails', '~> 3.5'
end
