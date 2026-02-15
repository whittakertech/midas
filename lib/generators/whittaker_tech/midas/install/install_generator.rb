# frozen_string_literal: true

class WhittakerTech::Midas::Generators::InstallGenerator < Rails::Generators::Base
  desc 'Installs Midas and copies migrations.'

  def copy_migrations
    say_status 'migrations', 'Copying migrations for Midas...', :green
    rake 'midas:install:migrations'
  end
end
