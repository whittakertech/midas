# frozen_string_literal: true

require 'whittaker_tech/midas/version'
require 'whittaker_tech/midas/engine'
require 'money'

module WhittakerTech::Midas
  ROUNDING_POLICIES = {
    round: ->(v) { v.round },
    ceil: ->(v) { v.ceil },
    floor: ->(v) { v.floor },
    bankers: ->(v) { v.round(0, half: :even) }
  }.freeze

  DEFAULT_ROUNDING_POLICY = :round

  mattr_accessor :table_namespace, default: nil

  def self.table_name(name)
    return "wt_midas_#{name}" if table_namespace.blank?

    adapter = ActiveRecord::Base.connection.adapter_name
    raise "WhittakerTech::Midas.table_namespace requires PostgreSQL (got #{adapter})" unless adapter == 'PostgreSQL'

    "#{table_namespace}.#{name}"
  end

  # Defaults to LTR; override per-currency as needed.
  # NOTE: Most currencies are displayed LTR even in RTL locales, but some systems
  # treat specific currency formats as RTL in fully RTL UIs. Keep this configurable.
  def self.currency_directions
    @currency_directions ||= Hash.new(:ltr)
  end

  def self.currency_direction_for(currency_code)
    currency_directions[currency_code.to_s.upcase]
  end
end
