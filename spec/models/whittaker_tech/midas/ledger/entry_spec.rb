# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Midas::Ledger::Entry do
  let(:customer) { TestCustomer.create! }
  let(:asset) { WhittakerTech::Midas::Ledger::Account.create!(owner: customer, kind: :asset, currency_code: 'USD') }
  let(:revenue) { WhittakerTech::Midas::Ledger::Account.create!(kind: :revenue, slug: 'revenue', currency_code: 'USD') }

  describe '.record!' do
    it 'creates a persisted, finalized entry with both postings' do
      entry = described_class.record!(
        currency_code: 'USD',
        occurred_at: Time.current,
        lines: [
          { account: asset, direction: :debit, amount: 500 },
          { account: revenue, direction: :credit, amount: 500 }
        ]
      )

      expect(entry).to be_persisted
      expect(entry).to be_finalized
      expect(entry.postings.count).to eq(2)
    end

    it 'balances debits and credits' do
      entry = described_class.record!(
        currency_code: 'USD',
        occurred_at: Time.current,
        lines: [
          { account: asset, direction: :debit, amount: 500 },
          { account: revenue, direction: :credit, amount: 500 }
        ]
      )

      expect(entry.postings.debit.sum(:currency_minor)).to eq(500)
      expect(entry.postings.credit.sum(:currency_minor)).to eq(500)
    end

    it 'attaches a real Coin (via Bankable) to each posting, matching the denormalized amount' do
      entry = described_class.record!(
        currency_code: 'USD',
        occurred_at: Time.current,
        lines: [
          { account: asset, direction: :debit, amount: 500 },
          { account: revenue, direction: :credit, amount: 500 }
        ]
      )

      posting = entry.postings.debit.first
      expect(posting.amount.currency_minor).to eq(posting.currency_minor)
      expect(posting.amount.currency_code).to eq('USD')
    end

    it 'rolls back entirely when postings do not balance' do
      expect do
        described_class.record!(
          currency_code: 'USD',
          occurred_at: Time.current,
          lines: [
            { account: asset, direction: :debit, amount: 500 },
            { account: revenue, direction: :credit, amount: 400 }
          ]
        )
      end.to raise_error(ActiveRecord::RecordInvalid)

      expect(described_class.count).to eq(0)
      expect(WhittakerTech::Midas::Ledger::Posting.count).to eq(0)
    end

    it 'rejects postings in a currency different from the entry' do
      eur_account = WhittakerTech::Midas::Ledger::Account.create!(owner: customer, kind: :asset, currency_code: 'EUR')

      expect do
        described_class.record!(
          currency_code: 'USD',
          occurred_at: Time.current,
          lines: [
            { account: asset, direction: :debit, amount: 500, currency_code: 'USD' },
            { account: eur_account, direction: :credit, amount: 500, currency_code: 'EUR' }
          ]
        )
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'rejects an account whose own currency does not match the entry' do
      eur_account = WhittakerTech::Midas::Ledger::Account.create!(owner: customer, kind: :asset, currency_code: 'EUR')

      expect do
        described_class.record!(
          currency_code: 'USD',
          occurred_at: Time.current,
          lines: [
            { account: eur_account, direction: :debit, amount: 500 },
            { account: revenue, direction: :credit, amount: 500 }
          ]
        )
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'rejects a zero-amount posting' do
      expect do
        described_class.record!(
          currency_code: 'USD',
          occurred_at: Time.current,
          lines: [
            { account: asset, direction: :debit, amount: 0 },
            { account: revenue, direction: :credit, amount: 0 }
          ]
        )
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'rejects an entry with no lines' do
      expect do
        described_class.record!(currency_code: 'USD', occurred_at: Time.current, lines: [])
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'immutability' do
    subject(:entry) do
      described_class.record!(
        currency_code: 'USD',
        occurred_at: Time.current,
        lines: [
          { account: asset, direction: :debit, amount: 500 },
          { account: revenue, direction: :credit, amount: 500 }
        ]
      )
    end

    it 'blocks updating currency_code/occurred_at/memo after creation' do
      expect { entry.update!(memo: 'edited') }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe 'the write-path bypass guard' do
    it 'refuses to add a new posting to an already-finalized entry' do
      entry = described_class.record!(
        currency_code: 'USD',
        occurred_at: Time.current,
        lines: [
          { account: asset, direction: :debit, amount: 500 },
          { account: revenue, direction: :credit, amount: 500 }
        ]
      )

      expect do
        entry.postings.create!(account: asset, direction: :debit, occurred_at: Time.current)
      end.to raise_error(WhittakerTech::Midas::Ledger::UnbalancedEntryError)
    end

    it 'refuses to destroy a posting on an already-finalized entry' do
      entry = described_class.record!(
        currency_code: 'USD',
        occurred_at: Time.current,
        lines: [
          { account: asset, direction: :debit, amount: 500 },
          { account: revenue, direction: :credit, amount: 500 }
        ]
      )

      expect { entry.postings.first.destroy! }.to raise_error(WhittakerTech::Midas::Ledger::UnbalancedEntryError)
    end

    it 'refuses to reattach a different amount to a posting on an already-finalized entry' do
      entry = described_class.record!(
        currency_code: 'USD',
        occurred_at: Time.current,
        lines: [
          { account: asset, direction: :debit, amount: 500 },
          { account: revenue, direction: :credit, amount: 500 }
        ]
      )

      expect do
        entry.postings.first.set_amount(amount: 99_999, currency_code: 'USD')
      end.to raise_error(WhittakerTech::Midas::Ledger::UnbalancedEntryError)
    end
  end
end
