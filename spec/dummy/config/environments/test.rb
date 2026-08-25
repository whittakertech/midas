require "active_support/core_ext/integer/time"

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # While tests run files are not watched, reloading is not necessary.
  # `enable_reloading` replaced `cache_classes` in Rails 7.1; the 6.1 matrix
  # lane still needs the old name.
  if config.respond_to?(:enable_reloading=)
    config.enable_reloading = false
  else
    config.cache_classes = true
  end

  # Eager loading loads your entire application. When running a single test locally,
  # this is usually not necessary, and can slow down your test suite. However, it's
  # recommended that you enable it in continuous integration systems to ensure eager
  # loading is working properly before deploying your code.
  config.eager_load = ENV["CI"].present?

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{1.hour.to_i}"
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Render exception templates for rescuable exceptions and raise for other exceptions.
  # Rails 7.1 changed this from a boolean to a symbol; 6.1 only understands
  # the boolean, where `false` is the equivalent of `:rescuable` here.
  config.action_dispatch.show_exceptions =
    Rails::VERSION::STRING >= '7.1' ? :rescuable : false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Raise error when a before_action's only/except options reference missing actions
  # (Rails 7.1+; the option does not exist on the 6.1 lane). Guarded on the
  # Rails version rather than `respond_to?`: `config.action_controller` is an
  # OrderedOptions that accepts any setter via method_missing, so the failure
  # would otherwise surface later, when the railtie applies the recorded
  # option to ActionController::Base.
  if Rails::VERSION::STRING >= '7.1'
    config.action_controller.raise_on_missing_callback_actions = true
  end
end
