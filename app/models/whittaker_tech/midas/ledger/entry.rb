# frozen_string_literal: true

# Ledger::Entry is a balanced double-entry transaction: a group of Postings
# (debits and credits) that must sum to zero within a single currency.
#
# `Ledger::Entry.record!` is the only sanctioned way to create an Entry —
# see its documentation for why. Entries (and their Postings) are immutable
# once finalized.
#
# @since 0.4.0
class WhittakerTech::Midas::Ledger::Entry < WhittakerTech::Midas::ApplicationRecord
  self.table_name = WhittakerTech::Midas.table_name('ledger_entries')

  belongs_to :source, polymorphic: true, optional: true

  has_many :postings,
           class_name: 'WhittakerTech::Midas::Ledger::Posting',
           dependent: :restrict_with_error,
           inverse_of: :entry

  before_validation :normalize_currency_code

  validates :currency_code, presence: true, length: { is: 3 }
  validates :occurred_at, presence: true

  # These only run meaningfully in the :finalize context (see `finalize!`)
  # — at initial `create!` time postings don't exist yet (Coin's FK
  # requires a persisted Posting before it can attach, which in turn
  # requires a persisted Entry — see `record!`), so validating balance at
  # `:create` would either see zero postings or incomplete data. This is
  # also why amount-positivity and per-posting currency-match checks live
  # here rather than on Posting itself — by finalize time every Posting's
  # Coin actually exists.
  validate :postings_balance, on: :finalize
  validate :postings_single_currency, on: :finalize
  validate :postings_amounts_positive, on: :finalize
  validate :postings_present, on: :finalize

  before_update :block_updates

  class << self
    # The only sanctioned way to build a balanced Entry. Constructs the
    # Entry, then each Posting, then each Posting's Coin, sequentially
    # (required by Coin's own FK — see WhittakerTech::Midas::Coin::Converter
    # for the identical Exchange precedent), all inside one transaction —
    # then finalizes the Entry, which validates the fully-persisted result
    # actually balances before stamping it immutable-and-closed. Any
    # failure (unbalanced, mixed currency, invalid line) rolls the whole
    # transaction back — nothing partial is ever left behind.
    #
    # @param currency_code [String] ISO 4217 currency code for the entry
    # @param occurred_at [Time] business-meaningful time of the transaction
    # @param lines [Array<Hash>] each a `{account:, direction:, amount:,
    #   currency_code: (optional, defaults to the entry's)}` hash
    # @param source [ActiveRecord::Base, nil] optional polymorphic source
    #   (an Invoice, a webhook event, a reclassification's original Entry)
    # @param memo [String, nil]
    # @return [Entry] the persisted, finalized Entry
    # @raise [ActiveRecord::RecordInvalid] if any line or the final balance
    #   check fails
    def record!(currency_code:, occurred_at:, lines:, source: nil, memo: nil)
      iso = currency_code.to_s.strip.upcase

      transaction do
        entry = create!(currency_code: iso, occurred_at:, source:, memo:)

        lines.each do |line|
          posting = entry.postings.create!(
            account: line.fetch(:account),
            direction: line.fetch(:direction),
            occurred_at: line[:occurred_at] || occurred_at
          )
          posting.set_amount(amount: line.fetch(:amount), currency_code: line[:currency_code] || iso)
        end

        entry.send(:finalize!)
        entry
      end
    end
  end

  # @return [Boolean] whether this Entry has completed construction —
  #   Postings may only be added/removed while an Entry is not yet
  #   finalized (i.e. during `record!`'s own construction).
  def finalized?
    finalized_at.present?
  end

  private

  # Reloads postings fresh from the DB (so amounts attached via `set_amount`
  # after each Posting's own creation are visible), re-validates balance
  # and currency consistency in the :finalize context, and — only if
  # valid — stamps `finalized_at` via `update_column` (deliberately
  # bypassing `block_updates`, since this is the one sanctioned internal
  # state transition, not an external mutation).
  def finalize!
    postings.reload
    raise ActiveRecord::RecordInvalid, self unless valid?(:finalize)

    update_column(:finalized_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  # Only checks non-empty, not "at least one debit and one credit" — the
  # balance and positive-amount checks together already rule out a
  # one-sided entry (a lone debit or lone credit can never balance against
  # nothing), so this doesn't need to duplicate that logic.
  def postings_present
    errors.add(:base, 'an entry must have at least one posting') if postings.empty?
  end

  def postings_balance
    debits = postings.debit.sum(:currency_minor)
    credits = postings.credit.sum(:currency_minor)
    errors.add(:base, "postings do not balance (#{debits} debit vs #{credits} credit)") if debits != credits
  end

  def postings_single_currency
    coin_table = WhittakerTech::Midas::Coin.table_name
    mismatched = postings.joins(:amount_coin).where.not(coin_table => { currency_code: currency_code }).exists?
    errors.add(:base, 'all postings must share the entry currency_code') if mismatched
  end

  def postings_amounts_positive
    missing = postings.where('currency_minor IS NULL OR currency_minor <= 0').exists?
    errors.add(:base, 'all postings must have a positive amount') if missing
  end

  def normalize_currency_code
    self.currency_code = currency_code.to_s.strip.upcase.presence if currency_code
  end

  def block_updates
    raise ActiveRecord::ReadOnlyRecord, 'WhittakerTech::Midas::Ledger::Entry records are immutable after creation'
  end
end
