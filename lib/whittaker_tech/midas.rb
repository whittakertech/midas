# frozen_string_literal: true

require 'whittaker_tech/midas/version'
require 'whittaker_tech/midas/deprecation'
require 'whittaker_tech/midas/engine'
require 'money'
require 'poly'

# WhittakerTech::Midas is a Rails engine for multi-currency monetary value
# management. It replaces scattered `*_cents` and `*_currency` columns with a
# single polymorphic `Coin` model backed by a centralized `midas_coins`
# table.
#
# ## Configuration
#
# ### Table namespace (PostgreSQL schema)
#
# By default all coins are stored in `midas_coins`. To place the table
# inside a PostgreSQL schema set `table_namespace` in an initializer:
#
#   WhittakerTech::Midas.table_namespace = 'finance'
#   # => table becomes finance.coins
#
# ### Bidirectional text
#
# Currency display direction defaults to LTR for every currency code.
# Override individual currencies as needed:
#
#   WhittakerTech::Midas.currency_directions['ILS'] = :rtl
#   WhittakerTech::Midas.currency_directions['AED'] = :rtl
#
# See also:
#
# - `Coin`
# - `Coin::Arithmetic`
# - `Bankable`
# @since 0.1.0
module WhittakerTech::Midas
  # Rounding strategies available for division operations.
  #
  # Each value is a lambda that accepts a Float and returns a rounded value.
  #
  # Rounding keys:
  #
  # - `:round`: Round half-up (standard commercial rounding)
  # - `:ceil`: Always round up (ceiling)
  # - `:floor`: Always round down (floor / truncate)
  # - `:bankers`: Round half-to-even (banker's rounding)
  #
  # @return [Hash{Symbol => Proc}]
  ROUNDING_POLICIES = {
    round: ->(v) { v.round },
    ceil: ->(v) { v.ceil },
    floor: ->(v) { v.floor },
    bankers: ->(v) { v.round(0, half: :even) }
  }.freeze

  # The rounding policy applied when no explicit policy is supplied.
  # @return [Symbol]
  DEFAULT_ROUNDING_POLICY = :round

  # Optional PostgreSQL schema name used to namespace the coins table.
  #
  # When `nil` (default) the table is created as `midas_coins`.
  # When set, the table becomes `<namespace>.coins` and requires a PostgreSQL
  # adapter.
  #
  # @return [String, nil]
  mattr_accessor :table_namespace, default: nil

  # Controls how deprecation notices are emitted.
  #
  # Allowed values:
  #
  # - `:warn`: Prints to STDERR via `Kernel.warn` (default)
  # - `:raise`: Raises `Deprecation::DeprecationError`
  # - `:silence`: Suppresses all notices
  #
  # @return [Symbol]
  mattr_accessor :deprecation_behavior, default: :warn

  # Resolves the fully-qualified table name for a given base name.
  #
  # @param name [String] base table name, e.g. `"coins"`
  # @return [String] the namespaced table name
  # @raise [RuntimeError] if `table_namespace` is set and the adapter is not PostgreSQL
  def self.table_name(name)
    return "midas_#{name}" if table_namespace.blank?

    adapter = ActiveRecord::Base.connection.adapter_name
    raise "WhittakerTech::Midas.table_namespace requires PostgreSQL (got #{adapter})" unless adapter == 'PostgreSQL'

    "#{table_namespace}.#{name}"
  end

  # Per-currency display direction map. Defaults all currencies to `:ltr`.
  #
  # Modify to configure RTL currencies in your initializer:
  #
  #   WhittakerTech::Midas.currency_directions['ILS'] = :rtl
  #
  # @return [Hash{String => Symbol}] maps uppercased ISO currency code to `:ltr` or `:rtl`
  def self.currency_directions
    @currency_directions ||= Hash.new(:ltr)
  end

  # Returns the configured display direction for the given currency code.
  #
  # Falls back to `:ltr` for any currency not explicitly configured.
  #
  # @param currency_code [String] ISO 4217 currency code, e.g. `"USD"`
  # @return [Symbol] `:ltr` or `:rtl`
  def self.currency_direction_for(currency_code)
    currency_directions[currency_code.to_s.upcase]
  end

  # Resets all mutable configuration to defaults.
  #
  # Intended for use in test suite `after` blocks when specs mutate
  # engine-level configuration.
  #
  # @return [void]
  def self.reset_configuration!
    self.table_namespace      = nil
    self.deprecation_behavior = :warn
    @currency_directions      = nil
  end
end
