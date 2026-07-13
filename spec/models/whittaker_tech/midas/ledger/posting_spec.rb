# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas::Ledger::Posting do
  let(:customer) { TestCustomer.create! }
  let(:asset) { WhittakerTech::Midas::Ledger::Account.create!(owner: customer, kind: :asset, currency_code: 'USD') }
  let(:revenue) { WhittakerTech::Midas::Ledger::Account.create!(kind: :revenue, slug: 'revenue', currency_code: 'USD') }
  let(:entry) do
    WhittakerTech::Midas::Ledger::Entry.record!(
      currency_code: 'USD',
      occurred_at: Time.current,
      lines: [
        { account: asset, direction: :debit, amount: 500 },
        { account: revenue, direction: :credit, amount: 500 }
      ]
    )
  end

  describe 'validations' do
    it 'rejects an account whose currency differs from the entry, before finalization' do
      eur_account = WhittakerTech::Midas::Ledger::Account.create!(owner: customer, kind: :asset, currency_code: 'EUR')
      unfinalized_entry = WhittakerTech::Midas::Ledger::Entry.create!(currency_code: 'USD', occurred_at: Time.current)

      posting = unfinalized_entry.postings.build(account: eur_account, direction: :debit, occurred_at: Time.current)

      expect(posting).not_to be_valid
      expect(posting.errors[:account]).to be_present
    end
  end

  describe '#set_amount' do
    it 'attaches a real Coin' do
      posting = entry.postings.debit.first
      expect(posting.amount).to be_a(WhittakerTech::Midas::Coin)
      expect(posting.amount_format).to eq('$5.00')
    end

    it 'keeps the denormalized currency_minor in sync with the Coin' do
      posting = entry.postings.debit.first
      expect(posting.currency_minor).to eq(500)
      expect(posting.amount.currency_minor).to eq(500)
    end
  end

  describe 'immutability' do
    it 'blocks updating direction/account after creation' do
      posting = entry.postings.debit.first
      expect { posting.update!(direction: :credit) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end
end
