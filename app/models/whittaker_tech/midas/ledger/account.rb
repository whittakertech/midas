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

  KINDS = {
    asset: 'asset',
    liability: 'liability',
    equity: 'equity',
    revenue: 'revenue',
    expense: 'expense',
    suspense: 'suspense'
  }.freeze

  # Rails 7.1 introduced both the positional `enum :name, values` form and the
  # `validate: true` option (unknown values become validation errors rather
  # than raising ArgumentError on assignment). Rails 6.1 has neither, so the
  # declaration is version-conditional. On 6.1 an unknown value still raises
  # ArgumentError at assignment time -- stricter than 7.1+, never looser --
  # and AR 6.1 offers no way to defer that to validation.
  if ActiveRecord::VERSION::STRING >= '7.1'
    enum :kind, KINDS, validate: true
  else
    # rubocop:disable Rails/EnumSyntax -- the positional form this cop wants
    # is exactly what Rails 6.1 lacks; that is why this branch exists.
    enum kind: KINDS
    # rubocop:enable Rails/EnumSyntax
  end

  before_validation :normalize_currency_code

  validates :currency_code, presence: true, length: { is: 3 }
  validates :slug, presence: true, if: -> { owner_type.nil? }
  # System accounts are disambiguated by slug, not kind — e.g. a
  # 'platform-revenue' and a 'fees-revenue' system account can coexist in
  # the same currency, both kind: :revenue. Matches the DB partial unique
  # index on (slug, currency_code) WHERE owner_id IS NULL.
  validates :slug, uniqueness: { scope: :currency_code },
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
  # Coin) so this stays cheap even before Phase 2 partitioning. Only counts
  # postings on finalized entries — Entry.create! (bypassing `record!`) is
  # a live, if unsanctioned, path to an unfinalized entry with postings
  # attached, and those must never contribute to a real balance.
  #
  # This is intentionally kind-agnostic. Presenting a liability/equity/
  # revenue account's balance as conventionally credit-positive is a
  # display concern layered on top of this raw number, not baked in here.
  #
  # @return [Integer]
  def balance
    entry_class = WhittakerTech::Midas::Ledger::Entry
    finalized = postings.joins(:entry).merge(entry_class.where.not(finalized_at: nil))
    finalized.debit.sum(:currency_minor) - finalized.credit.sum(:currency_minor)
  end

  private

  def normalize_currency_code
    self.currency_code = currency_code.to_s.strip.upcase.presence if currency_code
  end
end
