# frozen_string_literal: true

module WhittakerTech
  module Midas
    # The Midas Engine provides monetary value management capabilities as a Rails Engine.
    # It integrates seamlessly with Rails applications to add currency handling, coin management,
    # and monetary formatting functionality through the Bankable concern and related components.
    #
    # This engine follows Rails Engine conventions and can be mounted in any Rails application
    # to provide comprehensive monetary value handling capabilities. It includes models, helpers,
    # and utilities for working with currencies and monetary amounts.
    #
    # == Features
    #
    # - **Bankable Concern**: Allows any Active Record model to have monetary attributes
    # - **Coin Model**: Stores monetary values with currency information
    # - **Form Helpers**: View helpers for monetary input and display
    # - **Currency Management**: Integration with the Money gem for currency operations
    # - **Namespace Isolation**: Clean separation from host application code
    #
    # == Installation and Setup
    #
    # Add the engine to your Rails application's Gemfile and run bundle install.
    # The engine will automatically configure itself when Rails boots.
    #
    # @example Adding to a Rails application
    #   # In your Gemfile
    #   gem 'whittaker_tech-midas'
    #
    #   # The engine auto-configures on Rails boot
    #   # No additional setup required
    #
    # == Usage in Host Applications
    #
    # Once installed, the engine's functionality becomes available throughout
    # your Rails application:
    #
    # @example Using Bankable in models
    #   class Product < ApplicationRecord
    #     include WhittakerTech::Midas::Bankable
    #     has_coin :price
    #   end
    #
    # @example Using form helpers in views
    #   <%= form_with model: @product do |form| %>
    #     <%= form.money_field :price %>
    #   <% end %>
    #
    # == Configuration
    #
    # The engine provides several configuration points:
    #
    # - **Eager Loading**: Automatically configures model loading paths
    # - **Helper Integration**: Injects form helpers into ActionView
    # - **Namespace Isolation**: Keeps engine code separate from host application
    #
    # == Directory Structure
    #
    # The engine follows standard Rails Engine structure:
    # - `app/models/`: Coin model and concerns
    # - `app/helpers/`: Form helpers for monetary inputs
    # - `db/migrate/`: Database migrations for coin storage
    # - `lib/`: Engine configuration and initialization
    #
    # == Database Integration
    #
    # The engine provides database migrations that create the necessary tables
    # for storing monetary values. Run migrations after installation:
    #
    # @example Running migrations
    #   rails db:migrate
    #
    # == Namespace Isolation
    #
    # The engine uses `isolate_namespace` to prevent conflicts with host
    # application code. All engine components are properly namespaced under
    # `WhittakerTech::Midas`.
    #
    # == Helper Integration
    #
    # Form helpers are automatically made available in all views through
    # an initializer that extends ActionView::Base when the view layer loads.
    # This provides seamless integration without requiring manual includes.
    #
    # == Eager Loading
    #
    # The engine configures additional eager load paths to ensure all models
    # are properly loaded in production environments. This includes the models
    # directory which contains the Coin model and Bankable concern.
    #
    # == Thread Safety
    #
    # The engine follows Rails conventions for thread safety and can be safely
    # used in multi-threaded environments like Puma or Falcon.
    #
    # == Development and Testing
    #
    # The engine can be developed and tested independently using its own
    # test suite, or integrated into a host application for testing.
    #
    # @see WhittakerTech::Midas::Bankable
    # @see WhittakerTech::Midas::Coin
    # @see WhittakerTech::Midas::FormHelper
    # @since 0.1.0
    class Engine < ::Rails::Engine
      isolate_namespace WhittakerTech::Midas

      config.eager_load_paths += Dir["#{config.root}/app/models"]

      initializer 'midas.helpers' do
        ActiveSupport.on_load(:action_view) do
          include WhittakerTech::Midas::FormHelper
        end
      end
    end
  end
end
