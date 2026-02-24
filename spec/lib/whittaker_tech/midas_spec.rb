# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas do
  after { described_class.reset_configuration! }

  describe 'ROUNDING_POLICIES' do
    it 'has exactly four keys' do
      expect(described_class::ROUNDING_POLICIES.keys).to match_array(%i[round ceil floor bankers])
    end

    it 'all policies are callable' do
      described_class::ROUNDING_POLICIES.each_value do |policy|
        expect(policy).to respond_to(:call)
      end
    end
  end

  describe 'DEFAULT_ROUNDING_POLICY' do
    it 'equals :round' do
      expect(described_class::DEFAULT_ROUNDING_POLICY).to eq(:round)
    end
  end

  describe '.table_name' do
    let(:name) { 'coins' }

    context 'when no table_namespace is set' do
      before { described_class.table_namespace = nil }

      it 'prefixes with midas_' do
        expect(described_class.table_name(name)).to eq('midas_coins')
      end
    end

    context 'when table_namespace is set' do
      before { described_class.table_namespace = 'midas' }

      context 'when adapter is PostgreSQL' do
        before do
          allow(ActiveRecord::Base.connection)
            .to receive(:adapter_name)
            .and_return('PostgreSQL')
        end

        it 'returns a schema-qualified table name' do
          expect(described_class.table_name(name)).to eq('midas.coins')
        end
      end

      context 'when adapter is not PostgreSQL' do
        before do
          allow(ActiveRecord::Base.connection)
            .to receive(:adapter_name)
            .and_return('SQLite')
        end

        it 'raises an error' do
          expect do
            described_class.table_name(name)
          end.to raise_error(/requires PostgreSQL/)
        end
      end
    end
  end

  describe '.currency_direction_for' do
    it 'defaults to :ltr' do
      expect(described_class.currency_direction_for('USD')).to eq(:ltr)
    end

    it 'returns configured direction' do
      described_class.currency_directions['AED'] = :rtl
      expect(described_class.currency_direction_for('AED')).to eq(:rtl)
    end
  end
end
