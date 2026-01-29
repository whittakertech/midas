# frozen_string_literal: true

require 'whittaker_tech/midas'

class CreateWhittakerTechSchema < ActiveRecord::Migration[8.0]
  SCHEMA_NAME = (WhittakerTech::Midas.table_namespace || 'wt_midas').freeze
  raise 'Invalid schema name' unless SCHEMA_NAME =~ /\A[a-z_][a-z0-9_]*\z/

  def up
    return unless postgresql?

    execute "CREATE SCHEMA IF NOT EXISTS #{SCHEMA_NAME}"
  end

  def down
    return unless postgresql?

    execute "DROP SCHEMA #{SCHEMA_NAME} CASCADE"
  end

  private

  def postgresql?
    connection.adapter_name == 'PostgreSQL'
  end
end
