require 'bundler/setup'

APP_RAKEFILE = File.expand_path('spec/dummy/Rakefile', __dir__)
load 'rails/tasks/engine.rake'

load 'rails/tasks/statistics.rake'

require 'bundler/gem_tasks'

require 'yard'
namespace :docs do
  # yard-markdown also emits every project-level .md (README, CLAUDE.md, ...)
  # and any vendored files as "extra files"; only the class reference belongs
  # under /api/.
  YARD::Rake::YardocTask.new(:api) do |t|
    t.options = ['--yardopts', '.yardopts']
    t.after = lambda do
      keep = %w[.keep WhittakerTech WhittakerTech.md]
      Dir.children('docs/api').each do |name|
        FileUtils.rm_rf(File.join('docs/api', name)) unless keep.include?(name)
      end
    end
  end
end
