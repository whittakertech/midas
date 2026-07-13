# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas::Ledger::Account do
  let(:customer) { TestCustomer.create! }

  describe 'validations' do
    it { should validate_presence_of(:currency_code) }

    it 'requires a slug for system (owner-less) accounts' do
      account = described_class.new(kind: :suspense, currency_code: 'USD')
      expect(account).not_to be_valid
      expect(account.errors[:slug]).to be_present
    end

    it 'does not require a slug for owned accounts' do
      account = described_class.new(owner: customer, kind: :asset, currency_code: 'USD')
      expect(account).to be_valid
    end

    it 'enforces uniqueness per (owner, kind, currency) for owned accounts' do
      described_class.create!(owner: customer, kind: :asset, currency_code: 'USD')
      dup = described_class.new(owner: customer, kind: :asset, currency_code: 'USD')
      expect(dup).not_to be_valid
    end

    it 'allows the same kind for the same owner in a different currency' do
      described_class.create!(owner: customer, kind: :asset, currency_code: 'USD')
      other = described_class.new(owner: customer, kind: :asset, currency_code: 'EUR')
      expect(other).to be_valid
    end

    it 'enforces uniqueness per (slug, currency) for system accounts' do
      described_class.create!(kind: :suspense, slug: 'suspense', currency_code: 'USD')
      dup = described_class.new(kind: :suspense, slug: 'suspense', currency_code: 'USD')
      expect(dup).not_to be_valid
    end

    it 'allows two system accounts of the same kind with different slugs' do
      described_class.create!(kind: :revenue, slug: 'platform-revenue', currency_code: 'USD')
      other = described_class.new(kind: :revenue, slug: 'fees-revenue', currency_code: 'USD')
      expect(other).to be_valid
    end
  end

  describe '.suspense_for' do
    it 'creates the suspense account for a currency' do
      account = described_class.suspense_for('usd')
      expect(account).to be_suspense
      expect(account.currency_code).to eq('USD')
      expect(account.owner).to be_nil
    end

    it 'is idempotent — repeated calls return the same account' do
      first = described_class.suspense_for('USD')
      second = described_class.suspense_for('USD')
      expect(second.id).to eq(first.id)
    end

    it 'keeps suspense accounts separate per currency' do
      usd = described_class.suspense_for('USD')
      eur = described_class.suspense_for('EUR')
      expect(usd.id).not_to eq(eur.id)
    end
  end

  describe '#balance' do
    it 'is zero with no postings' do
      account = described_class.create!(owner: customer, kind: :asset, currency_code: 'USD')
      expect(account.balance).to eq(0)
    end

    it 'reflects debits minus credits' do
      asset = described_class.create!(owner: customer, kind: :asset, currency_code: 'USD')
      revenue = described_class.create!(kind: :revenue, slug: 'revenue', currency_code: 'USD')

      WhittakerTech::Midas::Ledger::Entry.record!(
        currency_code: 'USD',
        occurred_at: Time.current,
        lines: [
          { account: asset, direction: :debit, amount: 1000 },
          { account: revenue, direction: :credit, amount: 1000 }
        ]
      )

      expect(asset.balance).to eq(1000)
      expect(revenue.balance).to eq(-1000)
    end

    it 'ignores postings on an entry that was never finalized' do
      asset = described_class.create!(owner: customer, kind: :asset, currency_code: 'USD')
      entry = WhittakerTech::Midas::Ledger::Entry.create!(currency_code: 'USD', occurred_at: Time.current)
      entry.postings.create!(account: asset, direction: :debit, occurred_at: Time.current)

      expect(asset.balance).to eq(0)
    end
  end
end
