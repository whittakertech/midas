# frozen_string_literal: true

# Emits or raises deprecation notices for Midas API changes.
#
# Behavior is controlled by WhittakerTech::Midas.deprecation_behavior:
#   :warn    - prints a warning to STDERR (default)
#   :raise   - raises a DeprecationError (useful in test mode)
#   :silence - suppresses all notices
module WhittakerTech::Midas::Deprecation
  # Removal horizon advertised in deprecation messages.
  HORIZON = '0.3.0'

  # Error raised when deprecation_behavior is :raise.
  class DeprecationError < StandardError; end

  # Emits a deprecation notice for `message` attributed to `callsite`.
  #
  # @param message  [String]           human-readable deprecation description
  # @param callsite [Thread::Backtrace::Location, nil]
  def self.warn(message, callsite = caller_locations(1, 1).first)
    location = callsite ? "#{callsite.path}:#{callsite.lineno}" : 'unknown'
    full = "[DEPRECATED] #{message} " \
           "(called from #{location}). " \
           "Will be removed in whittaker_tech-midas #{HORIZON}."

    case WhittakerTech::Midas.deprecation_behavior
    when :raise   then raise DeprecationError, full
    when :silence then nil
    else               Kernel.warn full
    end
  end
end
