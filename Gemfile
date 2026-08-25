source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in whittaker_tech-midas.gemspec.
gemspec

# CI pins the Rails version per matrix cell via RAILS_VERSION. Left unset,
# Bundler resolves whatever satisfies the gemspec's `>= 6.1` bound (currently
# the latest 8.x). Values track the gemspec's declared support window --
# keep in sync if that window changes.
#
# 6.1 exists for hellodancerrails (Rails 6.1.7.10 / Ruby 3.3.11), which adopts
# Midas for Coin. Exercised on Ruby 3.3 only -- 6.1 predates Ruby 3.4.
case ENV.fetch('RAILS_VERSION', nil)
when '6.1'
  gem 'rails', '~> 6.1.0'
  # concurrent-ruby 1.3.5 removed its implicit `require 'logger'`, which
  # ActiveSupport 6.1 depends on -- without this pin `require 'rails'` raises
  # NameError on ActiveSupport::LoggerThreadSafeLevel::Logger. Rails 7.1+
  # requires logger itself, so this is scoped to the 6.1 lane.
  gem 'concurrent-ruby', '< 1.3.5'
when '7.1'
  gem 'rails', '~> 7.1.0'
when '7.2'
  gem 'rails', '~> 7.2.0'
when '8.x'
  gem 'rails', '>= 8.0'
end

# sqlite3 2.x requires Rails 7.2+. Rails 6.1's SQLite3Adapter declares
# `gem 'sqlite3', '~> 1.4'` at load time, so the 6.1 lane must stay on 1.x.
if ENV.fetch('RAILS_VERSION', nil) == '6.1'
  gem 'sqlite3', '~> 1.4'
else
  gem 'sqlite3'
end

gem 'rubocop'
gem 'rubocop-factory_bot'
gem 'rubocop-rails'
gem 'rubocop-rspec_rails'
gem 'yard'
# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"
