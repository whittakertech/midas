# frozen_string_literal: true

# Exchange is an immutable audit record of a single currency conversion.
#
# It owns two Coins via the standard Bankable DSL — `from` (a copy of the
# value being converted) and `to` (the converted result) — plus the rate,
# provider, and timestamp used.
#
# Exchange is write-only: nothing reads it back to resolve future
# conversions. It exists purely as an auditable record of what was
# converted, at what rate, using which provider, and when.
#
# @since 0.3.0
class WhittakerTech::Midas::Exchange < WhittakerTech::Midas::ApplicationRecord
  include WhittakerTech::Midas::Bankable

  self.table_name = WhittakerTech::Midas.table_name('exchanges')

  # Gives #from/#to (Coin readers), #from_amount/#to_amount,
  # #from_format/#to_format, and #set_from/#set_to.
  has_coins :from, :to

  validates :rate,   presence: true
  validates :source, presence: true
  validates :at,     presence: true

  before_update :block_updates

  private

  # Exchange rows are set once at creation and never touched again — the
  # coins it owns attach separately via Bankable and don't trigger this
  # callback. Does not block #destroy.
  def block_updates
    raise ActiveRecord::ReadOnlyRecord, 'WhittakerTech::Midas::Exchange records are immutable after creation'
  end
end
