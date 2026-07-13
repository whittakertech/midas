# frozen_string_literal: true

# Raised when a Posting write (add, update, or destroy) would leave its
# parent Entry's debits and credits out of balance. This is the
# defense-in-depth backstop for any write path that bypasses
# `Ledger::Entry.record!` — see `Ledger::Posting`'s `after_save`/
# `after_destroy` guard.
#
# @since 0.4.0
class WhittakerTech::Midas::Ledger::UnbalancedEntryError < StandardError; end
