# frozen_string_literal: true

# Ledger::Posting is a single debit or credit line within a balanced
# Ledger::Entry. Its amount is stored twice, deliberately: via the standard
# Bankable/Coin mechanism (`amount`, `amount_format`, `amount_in`, etc. —
# for presentation/conversion parity with the rest of the engine) and
# denormalized onto `currency_minor` directly on this table, which is what
# every balance/aggregation query actually reads. This exists so Phase 2
# partitioning of this table (by `occurred_at`) pays off — if the amount
# only lived on the joined Coin row, partitioning postings wouldn't help
# any query that also needs the amount.
#
# Postings are immutable once created, and may only be added to or removed
# from an Entry before that Entry is finalized — see `Ledger::Entry.record!`
# and `Ledger::Entry#finalized?`.
#
# @since 0.4.0
class WhittakerTech::Midas::Ledger::Posting < WhittakerTech::Midas::ApplicationRecord
  include WhittakerTech::Midas::Bankable

  self.table_name = WhittakerTech::Midas.table_name('ledger_postings')

  belongs_to :entry, class_name: 'WhittakerTech::Midas::Ledger::Entry', inverse_of: :postings
  belongs_to :account, class_name: 'WhittakerTech::Midas::Ledger::Account', inverse_of: :postings

  has_coin :amount
  # Bankable's `has_coin` defines `set_amount` directly on this class (via
  # `define_method` called with `self` as the includer), not through a
  # separate module in the ancestor chain — so a `def set_amount; super;
  # end` below would have no ancestor to reach. Alias the original before
  # overriding so it can still be called.
  alias attach_amount_coin set_amount

  DIRECTIONS = { debit: 'debit', credit: 'credit' }.freeze

  # Rails 7.1 introduced both the positional `enum :name, values` form and the
  # `validate: true` option (unknown values become validation errors rather
  # than raising ArgumentError on assignment). Rails 6.1 has neither, so the
  # declaration is version-conditional. On 6.1 an unknown value still raises
  # ArgumentError at assignment time -- stricter than 7.1+, never looser --
  # and AR 6.1 offers no way to defer that to validation.
  if ActiveRecord::VERSION::STRING >= '7.1'
    enum :direction, DIRECTIONS, validate: true
  else
    # rubocop:disable Rails/EnumSyntax -- the positional form this cop wants
    # is exactly what Rails 6.1 lacks; that is why this branch exists.
    enum direction: DIRECTIONS
    # rubocop:enable Rails/EnumSyntax
  end

  validates :occurred_at, presence: true
  # account/entry are both present at creation time (before any amount is
  # attached — see `set_amount` below), so this validates meaningfully.
  # Amount-dependent checks (positivity, currency match) can't run at
  # Posting-creation time at all — Coin requires a persisted `resource`
  # before it can attach (the Exchange/Converter precedent), so `amount`
  # is always nil until `set_amount` is called afterward. Those checks
  # live in `Entry#finalize!` instead, where real amount data exists.
  validate :account_currency_matches_entry, if: -> { entry && account }

  before_create :ensure_entry_not_finalized!
  before_update :block_updates
  before_destroy :ensure_entry_not_finalized!

  # Overrides Bankable's generated `set_amount` to keep the denormalized
  # `currency_minor` column in sync with the Coin it just attached. Business
  # validation of the resulting amount (positive, currency matches entry)
  # happens in `Entry#finalize!`, not here — see class comment.
  #
  # @param amount [Money, Integer, Numeric]
  # @param currency_code [String]
  # @return [WhittakerTech::Midas::Coin]
  def set_amount(amount:, currency_code:)
    ensure_entry_not_finalized!

    coin = attach_amount_coin(amount:, currency_code:)
    update_column(:currency_minor, coin.currency_minor) # rubocop:disable Rails/SkipsModelValidations
    coin
  end

  private

  def account_currency_matches_entry
    errors.add(:account, 'currency must match the entry currency') if account.currency_code != entry.currency_code
  end

  def ensure_entry_not_finalized!
    return unless entry.finalized?

    raise WhittakerTech::Midas::Ledger::UnbalancedEntryError,
          'cannot add or remove postings on a finalized entry'
  end

  def block_updates
    raise ActiveRecord::ReadOnlyRecord, 'WhittakerTech::Midas::Ledger::Posting records are immutable after creation'
  end
end
