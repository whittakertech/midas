# frozen_string_literal: true

# Raised when a Posting write (create, destroy, or reattaching its amount
# via #set_amount) is attempted against an already-finalized Entry. This is
# the defense-in-depth backstop for any write path that bypasses
# `Ledger::Entry.record!` — see `Ledger::Posting`'s `before_create`/
# `before_destroy` guard (and the `set_amount` override).
#
# @since 0.4.0
class WhittakerTech::Midas::Ledger::UnbalancedEntryError < StandardError; end
