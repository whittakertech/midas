# frozen_string_literal: true

namespace :midas do
  namespace :install do
    desc 'Copy Midas migrations to your application.'
    task migrations: :environment do
      engine = WhittakerTech::Midas::Engine
      source = engine.root.join('db/migrate')
      destination = Rails.root.join('db/migrate')

      FileUtils.mkdir_p(destination)

      Dir.glob(source.join('*.rb')).each_with_index do |migration, i|
        filename = File.basename(migration)
        timestamp = (Time.now.utc + i).strftime('%Y%m%d%H%M%S')
        target = destination.join("#{timestamp}_#{filename}")

        if File.exist?(target)
          puts "Skipping #{filename} because it already exists."
        else
          FileUtils.cp migration, target
          puts "Copied #{filename} to #{target}."
        end
      end
    end
  end
end
