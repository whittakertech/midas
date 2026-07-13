# frozen_string_literal: true

# Ledger::Account is a chart-of-accounts entry for Midas's double-entry
# ledger. An Account is either a system account (no owner — e.g. a
# per-currency suspense or platform-revenue account) or an owned account
# (belongs polymorphically to some domain resource, e.g. a Customer or
# Organization).
#
# Accounts are additive to Coin/Bankable, not a replacement — most Midas
# consumers should keep using `has_coin`/`has_coins` for simple stored
# values. Ledger::Account exists for models that need a full double-entry
# audit trail.
#
# @since 0.4.0
class WhittakerTech::Midas::Ledger::Account < WhittakerTech::Midas::ApplicationRecord
  include Poly::Joins

  self.table_name = WhittakerTech::Midas.table_name('ledger_accounts')

  # nil owner => a system-level account (suspense, platform revenue, ...).
  # present owner => a per-resource account (Customer, Organization, ...).
  belongs_to :owner, polymorphic: true, optional: true

  has_many :postings,
           class_name: 'WhittakerTech::Midas::Ledger::Posting',
           dependent: :restrict_with_error,
           inverse_of: :account

  enum :kind, {
    asset: 'asset',
    liability: 'liability',
    equity: 'equity',
    revenue: 'revenue',
    expense: 'expense',
    suspense: 'suspense'
  }, validate: true

  before_validation :normalize_currency_code

  validates :currency_code, presence: true, length: { is: 3 }
  validates :slug, presence: true, if: -> { owner_type.nil? }
  validates :kind, uniqueness: { scope: :currency_code },
                   if: -> { owner_type.nil? }
  validates :kind, uniqueness: { scope: %i[owner_type owner_id currency_code] },
                   if: -> { owner_type.present? }

  class << self
    # Finds or creates the singleton suspense account for a given currency.
    #
    # Wrapped in a bounded retry: concurrent callers (e.g. two webhooks
    # racing to post the first out-of-order event in a currency) can both
    # miss the `find_by` and attempt to create — the partial unique index
    # on `(slug, currency_code) WHERE owner_id IS NULL` makes the loser's
    # insert raise `RecordNotUnique` rather than silently duplicating, and
    # the retry then finds the winner's row.
    #
    # @param currency_code [String] ISO 4217 currency code
    # @return [Account]
    def suspense_for(currency_code)
      iso = currency_code.to_s.strip.upcase
      attempts = 0
      begin
        find_or_create_by!(kind: :suspense, slug: 'suspense', currency_code: iso)
      rescue ActiveRecord::RecordNotUnique
        attempts += 1
        retry if attempts <= 1
        raise
      end
    end
  end

  # Raw debit-normal balance: sum(debits) - sum(credits), reading the
  # denormalized `currency_minor` column on Posting directly (not joining
  # Coin) so this stays cheap even before Phase 2 partitioning.
  #
  # This is intentionally kind-agnostic. Presenting a liability/equity/
  # revenue account's balance as conventionally credit-positive is a
  # display concern layered on top of this raw number, not baked in here.
  #
  # @return [Integer]
  def balance
    postings.debit.sum(:currency_minor) - postings.credit.sum(:currency_minor)
  end

  private

  def normalize_currency_code
    self.currency_code = currency_code.to_s.strip.upcase.presence if currency_code
  end
end
